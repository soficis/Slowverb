import { describe, expect, it } from "vitest";
import { applySoundTouch } from "../src/worker_effects.js";

function stereoSine(seconds: number, hz: number): Float32Array {
  const frames = Math.round(seconds * 44100);
  const out = new Float32Array(frames * 2);
  for (let i = 0; i < frames; i++) {
    const s = 0.5 * Math.sin((2 * Math.PI * hz * i) / 44100);
    out[i * 2] = s;
    out[i * 2 + 1] = s;
  }
  return out;
}

function tailPeak(samples: Float32Array, frames: number): number {
  let peak = 0;
  for (let i = Math.max(0, samples.length - frames * 2); i < samples.length; i++) {
    peak = Math.max(peak, Math.abs(samples[i]));
  }
  return peak;
}

describe("applySoundTouch", () => {
  it.each([
    [0.86, 0],
    [0.5, 0],
    [1.0, -2.61],
    [1.25, 4],
  ])("keeps the whole input at tempo %s, pitch %s", (tempo, pitch) => {
    const input = stereoSine(2, 220);
    const out = applySoundTouch(input, tempo, pitch);
    // Without flushing, ~0.35 s of input was dropped from the end.
    expect(out.length / 2).toBe(Math.round(88200 / tempo));
    expect(tailPeak(out, 2205)).toBeGreaterThan(0.2);
  });
});
