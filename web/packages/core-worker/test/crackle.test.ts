import { describe, expect, it } from "vitest";
import type { RenderPayload } from "@slowverb/shared";
import {
  MAX_POPS_PER_SEC,
  mixCrackleInto,
  planCracklePops,
  renderCrackleBed,
  xorshift32,
} from "../src/crackle.js";
import { renderWithPcmPipeline } from "../src/ffmpeg_pipeline.js";

describe("xorshift32", () => {
  it("same seed -> same first 1000 values; values in [0,1); seed 0 does not get stuck at 0", () => {
    const a = xorshift32(12345);
    const b = xorshift32(12345);
    for (let i = 0; i < 1000; i += 1) {
      const va = a();
      const vb = b();
      expect(va).toBe(vb);
      expect(va).toBeGreaterThanOrEqual(0);
      expect(va).toBeLessThan(1);
    }
    const z = xorshift32(0);
    const first = z();
    expect(first).not.toBe(0);
    let allZero = first === 0;
    for (let i = 1; i < 100; i += 1) {
      if (z() !== 0) {
        allZero = false;
        break;
      }
    }
    expect(allZero).toBe(false);
  });
});

describe("renderCrackleBed determinism", () => {
  it("same seed twice -> byte-identical", () => {
    const a = renderCrackleBed(7, 44100 * 3, 0.6, 44100);
    const b = renderCrackleBed(7, 44100 * 3, 0.6, 44100);
    expect(a.length).toBe(b.length);
    for (let i = 0; i < a.length; i += 1) {
      expect(a[i]).toBe(b[i]);
    }
  });

  it("different seeds (7 vs 8) -> outputs differ", () => {
    const a = renderCrackleBed(7, 44100, 0.6, 44100);
    const b = renderCrackleBed(8, 44100, 0.6, 44100);
    expect(a.length).toBe(b.length);
    let diff = 0;
    for (let i = 0; i < a.length; i += 1) {
      if (a[i] !== b[i]) diff += 1;
    }
    expect(diff).toBeGreaterThan(0);
  });
});

describe("renderCrackleBed intensity", () => {
  it("intensity 0 -> zeros; -1 and NaN -> also all zeros", () => {
    for (const intensity of [0, -1, NaN]) {
      const frames = 100;
      const out = renderCrackleBed(7, frames, intensity, 44100);
      expect(out.length).toBe(2 * frames);
      for (let i = 0; i < out.length; i += 1) {
        expect(out[i]).toBe(0);
      }
    }
  });

  it("intensity 1, 5s at 44100 -> bounded and pops audible", () => {
    const out = renderCrackleBed(7, 44100 * 5, 1, 44100);
    let max = 0;
    for (let i = 0; i < out.length; i += 1) {
      const v = Math.abs(out[i]);
      if (v > max) max = v;
      expect(v).toBeLessThanOrEqual(1.0);
    }
    expect(max).toBeGreaterThan(0.05);
  });
});

describe("planCracklePops", () => {
  it("full intensity over 10s: bounded, ascending, in range", () => {
    const frames = 44100 * 10;
    const onsets = planCracklePops(3, frames, 1, 44100);
    expect(onsets.length).toBeLessThanOrEqual(8 * 10 + 1);
    expect(onsets.length).toBeGreaterThanOrEqual(20);
    for (let i = 1; i < onsets.length; i += 1) {
      expect(onsets[i]).toBeGreaterThanOrEqual(onsets[i - 1]);
    }
    for (let i = 0; i < onsets.length; i += 1) {
      expect(onsets[i]).toBeLessThan(frames);
    }
    void MAX_POPS_PER_SEC;
  });

  it("intensity 0.25 over 10s -> bounded", () => {
    const onsets = planCracklePops(3, 44100 * 10, 0.25, 44100);
    expect(onsets.length).toBeLessThanOrEqual(2 * 10 + 1);
  });
});

describe("validation", () => {
  it("frames 0 -> empty outputs", () => {
    expect(planCracklePops(3, 0, 1, 44100).length).toBe(0);
    const bed = renderCrackleBed(3, 0, 1, 44100);
    expect(bed.length).toBe(0);
  });

  it("frames 1.5 or sampleRate 0 -> throws RangeError", () => {
    expect(() => planCracklePops(3, 1.5, 1, 44100)).toThrow(RangeError);
    expect(() => planCracklePops(3, 100, 1, 0)).toThrow(RangeError);
    expect(() => renderCrackleBed(3, 1.5, 1, 44100)).toThrow(RangeError);
    expect(() => renderCrackleBed(3, 100, 1, 0)).toThrow(RangeError);
  });

  it("mixCrackleInto adds element-wise; mismatched lengths throw", () => {
    const pcm = new Float32Array([1, 2, 3, 4]);
    const bed = new Float32Array([0.5, -0.5, 0.25, 0.25]);
    mixCrackleInto(pcm, bed);
    expect(Array.from(pcm)).toEqual([1.5, 1.5, 3.25, 4.25]);
    expect(() => mixCrackleInto(new Float32Array(2), new Float32Array(3))).toThrow(RangeError);
  });
});

describe("crackle stage in the PCM pipeline", () => {
  it("mixes crackle into PCM before encode and records the temp file", async () => {
    const files = new Map<string, Uint8Array>();
    const calls: string[][] = [];
    const rawFrames = 44100;
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
        if (out.endsWith("-raw.f32")) {
          const data = new Float32Array(rawFrames * 2);
          files.set(out, new Uint8Array(data.buffer));
        } else {
          const data = new Float32Array(8);
          files.set(out, new Uint8Array(data.buffer));
        }
        return 0;
      },
    };
    const payload = {
      fileId: "f",
      format: "wav",
      dspSpec: { specVersion: "1.0.0", crackle: { intensity: 1, seed: 1 } },
    } as unknown as RenderPayload;
    const noop = () => undefined;
    const result = await renderWithPcmPipeline(
      ffmpeg,
      payload,
      "j",
      false,
      { applyPhaseLimiter: false, useSoundTouch: false, useToneReverb: false, usePlaybackDevice: false, useCrackle: true },
      { postEvent: noop, withProgressStage: (_s: string, _o: number, _c: number, run: () => void) => run(), postMasteringWarning: noop } as never
    );
    expect(result.tempFiles).toContain("f-j-crackle.f32");
    const rawBytes = files.get("f-j-raw.f32")!;
    const crackleBytes = files.get("f-j-crackle.f32")!;
    expect(crackleBytes).toBeDefined();
    // Input to the final encode is the crackle file and it differs from the decoded raw PCM.
    const encodeArgs = calls[calls.length - 1];
    const inputIdx = encodeArgs.indexOf("-i");
    expect(inputIdx).toBeGreaterThanOrEqual(0);
    const encodeInput = encodeArgs[inputIdx + 1];
    expect(encodeInput).toBe("f-j-crackle.f32");
    const raw = new Float32Array(rawBytes.buffer, rawBytes.byteOffset, rawBytes.byteLength / 4);
    const mixed = new Float32Array(crackleBytes.buffer, crackleBytes.byteOffset, crackleBytes.byteLength / 4);
    expect(mixed.length).toBe(raw.length);
    let diff = 0;
    for (let i = 0; i < mixed.length; i += 1) {
      if (mixed[i] !== raw[i]) diff += 1;
    }
    expect(diff).toBeGreaterThan(0);
  });
});
