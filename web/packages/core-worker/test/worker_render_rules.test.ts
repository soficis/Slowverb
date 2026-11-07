import { describe, expect, it } from "vitest";
import type { RenderPayload } from "@slowverb/shared";
import { isPlaybackDeviceEnabled, isToneReverbEnabled } from "../src/worker_render_rules.js";
import { renderWithPcmPipeline } from "../src/ffmpeg_pipeline.js";
import { getPlaybackDevice, getReverbIr, normalizeStereoIrEnergy } from "@slowverb/shared";

const payload = (algo: "ffmpeg" | "tone" | "freeverb", mix: number): RenderPayload =>
  ({
    fileId: "f",
    format: "mp3",
    dspSpec: {
      specVersion: "1.0.0",
      quality: { reverb: algo },
      reverb: { decay: 0.5, preDelayMs: 20, mix },
    },
  }) as RenderPayload;

describe("isToneReverbEnabled", () => {
  it("accepts tone and freeverb with mix > 0", () => {
    expect(isToneReverbEnabled(payload("tone", 0.3))).toBe(true);
    expect(isToneReverbEnabled(payload("freeverb", 0.3))).toBe(true);
  });

  it("rejects ffmpeg and mix <= 0", () => {
    expect(isToneReverbEnabled(payload("ffmpeg", 0.3))).toBe(false);
    expect(isToneReverbEnabled(payload("freeverb", 0))).toBe(false);
    expect(isToneReverbEnabled(payload("tone", 0))).toBe(false);
  });
});

describe("isPlaybackDeviceEnabled", () => {
  const withPlayback = (ir?: ArrayBuffer, playback = true): RenderPayload =>
    ({
      fileId: "f",
      format: "wav",
      playbackIR: ir,
      dspSpec: { specVersion: "1.0.0", ...(playback ? { playback: { device: "sedan_2002_front" } } : {}) },
    }) as RenderPayload;

  it("needs both spec.playback and the fetched IR", () => {
    expect(isPlaybackDeviceEnabled(withPlayback(new ArrayBuffer(8)))).toBe(true);
    expect(isPlaybackDeviceEnabled(withPlayback(undefined))).toBe(false);
    expect(isPlaybackDeviceEnabled(withPlayback(new ArrayBuffer(8), false))).toBe(false);
  });
});

describe("playback stage in the PCM pipeline", () => {
  it("runs after effects and before PhaseLimiter/mastering, with unit-energy IR and temp cleanup list", async () => {
    const files = new Map<string, Uint8Array>();
    const calls: string[][] = [];
    const ffmpeg = {
      FS: {
        writeFile: (p: string, d: Uint8Array) => void files.set(p, d),
        readFile: (p: string) => files.get(p) ?? new Uint8Array(4),
        unlink: (p: string) => void files.delete(p),
        analyzePath: (p: string) => ({ exists: files.has(p) }),
      },
      exec: (...args: string[]) => {
        calls.push(args);
        const out = args[args.length - 1];
        const data = out.endsWith("playback-ir.f32") ? new Float32Array([2, 0, 0, 2]) : new Float32Array(8);
        files.set(out, new Uint8Array(data.buffer));
        return 0;
      },
    };
    const payload = {
      fileId: "f",
      format: "wav",
      filterGraph: "volume=1dB",
      playbackIR: new ArrayBuffer(8),
      dspSpec: { specVersion: "1.0.0", playback: { device: "sedan_2002_rear" } },
    } as unknown as RenderPayload;
    const noop = () => undefined;
    const result = await renderWithPcmPipeline(
      ffmpeg,
      payload,
      "j",
      false,
      { applyPhaseLimiter: false, useSoundTouch: false, useToneReverb: false, usePlaybackDevice: true },
      { postEvent: noop, withProgressStage: (_s, _o, _c, run) => run(), postMasteringWarning: noop } as never
    );
    const joined = calls.map((c) => c.join(" "));
    const effects = joined.findIndex((c) => c.includes("volume=1dB"));
    const speaker = joined.findIndex((c) => c.includes("afir=dry=1:wet=1:gtype=none,volume=-6.5dB,alimiter=limit=0.95:level=disabled"));
    const encode = joined.length - 1;
    expect(effects).toBeGreaterThanOrEqual(0);
    expect(speaker).toBeGreaterThan(effects);
    expect(encode).toBeGreaterThan(speaker);
    // IR was rewritten with unit energy per channel: [2,0,0,2] -> [1,0,0,1]
    expect(Array.from(new Float32Array(files.get("f-j-playback-ir.f32")!.slice().buffer))).toEqual([1, 0, 0, 1]);
    expect(result.tempFiles).toEqual(expect.arrayContaining(["f-j-playback-ir.wav", "f-j-playback-ir.f32", "f-j-playback.f32"]));
  });
});

