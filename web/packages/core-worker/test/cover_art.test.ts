import { beforeAll, describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import {
  COVER_MAX_PX,
  attachCoverArt,
  buildAttachCoverArgs,
  buildExtractCoverArgs,
  extractCoverArt,
  supportsCoverArt,
} from "../src/cover_art.js";

// The bundled core expects a worker global scope.
(globalThis as any).self ??= globalThis;
(globalThis as any).location ??= { href: "file:///" };
(globalThis as any).importScripts ??= () => {};

describe("cover_art pure", () => {
  it("supportsCoverArt true only for mp3/flac", () => {
    expect(supportsCoverArt("mp3")).toBe(true);
    expect(supportsCoverArt("flac")).toBe(true);
    expect(supportsCoverArt("wav")).toBe(false);
    expect(supportsCoverArt("aac")).toBe(false);
    expect(COVER_MAX_PX).toBe(600);
  });

  it("buildExtractCoverArgs exact", () => {
    expect(buildExtractCoverArgs("i", "o")).toEqual([
      "-hide_banner",
      "-i",
      "i",
      "-map",
      "0:v:0",
      "-frames:v",
      "1",
      "-an",
      "-vf",
      "scale='min(600,iw)':'min(600,ih)':force_original_aspect_ratio=decrease",
      "-c:v",
      "png",
      "-f",
      "image2",
      "-update",
      "1",
      "-y",
      "o",
    ]);
  });

  it("buildAttachCoverArgs mp3 exact", () => {
    expect(buildAttachCoverArgs("a", "c", "o", "mp3")).toEqual([
      "-hide_banner",
      "-i",
      "a",
      "-i",
      "c",
      "-map",
      "0:a:0",
      "-map",
      "1:v:0",
      "-c:a",
      "copy",
      "-c:v",
      "png",
      "-vf",
      "scale='min(600,iw)':'min(600,ih)':force_original_aspect_ratio=decrease",
      "-disposition:v:0",
      "attached_pic",
      "-id3v2_version",
      "3",
      "-metadata:s:v",
      "title=Album cover",
      "-metadata:s:v",
      "comment=Cover (front)",
      "-f",
      "mp3",
      "-y",
      "o",
    ]);
  });

  it("buildAttachCoverArgs flac has no id3", () => {
    const args = buildAttachCoverArgs("a", "c", "o", "flac");
    expect(args).not.toContain("-id3v2_version");
    expect(args.slice(-4)).toEqual(["-f", "flac", "-y", "o"]);
    expect(args).toContain("attached_pic");
  });
});

describe("cover_art integration", () => {
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

  function streamsOf(name: string): string[] {
    core.reset();
    const lines: string[] = [];
    core.setLogger(({ message }: { type: string; message: string }) => {
      lines.push(message);
    });
    try {
      core.exec("-hide_banner", "-i", name);
    } catch {
      // exec returns non-zero there; that is fine.
    } finally {
      try {
        core.setLogger(() => {});
      } catch {
        // ignore
      }
    }
    return lines.filter((l) => l.includes("Stream #"));
  }

  function readAsBuffer(name: string): ArrayBuffer {
    const bytes = core.FS.readFile(name) as Uint8Array;
    const copy = Uint8Array.from(bytes);
    return copy.buffer;
  }

  beforeAll(async () => {
    const dir = new URL("../../../web/js/", import.meta.url);
    const mod = await import(new URL("ffmpeg-core.js", dir).href);
    core = await mod.default({ wasmBinary: readFileSync(new URL("ffmpeg-core.wasm", dir)) });
    core.reset();
    let rc = core.exec(
      "-f",
      "lavfi",
      "-i",
      "color=c=0xcc3366:s=800x400",
      "-frames:v",
      "1",
      "cover.png"
    );
    expect(rc).toBe(0);
    core.reset();
    rc = core.exec(
      "-f",
      "lavfi",
      "-i",
      "sine=f=440:d=2",
      "-ac",
      "2",
      "-c:a",
      "libmp3lame",
      "-b:a",
      "128k",
      "tone.mp3"
    );
    expect(rc).toBe(0);
    core.reset();
    rc = core.exec(
      "-i",
      "tone.mp3",
      "-i",
      "cover.png",
      "-map",
      "0:a",
      "-map",
      "1:v",
      "-c:a",
      "copy",
      "-c:v",
      "mjpeg",
      "-disposition:v:0",
      "attached_pic",
      "-id3v2_version",
      "3",
      "tagged.mp3"
    );
    expect(rc).toBe(0);
    core.reset();
    rc = core.exec("-f", "lavfi", "-i", "sine=f=440:d=2", "-ac", "2", "tone.flac");
    expect(rc).toBe(0);
  }, 60_000);

  it("extractCoverArt on tagged.mp3 returns PNG 600x300", async () => {
    const out = extractCoverArt(core, "tagged.mp3", cleanupFiles);
    expect(out).not.toBeNull();
    const bytes = new Uint8Array(out as ArrayBuffer);
    expect(bytes[0]).toBe(0x89);
    expect(bytes[1]).toBe(0x50);
    core.FS.writeFile("x.png", bytes);
    const lines = streamsOf("x.png");
    expect(lines.join("\n")).toContain("600x300");
  }, 60_000);

  it("extractCoverArt on tone.mp3 returns null", async () => {
    let result: ArrayBuffer | null = null;
    expect(() => {
      result = extractCoverArt(core, "tone.mp3", cleanupFiles);
    }).not.toThrow();
    expect(result).toBeNull();
  }, 60_000);

  it("attachCoverArt mp3 embeds png attached pic", async () => {
    const audio = readAsBuffer("tone.mp3");
    const cover = readAsBuffer("cover.png");
    const inLen = new Uint8Array(audio).length;
    const jobId = "t-attach-mp3";
    const out = attachCoverArt(core, audio, cover, "mp3", jobId, cleanupFiles);
    const outU8 = new Uint8Array(out);
    expect(Array.from(outU8)).not.toEqual(Array.from(new Uint8Array(audio)));
    core.FS.writeFile("out-mp3.mp3", outU8);
    const lines = streamsOf("out-mp3.mp3");
    const joined = lines.join("\n");
    expect(lines.some((l) => l.includes("png") && l.includes("(attached pic)"))).toBe(true);
    expect(joined).toContain("mp3");
    void inLen;
  }, 60_000);

  it("attachCoverArt flac embeds png attached pic", async () => {
    const audio = readAsBuffer("tone.flac");
    const cover = readAsBuffer("cover.png");
    const jobId = "t-attach-flac";
    const out = attachCoverArt(core, audio, cover, "flac", jobId, cleanupFiles);
    const outU8 = new Uint8Array(out);
    expect(Array.from(outU8)).not.toEqual(Array.from(new Uint8Array(audio)));
    core.FS.writeFile("out-flac.flac", outU8);
    const lines = streamsOf("out-flac.flac");
    const joined = lines.join("\n");
    expect(lines.some((l) => l.includes("png") && l.includes("(attached pic)"))).toBe(true);
    expect(joined).toContain("flac");
  }, 60_000);

  it("attachCoverArt with garbage cover returns original bytes", async () => {
    const audio = readAsBuffer("tone.mp3");
    const garbage = new Uint8Array([1, 2, 3]).buffer;
    const jobId = "t-attach-garbage";
    const out = attachCoverArt(core, audio, garbage, "mp3", jobId, cleanupFiles);
    expect(Array.from(new Uint8Array(out))).toEqual(Array.from(new Uint8Array(audio)));
  }, 60_000);

  it("job temp files cleaned up", async () => {
    const temps = [
      "tagged.mp3-cover.png",
      "tone.mp3-cover.png",
      "t-attach-mp3-cover-in.mp3",
      "t-attach-mp3-cover.img",
      "t-attach-mp3-cover-out.mp3",
      "t-attach-flac-cover-in.flac",
      "t-attach-flac-cover.img",
      "t-attach-flac-cover-out.flac",
      "t-attach-garbage-cover-in.mp3",
      "t-attach-garbage-cover.img",
      "t-attach-garbage-cover-out.mp3",
    ];
    for (const p of temps) {
      expect(core.FS.analyzePath(p).exists).toBeFalsy();
    }
    cleanupFiles("x.png", "out-mp3.mp3", "out-flac.flac");
  }, 60_000);
});
