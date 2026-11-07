import type { RenderPayload } from "@slowverb/shared";
import { SimpleFilter, SoundTouch } from "soundtouchjs";
import { clamp01 } from "./worker_utils.js";

export function applySoundTouch(
  input: Float32Array,
  tempo: number,
  pitchSemitones: number,
  onProgress?: (percent: number) => void
): Float32Array {
  const totalFrames = Math.floor(input.length / 2);

  const soundTouch = new SoundTouch();
  soundTouch.stretch?.setParameters?.(44100, 0, 0, 0);
  soundTouch.tempo = tempo;
  soundTouch.pitchSemitones = pitchSemitones;

  class InterleavedStereoSource {
    private position = 0;
    constructor(private readonly samples: Float32Array) { }
    extract(target: Float32Array, numFrames: number = 0, position: number = 0): number {
      this.position = position;
      const start = position * 2;
      const availableFrames = Math.max(0, Math.floor((this.samples.length - start) / 2));
      const frames = Math.max(0, Math.min(numFrames, availableFrames));
      if (frames > 0) {
        target.set(this.samples.subarray(start, start + frames * 2));
      }
      return frames;
    }
  }

  // SimpleFilter never flushes SoundTouch's internal buffers, so the last ~0.35 s of input was
  // dropped. Feed trailing silence to push it through, then trim to the exact stretched length.
  const flushFrames = 2 * 44100;
  const padded = new Float32Array(input.length + flushFrames * 2);
  padded.set(input);
  const expectedFrames = Math.round(totalFrames / tempo);

  const filter = new SimpleFilter(new InterleavedStereoSource(padded), soundTouch);
  const chunkFrames = 16384;
  const chunk = new Float32Array(chunkFrames * 2);
  const chunks: Float32Array[] = [];

  let lastEmit = -1;
  for (; ;) {
    const frames = filter.extract(chunk, chunkFrames);
    if (frames === 0) break;
    chunks.push(chunk.slice(0, frames * 2));

    if (onProgress) {
      const sourceFrames = filter.sourcePosition ?? 0;
      const percent = totalFrames > 0 ? clamp01(sourceFrames / totalFrames) : 1;
      if (percent - lastEmit >= 0.05) {
        onProgress(percent);
        lastEmit = percent;
      }
    }
  }

  const producedSamples = chunks.reduce((sum, block) => sum + block.length, 0);
  const output = new Float32Array(Math.min(producedSamples, expectedFrames * 2));
  let offset = 0;
  for (const block of chunks) {
    if (offset >= output.length) break;
    const take = Math.min(block.length, output.length - offset);
    output.set(block.subarray(0, take), offset);
    offset += take;
  }
  return output;
}

// A stuck PhaseLimiter worker would otherwise hang the render (and leak the worker) forever.
const PHASE_LIMITER_TIMEOUT_MS = 30 * 60 * 1000;

export async function processWithPhaseLimiter(options: {
  leftChannel: Float32Array;
  rightChannel: Float32Array;
  sampleRate: number;
  algorithm: string;
  mastering?: RenderPayload["mastering"];
  progressRange: { offset: number; scale: number };
  onProgress: (value: number) => void;
}): Promise<{ left: Float32Array; right: Float32Array }> {
  const {
    leftChannel,
    rightChannel,
    sampleRate,
    algorithm,
    mastering,
    progressRange,
    onProgress,
  } = options;

  return new Promise((resolve, reject) => {
    const isPro = algorithm === "phaselimiter_pro";
    const workerScript = isPro ? "/js/phase_limiter_pro_worker.js" : "/js/phase_limiter_worker.js";
    const masteringConfig = mastering ?? {};
    const config = isPro
      ? { mode: Math.round(masteringConfig.mode ?? 5) }
      : {
        targetLufs: typeof masteringConfig.targetLufs === "number" ? masteringConfig.targetLufs : -14.0,
        bassPreservation:
          typeof masteringConfig.bassPreservation === "number"
            ? masteringConfig.bassPreservation
            : 0.5,
      };
    const worker = new Worker(workerScript);
    const timeout = setTimeout(() => {
      worker.removeEventListener("message", onMessage);
      worker.removeEventListener("error", onError);
      worker.terminate();
      reject(new Error("PhaseLimiter timed out"));
    }, PHASE_LIMITER_TIMEOUT_MS);

    const onMessage = (event: MessageEvent) => {
      const data = event.data ?? {};
      const type = data.type;
      if (type === "progress") {
        const percent = typeof data.percent === "number" ? data.percent : 0;
        const scaled = progressRange.offset + clamp01(percent) * progressRange.scale;
        onProgress(scaled);
        return;
      }
      if (type === "complete") {
        worker.removeEventListener("message", onMessage);
        worker.removeEventListener("error", onError);
        clearTimeout(timeout);
        worker.terminate();

        const left = data.leftChannel;
        const right = data.rightChannel;
        if (!(left instanceof Float32Array) || !(right instanceof Float32Array)) {
          reject(new Error("Invalid PhaseLimiter worker result"));
          return;
        }
        resolve({ left, right });
        return;
      }
      if (type === "error") {
        worker.removeEventListener("message", onMessage);
        worker.removeEventListener("error", onError);
        clearTimeout(timeout);
        worker.terminate();
        reject(new Error(data.error ?? "PhaseLimiter worker error"));
      }
    };

    const onError = (event: ErrorEvent) => {
      worker.removeEventListener("message", onMessage);
      worker.removeEventListener("error", onError);
      clearTimeout(timeout);
      worker.terminate();
      reject(new Error(event.message || "PhaseLimiter worker crashed"));
    };

    worker.addEventListener("message", onMessage);
    worker.addEventListener("error", onError);

    try {
      worker.postMessage(
        {
          leftChannel,
          rightChannel,
          sampleRate,
          config,
        },
        [leftChannel.buffer, rightChannel.buffer]
      );
    } catch (error) {
      worker.removeEventListener("message", onMessage);
      worker.removeEventListener("error", onError);
      clearTimeout(timeout);
      worker.terminate();
      reject(error);
    }
  });
}