describe("IR registry", () => {
  it("only resolves whitelisted ids", () => {
    expect(getPlaybackDevice("sedan_2002_front")?.url).toBe("irs/sedan_2002_front.wav");
    expect(getReverbIr("hotel_bathroom")?.url).toBe("irs/hotel_bathroom.wav");
    expect(getReverbIr("sedan_2002_front")).toBeUndefined();
    for (const bad of ["https://evil.example/x.wav", "__proto__", "toString", undefined, 3]) {
      expect(getPlaybackDevice(bad)).toBeUndefined();
      expect(getReverbIr(bad)).toBeUndefined();
    }
  });
});

describe("normalizeStereoIrEnergy", () => {
  it("scales each channel to unit energy", () => {
    const ir = new Float32Array([3, 0, 4, 0, 0, 2, 0, 0]);
    expect(normalizeStereoIrEnergy(ir)).toBe(true);
    const e = [0, 0];
    ir.forEach((v, i) => (e[i & 1] += v * v));
    expect(e[0]).toBeCloseTo(1, 6);
    expect(e[1]).toBeCloseTo(1, 6);
  });

  it("rejects silent or non-finite IRs and leaves data untouched", () => {
    const silent = new Float32Array([0, 0, 0, 0]);
    expect(normalizeStereoIrEnergy(silent)).toBe(false);
    const oneSilent = new Float32Array([1, 0, 1, 0]);
    expect(normalizeStereoIrEnergy(oneSilent)).toBe(false);
    expect(Array.from(oneSilent)).toEqual([1, 0, 1, 0]);
    expect(normalizeStereoIrEnergy(new Float32Array([NaN, 1, 1, 1]))).toBe(false);
  });
});

describe("file reverb in the PCM pipeline", () => {
  it("decodes the WAV IR and blends with the registry makeup", async () => {
    const files = new Map<string, Uint8Array>();
    const calls: string[][] = [];
    const ffmpeg = {
      FS: {
        writeFile: (p: string, d: Uint8Array) => void files.set(p, d),
        readFile: (p: string) => files.get(p) ?? new Uint8Array(4),
        unlink: (p: string) => void files.delete(p),
        analyzePath: (p: string) => ({ exists: files.has(p) }),
      },
      exec: (...args: string[]) => {
        calls.push(args);
        const out = args[args.length - 1];
        const data = out.endsWith("reverb-ir.f32") ? new Float32Array([2, 0, 0, 2]) : new Float32Array(8);
        files.set(out, new Uint8Array(data.buffer));
        return 0;
      },
    };
    const payload = {
      fileId: "f",
      format: "wav",
      reverbIRWav: new ArrayBuffer(8),
      dspSpec: {
        specVersion: "1.0.0",
        quality: { reverb: "file" },
        reverb: { decay: 0.5, preDelayMs: 20, mix: 0.25, ir: "plate_conner_i" },
      },
    } as unknown as RenderPayload;
    const noop = () => undefined;
    await renderWithPcmPipeline(
      ffmpeg,
      payload,
      "j",
      false,
      { applyPhaseLimiter: false, useSoundTouch: false, useToneReverb: true, usePlaybackDevice: false },
      { postEvent: noop, withProgressStage: (_s: string, _o: number, _c: number, run: () => void) => run(), postMasteringWarning: noop } as never
    );
    const blend = calls.map((c) => c.join(" ")).find((c) => c.includes("amix="));
    expect(blend).toContain("afir=dry=1:wet=1:gtype=none,volume=-14.5dB[wv]");
    expect(blend).toContain("weights='0.7500 0.2500'");
    expect(Array.from(new Float32Array(files.get("f-j-reverb-ir.f32")!.slice().buffer))).toEqual([1, 0, 0, 1]);
  });
});
