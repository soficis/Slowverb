/**
 * Freeverb impulse response generator.
 *
 * Implements the SoX Freeverb algorithm: 8 parallel comb filters with
 * one-pole lowpass damping in each feedback path, followed by 4 serial
 * allpass filters (Schroeder allpass). Produces a stereo interleaved
 * Float32Array suitable for FFmpeg's afir convolution reverb filter.
 *
 * Pure JavaScript — no browser API dependencies (AudioContext,
 * OfflineAudioContext, Tone.js). Safe for Web Worker use.
 *
 * ## Algorithm reference
 *
 * SoX's reverb effect is based on the Freeverb algorithm by
 * "Jezar at Dreampoint". Each comb filter uses a delay line whose
 * output is fed back through a one-pole lowpass filter. The allpass
 * filters smear the combined comb output in time without colouration.
 *
 * | Filter type | Count | Configuration |
 * |---|---|---|
 * | Comb | 8 | Delay 1116–1617 samples, scaled by roomScale |
 * | Allpass | 4 | Delay 225–556 samples, gain 0.5 (fixed) |
 *
 * For stereo, right-channel comb delays receive a 12-sample offset
 * (scaled by stereoDepth).
 *
 * @module freeverb-ir-generator
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface FreeverbParams {
  /** Reverb tail length, 0–100 (SoX reverberance). */
  readonly reverberance: number;
  /** High-frequency damping, 0–100. */
  readonly hfDamping: number;
  /** Room size, 0–100. Scales comb filter delays. */
  readonly roomScale: number;
  /** Stereo separation, 0–100. Scales the right-channel delay offset. */
  readonly stereoDepth: number;
  /** Pre-delay before reverb onset, 0–500 ms. */
  readonly preDelayMs: number;
  /** Sample rate of the generated IR (must match the target audio). */
  readonly sampleRate: number;
  /** Length of the impulse response in seconds (excluding pre-delay). */
  readonly durationSec: number;
}

export interface FreeverbIRResult {
  /** Stereo interleaved Float32Array samples as an ArrayBuffer. */
  readonly pcm: ArrayBuffer;
  /** Sample rate used for generation. */
  readonly sampleRate: number;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/**
 * Comb filter delay lengths (in samples at 44.1 kHz) from the original
 * Freeverb by Jezar at Dreampoint.
 */
const COMB_DELAYS: readonly number[] = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617] as const;

/**
 * Allpass filter delay lengths (in samples at 44.1 kHz).
 * These are NOT scaled by roomScale.
 */
const ALLPASS_DELAYS: readonly number[] = [225, 341, 441, 556] as const;

/**
 * Stereo offset applied to right-channel comb filter delays (samples).
 * Scaled by stereoDepth / 100.
 */
const STEREO_OFFSET = 12;

/**
 * Allpass filter gain coefficient (fixed per Jezar's Freeverb).
 */
const ALLPASS_GAIN = 0.5;

/**
 * Target peak amplitude after normalisation: –1 dBFS ≈ 0.891.
 * Leaves headroom to prevent intersample peaks during convolution.
 */
const TARGET_PEAK = 10 ** (-1 / 20); // 0.8912509381

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Compute the comb filter feedback coefficient from the reverberance
 * control value (0–100). Higher values produce longer reverb tails.
 *
 * Derived from SoX source:
 *   feedback = 1 − exp((reverberance + 10.032) / −28.123)
 */
function calcFeedback(reverberance: number): number {
  return 1 - Math.exp((reverberance + 10.032) / -28.123);
}

/**
 * Compute the one-pole lowpass damping coefficient from the HF-damping
 * control value (0–100). Higher values damp high-frequencies more.
 *
 * Derived from SoX source:
 *   damp = hfDamping / 100 × 0.3 + 0.2
 */
function calcDamping(hfDamping: number): number {
  return (hfDamping / 100) * 0.3 + 0.2;
}

// ---------------------------------------------------------------------------
// Processing
// ---------------------------------------------------------------------------

/**
 * Feed a single input sample through one Freeverb comb filter and capture
 * the delay-line output (before writing back).
 *
 * The comb filter consists of a delay line whose output is fed back
 * through a one-pole lowpass filter:
 *
 *   output ← delay[writeIdx]
 *   lpState ← output × (1−damp) + lpState × damp
 *   delay[writeIdx] ← input + feedback × lpState
 *
 * @param buffer  Delay-line buffer (mutated in place).
 * @param length  Length of the delay line (samples).
 * @param writeIdx  Current write index (mutated).
 * @param input  The input sample for this tick.
 * @param feedback  Comb filter feedback coefficient.
 * @param damp  One-pole lowpass coefficient.
 * @param lpState  Persistent lowpass filter state (mutated).
 * @returns The delay-line output **before** the new value is written.
 */
function processComb(
  buffer: Float64Array,
  length: number,
  writeIdx: number,
  input: number,
  feedback: number,
  damp: number,
  lpState: number,
): { readonly output: number; readonly nextWriteIdx: number; readonly nextLpState: number } {
  const output = buffer[writeIdx];

  // One-pole lowpass: y[n] = x[n] × (1−a) + y[n−1] × a
  const nextLpState = output * (1 - damp) + lpState * damp;

  buffer[writeIdx] = input + feedback * nextLpState;

  const nextWriteIdx = (writeIdx + 1) % length;

  return { output, nextWriteIdx, nextLpState };
}

