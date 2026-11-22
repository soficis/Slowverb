/**
 * Offline audio-analysis track: per-frame spectrum bands plus rms/bass/mid/treble,
 * computed from rendered PCM in the worker and read by the visualizers.
 */

export const ANALYSIS_BAND_COUNT = 64;
/** 64 spectrum bands, then rms, bass, mid, treble. */
export const ANALYSIS_STRIDE = ANALYSIS_BAND_COUNT + 4;

const RMS_OFFSET = ANALYSIS_BAND_COUNT;
const BASS_OFFSET = ANALYSIS_BAND_COUNT + 1;
const MID_OFFSET = ANALYSIS_BAND_COUNT + 2;
const TREBLE_OFFSET = ANALYSIS_BAND_COUNT + 3;

export const ANALYSIS_MIN_HZ = 20;
export const ANALYSIS_MAX_HZ = 16000;
export const ANALYSIS_NORMALISED_PEAK = 0.95;

const BASS_HZ = [20, 200] as const;
const MID_HZ = [200, 2000] as const;
const TREBLE_HZ = [2000, 16000] as const;

/**
 * sqrt(sum of squared Hann-windowed magnitudes normalised by fftSize/2) for a sine of
 * amplitude A is A * sqrt(3/8). Dividing by this makes a band's energy read A.
 */
const HANN_ENERGY_GAIN = Math.sqrt(3 / 8);

export interface AnalysisTrack {
  readonly sampleRate: number;
  readonly fps: number;
  readonly frameCount: number;
  /** Flat, frameCount * ANALYSIS_STRIDE values, frame-major. */
  readonly data: Float32Array;
}

export interface AnalysisFrame {
  /** ANALYSIS_BAND_COUNT values; a view into track.data, not a copy. */
  readonly spectrum: Float32Array;
  readonly rms: number;
  readonly bass: number;
  readonly mid: number;
  readonly treble: number;
}

export interface BandEnergies {
  readonly bass: number;
  readonly mid: number;
  readonly treble: number;
}

/** Index is clamped to [0, frameCount - 1]. Throws on an empty track. */
export function frameAt(track: AnalysisTrack, index: number): AnalysisFrame {
  if (track.frameCount <= 0) throw new RangeError("frameAt: track has no frames");
  const i = Math.min(track.frameCount - 1, Math.max(0, Math.floor(Number.isFinite(index) ? index : 0)));
  const base = i * ANALYSIS_STRIDE;
  const data = track.data;
  return {
    spectrum: data.subarray(base, base + ANALYSIS_BAND_COUNT),
    rms: data[base + RMS_OFFSET],
    bass: data[base + BASS_OFFSET],
    mid: data[base + MID_OFFSET],
    treble: data[base + TREBLE_OFFSET],
  };
}

/**
 * Upper frequency for the band layout: min(16 kHz, Nyquist).
 */
export function analysisMaxHz(sampleRate: number): number {
  return Math.min(ANALYSIS_MAX_HZ, sampleRate / 2);
}

/**
 * ANALYSIS_BAND_COUNT + 1 log-spaced edges from 20 Hz to analysisMaxHz(sampleRate).
 * Band i covers [edges[i], edges[i + 1]).
 */
export function analysisBandEdges(sampleRate: number): Float64Array {
  const maxHz = analysisMaxHz(sampleRate);
  const edges = new Float64Array(ANALYSIS_BAND_COUNT + 1);
  const ratio = maxHz / ANALYSIS_MIN_HZ;
  for (let i = 0; i <= ANALYSIS_BAND_COUNT; i++) {
    edges[i] = ANALYSIS_MIN_HZ * Math.pow(ratio, i / ANALYSIS_BAND_COUNT);
  }
  return edges;
}

/**
 * Energy per range from a one-sided magnitude spectrum (fftSize / 2 + 1 bins, each
 * normalised by fftSize / 2, Hann-windowed). Value = sqrt(sum of squared magnitudes of
 * bins whose centre lies in [lo, hi)) / sqrt(3/8), clamped to [0, 1]. A sine of
 * amplitude A inside a range reads ~A; the value does not depend on how wide the range is.
 * Ranges: bass 20-200 Hz, mid 200-2000 Hz, treble 2000-16000 Hz.
 */
export function bandEnergies(magnitudes: Float32Array, sampleRate: number, fftSize: number): BandEnergies {
  const binHz = sampleRate / fftSize;
  const energy = (lo: number, hi: number): number => {
    const first = Math.max(0, Math.ceil(lo / binHz));
    const last = Math.min(magnitudes.length - 1, Math.ceil(hi / binHz) - 1);
    let sum = 0;
    for (let k = first; k <= last; k++) sum += magnitudes[k] * magnitudes[k];
    return Math.min(1, Math.sqrt(sum) / HANN_ENERGY_GAIN);
  };
  return {
    bass: energy(BASS_HZ[0], BASS_HZ[1]),
    mid: energy(MID_HZ[0], MID_HZ[1]),
    treble: energy(TREBLE_HZ[0], TREBLE_HZ[1]),
  };
}

/**
 * Peak-normalise three groups independently so each group's loudest value is 0.95:
 *   1. rms
 *   2. the 64 spectrum bands (one factor for all bands and frames)
 *   3. bass, mid, treble (one shared factor, so their relative balance is kept)
 * A group whose peak is 0 stays 0. Results are clamped to [0, 1]. Returns a new track;
 * the input is not modified.
 */
export function normaliseTrack(track: AnalysisTrack): AnalysisTrack {
  const src = track.data;
  const out = new Float32Array(src.length);
  const frames = track.frameCount;

  let rmsPeak = 0;
  let spectrumPeak = 0;
  let rangePeak = 0;
  for (let f = 0; f < frames; f++) {
    const base = f * ANALYSIS_STRIDE;
    for (let b = 0; b < ANALYSIS_BAND_COUNT; b++) spectrumPeak = Math.max(spectrumPeak, src[base + b]);
    rmsPeak = Math.max(rmsPeak, src[base + RMS_OFFSET]);
    rangePeak = Math.max(rangePeak, src[base + BASS_OFFSET], src[base + MID_OFFSET], src[base + TREBLE_OFFSET]);
  }

  const gain = (peak: number): number => (peak > 0 ? ANALYSIS_NORMALISED_PEAK / peak : 0);
  const rmsGain = gain(rmsPeak);
  const spectrumGain = gain(spectrumPeak);
  const rangeGain = gain(rangePeak);
  const scale = (v: number, g: number): number => Math.min(1, Math.max(0, v * g));

  for (let f = 0; f < frames; f++) {
    const base = f * ANALYSIS_STRIDE;
    for (let b = 0; b < ANALYSIS_BAND_COUNT; b++) out[base + b] = scale(src[base + b], spectrumGain);
    out[base + RMS_OFFSET] = scale(src[base + RMS_OFFSET], rmsGain);
    out[base + BASS_OFFSET] = scale(src[base + BASS_OFFSET], rangeGain);
    out[base + MID_OFFSET] = scale(src[base + MID_OFFSET], rangeGain);
    out[base + TREBLE_OFFSET] = scale(src[base + TREBLE_OFFSET], rangeGain);
  }

  return { sampleRate: track.sampleRate, fps: track.fps, frameCount: frames, data: out };
}
