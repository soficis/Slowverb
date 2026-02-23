import { describe, expect, it } from "vitest";
import {
  addCodecArgs,
  buildDecodePlan,
  buildOutputName,
  clamp01,
  clampInt,
  parseProbeLogs,
} from "../src/worker_utils.js";

describe("worker_utils", () => {
  it("buildOutputName uses preview/full suffix", () => {
    expect(buildOutputName("track", "job1", "mp3", true)).toBe("track-job1-preview.mp3");
    expect(buildOutputName("track", "job1", "wav", false)).toBe("track-job1-full.wav");
  });

  it("buildDecodePlan includes filter graph when present", () => {
    const args = buildDecodePlan(
      {
        fileId: "src",
        format: "mp3",
        filterGraph: "atempo=0.9",
      },
      "out.f32",
      44100,
      false,
    );

    expect(args).toContain("-af");
    expect(args).toContain("atempo=0.9");
  });

  it("addCodecArgs throws for unsupported format", () => {
    const args: string[] = [];
    expect(() => addCodecArgs(args, "opus" as never, 192)).toThrow(/Unsupported export format/);
  });

  it("parseProbeLogs extracts metadata", () => {
    const parsed = parseProbeLogs([
      "Input #0, mp3, from 'in.mp3':",
      "  Duration: 00:00:12.34, start: 0.000000, bitrate: 320 kb/s",
      "  Stream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 320 kb/s",
    ]);

    expect(parsed.format).toBe("mp3");
    expect(parsed.durationMs).toBe(12340);
    expect(parsed.sampleRate).toBe(44100);
    expect(parsed.channels).toBe(2);
  });

  it("clamp helpers enforce boundaries", () => {
    expect(clamp01(-1)).toBe(0);
    expect(clamp01(2)).toBe(1);
    expect(clampInt(7.7, 0, 10)).toBe(8);
    expect(clampInt(-5, 0, 10)).toBe(0);
  });
});
