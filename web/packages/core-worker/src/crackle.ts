export const MAX_POPS_PER_SEC = 8;
export const POP_DECAY = 0.985;

export function xorshift32(seed: number): () => number {
  let s = (seed >>> 0) || 0x9e3779b9;
  return () => {
    s ^= s << 13;
    s ^= s >>> 17;
    s ^= s << 5;
    s >>>= 0;
    return s / 4294967296;
  };
}

function clampIntensity(intensity: number): number {
  if (typeof intensity !== "number" || Number.isNaN(intensity)) return 0;
  if (intensity <= 0) return 0;
  if (intensity >= 1) return 1;
  return intensity;
}

function validateFramesAndRate(frames: number, sampleRate: number): void {
  if (!Number.isInteger(frames) || frames < 0) {
    throw new RangeError(`Invalid frames: ${String(frames)}`);
  }
  if (typeof sampleRate !== "number" || !Number.isFinite(sampleRate) || sampleRate <= 0) {
    throw new RangeError(`Invalid sampleRate: ${String(sampleRate)}`);
  }
}

export function planCracklePops(
  seed: number,
  frames: number,
  intensity: number,
  sampleRate: number
): Uint32Array {
  validateFramesAndRate(frames, sampleRate);
  const i = clampIntensity(intensity);
  if (i === 0 || frames === 0) return new Uint32Array(0);
  const rng = xorshift32(seed);
  const popsPerSec = MAX_POPS_PER_SEC * i;
  const slot = sampleRate / popsPerSec;
  const onsets: number[] = [];
  for (let k = 0; k * slot < frames; k += 1) {
    const r1 = rng();
    const r2 = rng();
    if (r1 < 0.7) {
      const onset = Math.floor(k * slot + r2 * slot);
      if (onset < frames) onsets.push(onset);
    }
  }
  return Uint32Array.from(onsets);
}

function clampSample(v: number): number {
  if (v > 1) return 1;
  if (v < -1) return -1;
  return v;
}

export function renderCrackleBed(
  seed: number,
  frames: number,
  intensity: number,
  sampleRate: number
): Float32Array {
  validateFramesAndRate(frames, sampleRate);
  const i = clampIntensity(intensity);
  const out = new Float32Array(frames * 2);
  if (i === 0) return out;
  const hrng = xorshift32((seed ^ 0xa5a5a5a5) >>> 0);
  const hissGain = 0.004 * i;
  const onsets = planCracklePops(seed, frames, i, sampleRate);
  const prng = xorshift32((seed ^ 0x5bd1e995) >>> 0);
  let yL = 0;
  let yR = 0;
  let envL = 0;
  let envR = 0;
  let onsetIdx = 0;
  for (let n = 0; n < frames; n += 1) {
    const xL = (hrng() * 2 - 1) * hissGain;
    const xR = (hrng() * 2 - 1) * hissGain;
    yL += 0.35 * (xL - yL);
    yR += 0.35 * (xR - yR);
    while (onsetIdx < onsets.length && onsets[onsetIdx] === n) {
      const a = (0.15 + 0.35 * prng()) * i;
      const bal = prng();
      envL = a * (0.6 + 0.4 * bal);
      envR = a * (0.6 + 0.4 * (1 - bal));
      onsetIdx += 1;
    }
    let popL = 0;
    let popR = 0;
    if (envL > 1e-5 || envR > 1e-5) {
      const popNoise = prng() * 2 - 1;
      popL = envL * popNoise;
      popR = envR * popNoise;
    }
    envL *= POP_DECAY;
    envR *= POP_DECAY;
    out[2 * n] = clampSample(yL + popL);
    out[2 * n + 1] = clampSample(yR + popR);
  }
  return out;
}

export function mixCrackleInto(pcm: Float32Array, bed: Float32Array): void {
  if (pcm.length !== bed.length) {
    throw new RangeError(`Length mismatch: pcm=${pcm.length} bed=${bed.length}`);
  }
  for (let j = 0; j < pcm.length; j += 1) {
    pcm[j] += bed[j];
  }
}
