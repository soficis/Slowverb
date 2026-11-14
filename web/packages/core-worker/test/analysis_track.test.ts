import { describe, expect, it } from "vitest";
import {
  ANALYSIS_STRIDE,
  analysisBandEdges,
  frameAt,
} from "@slowverb/shared";
import { buildAnalysisTrack, fft } from "../src/analysis_track.js";

function sine(freq: number, amp: number, seconds: number, sr = 44100): Float32Array {
  const n = Math.floor(seconds * sr);
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    out[i] = amp * Math.sin((2 * Math.PI * freq * i) / sr);
  }
  return out;
}

function lcg(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

describe("analysis_track", () => {
  it("a: silence is all zeros, raw and normalised", () => {
    const zeros = new Float32Array(44100);
    for (const track of [
      buildAnalysisTrack(zeros, 44100, { normalise: false }),
      buildAnalysisTrack(zeros, 44100),
    ]) {
      for (let i = 0; i < track.data.length; i++) {
        expect(track.data[i]).toBe(0);
      }
    }
  });

  it("b: 60 Hz bass", () => {
    const pcm = sine(60, 0.8, 1);
    const raw = buildAnalysisTrack(pcm, 44100, { normalise: false });
    const mid = Math.floor(raw.frameCount / 2);
    const f = frameAt(raw, mid);
    expect(f.bass).toBeGreaterThan(0.7);
    expect(f.bass).toBeGreaterThan(f.mid * 2);

    const norm = buildAnalysisTrack(pcm, 44100);
    const fn = frameAt(norm, Math.floor(norm.frameCount / 2));
    expect(fn.bass).toBeGreaterThan(0.8);
    expect(fn.bass).toBeGreaterThan(fn.mid * 2);
  });

  it("c: 1000 Hz mid", () => {
    const pcm = sine(1000, 0.8, 1);
    const raw = buildAnalysisTrack(pcm, 44100, { normalise: false });
    const mid = Math.floor(raw.frameCount / 2);
    const f = frameAt(raw, mid);
    expect(f.mid).toBeGreaterThan(0.7);
    expect(f.mid).toBeGreaterThan(f.bass * 2);
    expect(f.mid).toBeGreaterThan(f.treble * 2);

    const norm = buildAnalysisTrack(pcm, 44100);
    const fn = frameAt(norm, Math.floor(norm.frameCount / 2));
    expect(fn.mid).toBeGreaterThan(0.8);
    expect(fn.mid).toBeGreaterThan(fn.bass);
  });

  it("d: 8000 Hz treble", () => {
    const pcm = sine(8000, 0.8, 1);
    const raw = buildAnalysisTrack(pcm, 44100, { normalise: false });
    const mid = Math.floor(raw.frameCount / 2);
    const f = frameAt(raw, mid);
    expect(f.treble).toBeGreaterThan(0.7);
    expect(f.treble).toBeGreaterThan(f.mid * 2);

    const norm = buildAnalysisTrack(pcm, 44100);
    const fn = frameAt(norm, Math.floor(norm.frameCount / 2));
    expect(fn.treble).toBeGreaterThan(0.8);
    expect(fn.treble).toBeGreaterThan(fn.mid);
  });

  it("e: normalisation peaks at 0.95", () => {
    for (const amp of [0.5, 1.0]) {
      const pcm = sine(1000, amp, 1);
      const track = buildAnalysisTrack(pcm, 44100);
      let maxRms = 0;
      let maxRange = 0;
      for (let i = 0; i < track.frameCount; i++) {
        const f = frameAt(track, i);
        if (f.rms > maxRms) maxRms = f.rms;
        maxRange = Math.max(maxRange, f.bass, f.mid, f.treble);
      }
      expect(maxRms).toBeGreaterThan(0.95 - 0.001);
      expect(maxRms).toBeLessThan(0.95 + 0.001);
      expect(maxRange).toBeGreaterThan(0.95 - 0.001);
      expect(maxRange).toBeLessThan(0.95 + 0.001);
    }
  });

  it("f: frameCount and fps", () => {
    const pcm = sine(440, 0.8, 10);
    const t2048 = buildAnalysisTrack(pcm, 44100, { hopSize: 2048, normalise: false });
    expect(t2048.frameCount).toBe(216);
    const tDefault = buildAnalysisTrack(pcm, 44100, { normalise: false });
    expect(tDefault.frameCount).toBe(431);
    expect(tDefault.fps).toBe(44100 / 1024);
  });

  it("g: frameAt clamping and empty track", () => {
    const pcm = sine(1000, 0.8, 1);
    const track = buildAnalysisTrack(pcm, 44100, { normalise: false });
    const last = frameAt(track, track.frameCount - 1);
    expect(last.spectrum.length).toBe(64);
    const vals: number[] = [...last.spectrum, last.rms, last.bass, last.mid, last.treble];
    for (const v of vals) {
      expect(Number.isFinite(v)).toBe(true);
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThanOrEqual(1);
    }
    const clamped = frameAt(track, track.frameCount + 5);
    expect(clamped).toEqual(last);
    expect(() => frameAt(buildAnalysisTrack(new Float32Array(0), 44100), 0)).toThrow(RangeError);
  });

  it("h: stereo handling", () => {
    const mono = sine(1000, 0.8, 1);
    const stereoBoth = new Float32Array(mono.length * 2);
    for (let i = 0; i < mono.length; i++) {
      stereoBoth[i * 2] = mono[i];
      stereoBoth[i * 2 + 1] = mono[i];
    }
    const monoTrack = buildAnalysisTrack(mono, 44100);
    const stereoTrack = buildAnalysisTrack(stereoBoth, 44100, { channels: 2 });
    expect(stereoTrack.frameCount).toBe(monoTrack.frameCount);
    expect(stereoTrack.data.length).toBe(monoTrack.data.length);
    for (let i = 0; i < monoTrack.data.length; i++) {
      expect(Math.abs(stereoTrack.data[i] - monoTrack.data[i])).toBeLessThan(1e-6);
    }

    const stereoCancel = new Float32Array(mono.length * 2);
    for (let i = 0; i < mono.length; i++) {
      stereoCancel[i * 2] = mono[i];
      stereoCancel[i * 2 + 1] = -mono[i];
    }
    const cancelled = buildAnalysisTrack(stereoCancel, 44100, { channels: 2 });
    for (let i = 0; i < cancelled.data.length; i++) {
      expect(cancelled.data[i]).toBe(0);
    }

    expect(() => buildAnalysisTrack(new Float32Array(3), 44100, { channels: 2 })).toThrow(RangeError);
  });

  it("i: fft matches naive DFT", () => {
    const rand = lcg(12345);
    const n = 64;
    const re = new Float64Array(n);
    const im = new Float64Array(n);
    for (let i = 0; i < n; i++) {
      re[i] = rand() * 2 - 1;
      im[i] = rand() * 2 - 1;
    }
    const srcRe = Float64Array.from(re);
    const srcIm = Float64Array.from(im);
    fft(re, im);
    for (let k = 0; k < n; k++) {
      let eRe = 0;
      let eIm = 0;
      for (let m = 0; m < n; m++) {
        const ang = (2 * Math.PI * k * m) / n;
        const c = Math.cos(ang);
        const s = Math.sin(ang);
        eRe += srcRe[m] * c + srcIm[m] * s;
        eIm += -srcRe[m] * s + srcIm[m] * c;
      }
      expect(Math.abs(re[k] - eRe)).toBeLessThan(1e-9);
      expect(Math.abs(im[k] - eIm)).toBeLessThan(1e-9);
    }
    expect(() => fft(new Float64Array(12), new Float64Array(12))).toThrow(RangeError);
  });

  it("j: layout invariants on noise", () => {
    const rand = lcg(987654321);
    const n = 44100 * 2;
    const pcm = new Float32Array(n);
    for (let i = 0; i < n; i++) pcm[i] = rand() - 0.5;
    const track = buildAnalysisTrack(pcm, 44100);
    expect(track.data.length).toBe(track.frameCount * ANALYSIS_STRIDE);
    for (let i = 0; i < track.data.length; i++) {
      const v = track.data[i];
      expect(Number.isFinite(v)).toBe(true);
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThanOrEqual(1);
    }
  });

  it("k: spectrum peak contains 1000 Hz", () => {
    const pcm = sine(1000, 0.8, 1);
    const track = buildAnalysisTrack(pcm, 44100, { normalise: false });
    const mid = Math.floor(track.frameCount / 2);
    const f = frameAt(track, mid);
    const edges = analysisBandEdges(44100);
    let target = -1;
    for (let b = 0; b < 64; b++) {
      if (edges[b] <= 1000 && 1000 < edges[b + 1]) {
        target = b;
        break;
      }
    }
    expect(target).toBeGreaterThanOrEqual(0);
    let best = 0;
    let bestIdx = 0;
    for (let b = 0; b < f.spectrum.length; b++) {
      if (f.spectrum[b] > best) {
        best = f.spectrum[b];
        bestIdx = b;
      }
    }
    expect(bestIdx).toBe(target);
  });
});
