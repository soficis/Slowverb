import type { RenderPayload } from "@slowverb/shared";
import { readInterleavedF32, resolveTimeStretchParams, writeInterleavedF32 } from "./worker_utils.js";
import { applySoundTouch } from "./worker_effects.js";
import type { WorkerFfmpegBridge } from "./worker_types.js";

interface StageProgress {
  offset: number;
  scale: number;
}

export function runSoundTouchStage(
  ffmpeg: WorkerFfmpegBridge,
  payload: RenderPayload,
  inputFile: string,
  outputFile: string,
  jobId: string,
  progress: StageProgress,
  postProgress: (jobId: string, value: number, stage: string) => void
): string {
  const { tempo, pitchSemitones } = resolveTimeStretchParams(payload);
  postProgress(jobId, progress.offset, "time-stretch");

  const input = readInterleavedF32(ffmpeg.FS, inputFile);
  const stretched = applySoundTouch(input, tempo, pitchSemitones, (percent) => {
    postProgress(jobId, progress.offset + percent * progress.scale, "time-stretch");
  });

  writeInterleavedF32(ffmpeg.FS, outputFile, stretched);
  postProgress(jobId, progress.offset + progress.scale, "time-stretch");
  return outputFile;
}
