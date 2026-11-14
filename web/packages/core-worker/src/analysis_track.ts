import {
  ANALYSIS_BAND_COUNT,
  ANALYSIS_STRIDE,
  analysisBandEdges,
  bandEnergies,
  normaliseTrack,
} from "@slowverb/shared";
import type { AnalysisTrack } from "@slowverb/shared";

export interface AnalysisOptions {
  readonly fftSize?: number;
  readonly hopSize?: number;
  readonly channels?: 1 | 2;
  readonly normalise?: boolean;
}

function isPowerOfTwo(n: number): boolean {
  if (!Number.isInteger(n)) return false;
  if (n < 1) return false;
  let v = n;
  while (v % 2 === 0) v /= 2;
  return v === 1;
}

export function fft(re: Float64Array, im: Float64Array): void {
  if (re.length !== im.length) throw new RangeError("fft: re/im length mismatch");
  const n = re.length;
  if (n < 2 || !isPowerOfTwo(n)) throw new RangeError("fft: length must be a power of two >= 2");

  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    while (j & bit) {
      j ^= bit;
      bit >>= 1;
    }
    j ^= bit;
    if (i < j) {
      const tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      const ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }

  for (let len = 2; len <= n; len <<= 1) {
    const ang = (-2 * Math.PI) / len;
    const wlenRe = Math.cos(ang);
    const wlenIm = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let wRe = 1;
      let wIm = 0;
      const half = len >> 1;
      for (let j = 0; j < half; j++) {
        const uRe = re[i + j];
        const uIm = im[i + j];
        const vRe = re[i + j + half] * wRe - im[i + j + half] * wIm;
        const vIm = re[i + j + half] * wIm + im[i + j + half] * wRe;
        re[i + j] = uRe + vRe;
        im[i + j] = uIm + vIm;
        re[i + j + half] = uRe - vRe;
        im[i + j + half] = uIm - vIm;
        const nRe = wRe * wlenRe - wIm * wlenIm;
        wIm = wRe * wlenIm + wIm * wlenRe;
        wRe = nRe;
      }
    }
  }
}

export function buildAnalysisTrack(
  pcm: Float32Array,
  sampleRate: number,
  options?: AnalysisOptions
): AnalysisTrack {
  if (!Number.isFinite(sampleRate) || sampleRate <= 0) {
    throw new RangeError("buildAnalysisTrack: sampleRate must be finite and > 0");
  }
  const fftSize = options?.fftSize ?? 2048;
  const hopSize = options?.hopSize ?? 1024;
  const channels = options?.channels ?? 1;
  if (!isPowerOfTwo(fftSize) || fftSize < 32) {
    throw new RangeError("buildAnalysisTrack: fftSize must be a power of two >= 32");
  }
  if (!Number.isInteger(hopSize) || hopSize < 1) {
    throw new RangeError("buildAnalysisTrack: hopSize must be an integer >= 1");
  }
  if (channels !== 1 && channels !== 2) {
    throw new RangeError("buildAnalysisTrack: channels must be 1 or 2");
  }
  if (channels === 2 && pcm.length % 2 !== 0) {
    throw new RangeError("buildAnalysisTrack: stereo pcm length must be even");
  }

  let mono: Float32Array;
  if (channels === 2) {
    const frames = pcm.length / 2;
    mono = new Float32Array(frames);
    for (let i = 0; i < frames; i++) {
      mono[i] = (pcm[i * 2] + pcm[i * 2 + 1]) / 2;
    }
  } else {
    mono = pcm;
  }
  const len = mono.length;

  const frameCount = len === 0 ? 0 : Math.ceil(len / hopSize);
  const fps = sampleRate / hopSize;
  const data = new Float32Array(frameCount * ANALYSIS_STRIDE);

  const window = new Float64Array(fftSize);
  for (let i = 0; i < fftSize; i++) {
    window[i] = 0.5 * (1 - Math.cos((2 * Math.PI * i) / fftSize));
  }
  const edges = analysisBandEdges(sampleRate);
  const binHz = sampleRate / fftSize;
  const re = new Float64Array(fftSize);
  const im = new Float64Array(fftSize);
  const mag = new Float32Array(fftSize / 2 + 1);
  const half = fftSize / 2;

  // Bin range per band, computed once: bins k with lo <= k*binHz < hi. A band with no
  // bin uses the single bin nearest its geometric centre.
  const bandFirst = new Int32Array(ANALYSIS_BAND_COUNT);
  const bandLast = new Int32Array(ANALYSIS_BAND_COUNT);
  for (let b = 0; b < ANALYSIS_BAND_COUNT; b++) {
    const lo = edges[b];
    const hi = edges[b + 1];
    const first = Math.max(0, Math.ceil(lo / binHz));
    const last = Math.min(half, Math.ceil(hi / binHz) - 1);
    if (first <= last) {
      bandFirst[b] = first;
      bandLast[b] = last;
    } else {
      const idx = Math.min(half, Math.max(0, Math.round(Math.sqrt(lo * hi) / binHz)));
      bandFirst[b] = idx;
      bandLast[b] = idx;
    }
  }

  for (let f = 0; f < frameCount; f++) {
    const start = f * hopSize;
    let sumSq = 0;
    for (let i = 0; i < fftSize; i++) {
      const idx = start + i;
      const v = idx < len ? mono[idx] : 0;
      sumSq += v * v;
      re[i] = v * window[i];
      im[i] = 0;
    }
    const rms = Math.sqrt(sumSq / fftSize);
    fft(re, im);
    for (let k = 0; k <= half; k++) {
      mag[k] = Math.sqrt(re[k] * re[k] + im[k] * im[k]) / half;
    }
    const base = f * ANALYSIS_STRIDE;
    for (let b = 0; b < ANALYSIS_BAND_COUNT; b++) {
      let best = 0;
      for (let k = bandFirst[b]; k <= bandLast[b]; k++) {
        if (mag[k] > best) best = mag[k];
      }
      data[base + b] = best > 1 ? 1 : best;
    }
    const { bass, mid, treble } = bandEnergies(mag, sampleRate, fftSize);
    data[base + ANALYSIS_BAND_COUNT] = rms;
    data[base + ANALYSIS_BAND_COUNT + 1] = bass;
    data[base + ANALYSIS_BAND_COUNT + 2] = mid;
    data[base + ANALYSIS_BAND_COUNT + 3] = treble;
  }

  const track: AnalysisTrack = { sampleRate, fps, frameCount, data };
  if (options?.normalise !== false) return normaliseTrack(track);
  return track;
}