/**
 * Feed a single input sample through one Freeverb allpass filter.
 *
 * The Schroeder allpass filter spreads energy in time without colouration:
 *
 *   bufOut    ← delay[writeIdx]
 *   delay[writeIdx] ← input + gain × bufOut
 *   output    ← −input + bufOut
 *
 * @param buffer  Delay-line buffer (mutated in place).
 * @param length  Length of the delay line (samples).
 * @param writeIdx  Current write index (mutated).
 * @param input  The input sample for this tick.
 * @param gain  Allpass gain coefficient (typically 0.5).
 * @returns The filtered output sample.
 */
function processAllpass(
  buffer: Float64Array,
  length: number,
  writeIdx: number,
  input: number,
  gain: number,
): { readonly output: number; readonly nextWriteIdx: number } {
  const bufOut = buffer[writeIdx];
  buffer[writeIdx] = input + gain * bufOut;
  const output = -input + bufOut;
  const nextWriteIdx = (writeIdx + 1) % length;
  return { output, nextWriteIdx };
}

/**
 * Create the impulse response key string for cache look-up.
 */
function makeCacheKey(params: FreeverbParams): string {
  const { reverberance, hfDamping, roomScale, stereoDepth, preDelayMs, sampleRate, durationSec } = params;
  return `${reverberance.toFixed(1)}_${hfDamping.toFixed(1)}_${roomScale.toFixed(1)}_${stereoDepth.toFixed(1)}_${preDelayMs.toFixed(0)}_${sampleRate}_${durationSec.toFixed(2)}`;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * FreeverbIRGenerator caches generated impulse responses by parameter key
 * to avoid redundant computation for repeated parameter sets.
 */
export class FreeverbIRGenerator {
  private readonly cache = new Map<string, FreeverbIRResult>();

  /**
   * Generate a Freeverb impulse response for the given parameters, or
   * return a cached result if these exact parameters have been used before.
   *
   * The returned `ArrayBuffer` is a **shared reference** to the cached
   * buffer. Callers that mutate the underlying `Float32Array` must make a
   * copy first (`new Float32Array(result.pcm)`).
   */
  generate(params: FreeverbParams): FreeverbIRResult {
    const key = makeCacheKey(params);
    const cached = this.cache.get(key);
    if (cached !== undefined) {
      return cached;
    }

    const result = generateFreeverbIR(params);
    this.cache.set(key, result);
    return result;
  }

  /** Clear all cached impulse responses. */
  clearCache(): void {
    this.cache.clear();
  }
}

/**
 * Generate a Freeverb impulse response as a stereo interleaved Float32Array
 * backed by an ArrayBuffer, using only pure-JavaScript arithmetic.
 *
 * @param params  Freeverb parameter set.
 * @returns  An object containing the PCM buffer and the sample rate used.
 *
 * ## Processing stages
 *
 * 1. **Parameter mapping** — convert user controls to feedback, damping,
 *    room-scale, and stereo-depth coefficients.
 * 2. **Impulse injection** — a Dirac impulse (1.0) is fed into the Freeverb
 *    network at sample index `preDelaySamples`, preceded by silence.
 * 3. **Comb section** — the impulse passes through 8 parallel comb filters.
 *    Each comb has a one-pole lowpass filter in its feedback path. The
 *    right channel uses delay lines offset by `stereoOffset` samples.
 * 4. **Allpass section** — the summed comb outputs pass through 4 serial
 *    Schroeder allpass filters (gain = 0.5).
 * 5. **Normalisation** — the entire IR is scaled so its peak amplitude
 *    equals -1 dBFS (≈ 0.891), preventing headroom issues when the IR is
 *    used in convolution.
 */
export function generateFreeverbIR(params: FreeverbParams): FreeverbIRResult {
  const {
    reverberance,
    hfDamping,
    roomScale,
    stereoDepth,
    preDelayMs,
    sampleRate,
    durationSec,
  } = params;

  // -----------------------------------------------------------------------
  // 1. Parameter mapping
  // -----------------------------------------------------------------------

  const feedback = calcFeedback(reverberance);
  const damp = calcDamping(hfDamping);
  const roomScaleFactor = (roomScale / 100) * 0.9 + 0.1;
  const depthFactor = stereoDepth / 100;
  const stereoOffset = Math.round(STEREO_OFFSET * depthFactor);

  // Scale comb delays by roomScale; ensure minimum delay of 1 sample.
  const leftCombDelays = COMB_DELAYS.map((d) => Math.max(1, Math.round(d * roomScaleFactor)));
  const rightCombDelays = COMB_DELAYS.map((d) => Math.max(1, Math.round(d * roomScaleFactor + stereoOffset)));

  // Allpass delays are NOT scaled by roomScale.
  const allpassDelays = [...ALLPASS_DELAYS];

  // -----------------------------------------------------------------------
  // 2. Allocate delay-line state
  // -----------------------------------------------------------------------

  const NUM_COMBS = COMB_DELAYS.length;
  const NUM_ALLPASS = ALLPASS_DELAYS.length;

  // Left-channel comb filters
  const leftCombBuf: Float64Array[] = [];
  const leftCombIdx: number[] = [];
  const leftLpState: number[] = [];
  for (let i = 0; i < NUM_COMBS; i++) {
    leftCombBuf.push(new Float64Array(leftCombDelays[i]));
    leftCombIdx.push(0);
    leftLpState.push(0);
  }

  // Right-channel comb filters
  const rightCombBuf: Float64Array[] = [];
  const rightCombIdx: number[] = [];
  const rightLpState: number[] = [];
  for (let i = 0; i < NUM_COMBS; i++) {
    rightCombBuf.push(new Float64Array(rightCombDelays[i]));
    rightCombIdx.push(0);
    rightLpState.push(0);
  }

  // Left-channel allpass filters
  const leftApBuf: Float64Array[] = [];
  const leftApIdx: number[] = [];
  for (let i = 0; i < NUM_ALLPASS; i++) {
    leftApBuf.push(new Float64Array(allpassDelays[i]));
    leftApIdx.push(0);
  }

  // Right-channel allpass filters
  const rightApBuf: Float64Array[] = [];
  const rightApIdx: number[] = [];
  for (let i = 0; i < NUM_ALLPASS; i++) {
    rightApBuf.push(new Float64Array(allpassDelays[i]));
    rightApIdx.push(0);
  }

  // -----------------------------------------------------------------------
  // 3. Generate the impulse response
  // -----------------------------------------------------------------------

  const reverbSamples = Math.floor(sampleRate * durationSec);
  const preDelaySamples = Math.floor((preDelayMs / 1000) * sampleRate);
  const totalSamples = preDelaySamples + reverbSamples;

  // Stereo interleaved output: L, R, L, R, …
  const output = new Float32Array(totalSamples * 2);

  // The impulse is injected at sample index `preDelaySamples`. Everything
  // before that is silence (the output buffer is zero-initialised).
  const impulseSample = preDelaySamples;

  for (let i = 0; i < totalSamples; i++) {
    // Dirac impulse — a single 1.0 sample, silence elsewhere.
    const input = i === impulseSample ? 1.0 : 0.0;

    // -------------------------------------------------------------------
    // Left channel — 8 parallel comb filters
    // -------------------------------------------------------------------
    let leftSum = 0;
    for (let c = 0; c < NUM_COMBS; c++) {
      const {
        output: combOut,
        nextWriteIdx: nextIdx,
        nextLpState: nextLp,
      } = processComb(
        leftCombBuf[c],
        leftCombDelays[c],
        leftCombIdx[c],
        input,
        feedback,
        damp,
        leftLpState[c],
      );
      leftSum += combOut;
      leftCombIdx[c] = nextIdx;
      leftLpState[c] = nextLp;
    }

    // Left channel — 4 serial allpass filters
    let leftOut = leftSum;
    for (let a = 0; a < NUM_ALLPASS; a++) {
      const { output: apOut, nextWriteIdx: nextIdx } = processAllpass(
        leftApBuf[a],
        allpassDelays[a],
        leftApIdx[a],
        leftOut,
        ALLPASS_GAIN,
      );
      leftOut = apOut;
      leftApIdx[a] = nextIdx;
    }

    // -------------------------------------------------------------------
    // Right channel — 8 parallel comb filters
    // -------------------------------------------------------------------
    let rightSum = 0;
    for (let c = 0; c < NUM_COMBS; c++) {
      const {
        output: combOut,
        nextWriteIdx: nextIdx,
        nextLpState: nextLp,
      } = processComb(
        rightCombBuf[c],
        rightCombDelays[c],
        rightCombIdx[c],
        input,
        feedback,
        damp,
        rightLpState[c],
      );
      rightSum += combOut;
      rightCombIdx[c] = nextIdx;
      rightLpState[c] = nextLp;
    }

    // Right channel — 4 serial allpass filters
    let rightOut = rightSum;
    for (let a = 0; a < NUM_ALLPASS; a++) {
      const { output: apOut, nextWriteIdx: nextIdx } = processAllpass(
        rightApBuf[a],
        allpassDelays[a],
        rightApIdx[a],
        rightOut,
        ALLPASS_GAIN,
      );
      rightOut = apOut;
      rightApIdx[a] = nextIdx;
    }

    // Write interleaved stereo
    output[i * 2] = leftOut;
    output[i * 2 + 1] = rightOut;
  }

  // -----------------------------------------------------------------------
  // 4. Normalise to –1 dBFS peak
  // -----------------------------------------------------------------------

  let peak = 0;
  for (let i = 0; i < output.length; i++) {
    const abs = Math.abs(output[i]);
    if (abs > peak) {
      peak = abs;
    }
  }

  if (peak > 0) {
    const gain = TARGET_PEAK / peak;
    for (let i = 0; i < output.length; i++) {
      output[i] *= gain;
    }
  }

  return { pcm: output.buffer, sampleRate };
}
