import { beforeAll, describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import {
  BLACK_PNG_BASE64,
  blackPngBytes,
  buildBedArgs,
  buildMuxArgs,
  muxStillVideo,
  resolveStillVideoParams,
} from "../src/video_mux.js";

// The bundled core expects a worker global scope.
(globalThis as any).self ??= globalThis;
(globalThis as any).location ??= { href: "file:///" };
(globalThis as any).importScripts ??= () => {};

describe("video_mux pure", () => {
  it("blackPngBytes has PNG signature and 1x1 IHDR", () => {
    const bytes = blackPngBytes();
    expect(Array.from(bytes.slice(0, 8))).toEqual([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    expect(view.getUint32(16)).toBe(1);
    expect(view.getUint32(20)).toBe(1);
    void BLACK_PNG_BASE64;
  });

  it("resolveStillVideoParams defaults", () => {
    expect(resolveStillVideoParams({ width: 1920, height: 1080 })).toEqual({
      width: 1920,
      height: 1080,
      fps: 30,
      crf: 23,
      encoder: "libx264",
    });
  });

  it("resolveStillVideoParams rejects bad values", () => {
    expect(() => resolveStillVideoParams({ width: 1921, height: 1080 })).toThrow(RangeError);
    expect(() => resolveStillVideoParams({ width: 8, height: 1080 })).toThrow(RangeError);
    expect(() => resolveStillVideoParams({ width: 4096, height: 4096 })).toThrow(RangeError);
    expect(() => resolveStillVideoParams({ width: 1920, height: 1080, fps: 0 })).toThrow(RangeError);
    expect(() => resolveStillVideoParams({ width: 1920, height: 1080, fps: 61 })).toThrow(RangeError);
    expect(() => resolveStillVideoParams({ width: 1920, height: 1080, fps: 29.97 })).toThrow(RangeError);
    expect(() => resolveStillVideoParams({ width: 1920, height: 1080, crf: 52 })).toThrow(RangeError);
  });

  it("buildBedArgs libx264 exact", () => {
    expect(
      buildBedArgs("s", "b", { width: 1920, height: 1080, fps: 30, crf: 23, encoder: "libx264" })
    ).toEqual([
      "-loop",
      "1",
      "-framerate",
      "30",
      "-i",
      "s",
      "-t",
      "2",
      "-vf",
      "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,setsar=1",
      "-c:v",
      "libx264",
      "-preset",
      "ultrafast",
      "-tune",
      "stillimage",
      "-crf",
      "23",
      "-g",
      "30",
      "-pix_fmt",
      "yuv420p",
      "-r",
      "30",
      "-an",
      "-y",
      "b",
    ]);
  });

  it("buildBedArgs mpeg4 uses q:v and no crf", () => {
    const args = buildBedArgs("s", "b", { width: 1920, height: 1080, fps: 30, crf: 23, encoder: "mpeg4" });
    expect(args).toContain("-q:v");
    expect(args).toContain("3");
    expect(args).not.toContain("-crf");
  });

  it("buildMuxArgs exact", () => {
    expect(buildMuxArgs("b", "a", 44100, "o")).toEqual([
      "-stream_loop",
      "-1",
      "-i",
      "b",
      "-f",
      "f32le",
      "-ac",
      "2",
      "-ar",
      "44100",
      "-i",
      "a",
      "-map",
      "0:v:0",
      "-map",
      "1:a:0",
      "-c:v",
      "copy",
      "-c:a",
      "aac",
      "-b:a",
      "192k",
      "-shortest",
      "-movflags",
      "+faststart",
      "-y",
      "o",
    ]);
  });

  it("muxStillVideo rejects when bed encode fails and cleans up", async () => {
    const files = new Map<string, Uint8Array>();
    const execCalls: string[][] = [];
    const ffmpeg = {
      FS: {
        writeFile: (p: string, d: Uint8Array) => void files.set(p, d),
        readFile: (p: string) => {
          const v = files.get(p);
          if (!v) throw new Error(`missing ${p}`);
          return v;
        },
        unlink: (p: string) => void files.delete(p),
        analyzePath: (p: string) => ({ exists: files.has(p) }),
      },
      exec: (...args: string[]) => {
        execCalls.push(args);
        if (execCalls.length === 1) return 1;
        return 0;
      },
    };
    const cleaned: string[] = [];
    const left = new Float32Array([0.1, 0.2]);
    const right = new Float32Array([0.1, 0.2]);
    await expect(
      muxStillVideo(
        ffmpeg as never,
        { left, right, sampleRate: 44100, still: null, width: 640, height: 360 },
        "job1",
        (...paths: string[]) => void cleaned.push(...paths)
      )
    ).rejects.toThrow(/video bed encode failed/);
    expect(cleaned).toEqual(
      expect.arrayContaining(["job1-still.img", "job1-bed.mp4", "job1-audio.f32", "job1-video.mp4"])
    );
    expect(cleaned).toHaveLength(4);
  });
});

describe("video_mux integration", () => {
  let core: any;
  const cleanupFiles = (...paths: string[]) => {
    for (const p of paths) {
      try {
        core.FS.unlink(p);
      } catch {
        // ignore
      }
    }
  };

  function makeSine(sampleRate: number, seconds: number): { left: Float32Array; right: Float32Array } {
    const n = Math.floor(sampleRate * seconds);
    const left = new Float32Array(n);
    const right = new Float32Array(n);
    for (let i = 0; i < n; i += 1) {
      const s = 0.3 * Math.sin((2 * Math.PI * 440 * i) / sampleRate);
      left[i] = s;
      right[i] = s;
    }
    return { left, right };
  }

  function indexOfAscii(haystack: Uint8Array, needle: string): number {
    const n = new TextEncoder().encode(needle);
    outer: for (let i = 0; i + n.length <= haystack.length; i += 1) {
      for (let j = 0; j < n.length; j += 1) {
        if (haystack[i + j] !== n[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  function parseMvhdDuration(bytes: Uint8Array): number {
    const i = indexOfAscii(bytes, "mvhd");
    if (i < 0) throw new Error("mvhd not found");
    const version = bytes[i + 4];
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    if (version === 0) {
      const timescale = view.getUint32(i + 16);
      const duration = view.getUint32(i + 20);
      return duration / timescale;
    }
    if (version === 1) {
      const timescale = view.getUint32(i + 24);
      const hi = view.getUint32(i + 28);
      const lo = view.getUint32(i + 32);
      return (hi * 2 ** 32 + lo) / timescale;
    }
    throw new Error(`unsupported mvhd version ${version}`);
  }

  function expectMp4Checks(bytes: Uint8Array, expectedSeconds: number): void {
    expect(new TextDecoder().decode(bytes.slice(4, 8))).toBe("ftyp");
    const asciiAll = new TextDecoder().decode(bytes);
    expect(asciiAll).toContain("moov");
    const moov = indexOfAscii(bytes, "moov");
    const mdat = indexOfAscii(bytes, "mdat");
    expect(moov).toBeGreaterThanOrEqual(0);
    expect(mdat).toBeGreaterThanOrEqual(0);
    expect(moov).toBeLessThan(mdat);
    expect(Math.abs(parseMvhdDuration(bytes) - expectedSeconds)).toBeLessThan(0.11);
  }

  beforeAll(async () => {
    const dir = new URL("../../../web/js/", import.meta.url);
    const mod = await import(new URL("ffmpeg-core.js", dir).href);
    core = await mod.default({ wasmBinary: readFileSync(new URL("ffmpeg-core.wasm", dir)) });
  }, 60_000);

  it("muxes black still at 640x360 with faststart", async () => {
    const { left, right } = makeSine(44100, 3.0);
    const jobId = "it-black-640x360";
    const buffer = await muxStillVideo(
      core,
      { left, right, sampleRate: 44100, still: null, width: 640, height: 360 },
      jobId,
      cleanupFiles
    );
    const bytes = new Uint8Array(buffer);
    expectMp4Checks(bytes, 3.0);
  }, 60_000);

  it("muxes real still at 1280x720 fps 24", async () => {
    core.reset();
    const rc = core.exec("-f", "lavfi", "-i", "color=c=0x336699:s=320x240", "-frames:v", "1", "src.png");
    expect(rc).toBe(0);
    const still = core.FS.readFile("src.png") as Uint8Array;
    try {
      const { left, right } = makeSine(44100, 3.0);
      const jobId = "it-real-1280x720";
      const buffer = await muxStillVideo(
        core,
        { left, right, sampleRate: 44100, still, width: 1280, height: 720, fps: 24 },
        jobId,
        cleanupFiles
      );
      const bytes = new Uint8Array(buffer);
      expectMp4Checks(bytes, 3.0);
    } finally {
      try {
        core.FS.unlink("src.png");
      } catch {
        // ignore
      }
    }
  }, 60_000);

  it("cleaned up job files", () => {
    for (const jobId of ["it-black-640x360", "it-real-1280x720"]) {
      for (const suffix of ["-still.img", "-bed.mp4", "-audio.f32", "-video.mp4"]) {
        expect(core.FS.analyzePath(`${jobId}${suffix}`).exists).toBeFalsy();
      }
    }
  }, 60_000);
});
