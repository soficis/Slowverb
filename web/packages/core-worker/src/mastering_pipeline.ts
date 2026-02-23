import type { MasteringSpec } from "@slowverb/shared";
import { buildPcmFilterPlan, readAndSplitF32Stereo, writeInterleavedF32Stereo } from "./worker_utils.js";
import { processWithPhaseLimiter } from "./worker_effects.js";
import type { WorkerFfmpegBridge } from "./worker_types.js";

interface ProgressRange {
  offset: number;
  scale: number;
}

interface StageContext {
  ffmpeg: WorkerFfmpegBridge;
  fileId: string;
  jobId: string;
  sampleRate: number;
  withProgressStage: (stage: string, offset: number, scale: number, run: () => void) => void;
  postProgress: (jobId: string, value: number, stage: string) => void;
}

interface PhaseLimiterStageInput extends StageContext {
  inputFile: string;
  algorithm: "phaselimiter" | "phaselimiter_pro";
  mastering: MasteringSpec;
  progressRange: ProgressRange;
  isToneReverbEnabled: boolean;
}

export function isSimpleMasteringWithToneReverb(
  mastering: MasteringSpec | undefined,
  toneReverbEnabled: boolean
): boolean {
  return mastering?.enabled === true && mastering?.algorithm === "simple" && toneReverbEnabled;
}

export async function applyPhaseLimiterStage(
  input: PhaseLimiterStageInput
): Promise<{ outputFile: string; tempFiles: string[] }> {
  const {
    ffmpeg,
    fileId,
    jobId,
    sampleRate,
    inputFile,
    algorithm,
    mastering,
    progressRange,
    isToneReverbEnabled,
    withProgressStage,
    postProgress,
  } = input;

  const masteredFile = `${fileId}-${jobId}-mastered.f32`;
  const { left, right } = readAndSplitF32Stereo(ffmpeg.FS, inputFile);

  postProgress(jobId, progressRange.offset, "mastering");
  const processed = await processWithPhaseLimiter({
    leftChannel: left,
    rightChannel: right,
    sampleRate,
    algorithm,
    mastering,
    progressRange,
    onProgress: (value) => postProgress(jobId, value, "mastering"),
  });

  writeInterleavedF32Stereo(ffmpeg.FS, masteredFile, processed.left, processed.right);
  const tempFiles: string[] = [masteredFile];
  let currentFile = masteredFile;

  if (algorithm === "phaselimiter_pro") {
    const boostValue = isToneReverbEnabled ? "6dB" : "4dB";
    const boostedFile = `${fileId}-${jobId}-pro-boosted.f32`;
    const boostArgs = buildPcmFilterPlan(currentFile, boostedFile, `volume=${boostValue}`, sampleRate);
    withProgressStage("mastering-boost", 0.9, 0.0, () => ffmpeg.exec(...boostArgs));
    tempFiles.push(boostedFile);
    currentFile = boostedFile;
  }

  if (algorithm === "phaselimiter") {
    const reducedFile = `${fileId}-${jobId}-lite-reduced.f32`;
    const reduceArgs = buildPcmFilterPlan(currentFile, reducedFile, "volume=-2dB", sampleRate);
    withProgressStage("mastering-reduction", 0.9, 0.0, () => ffmpeg.exec(...reduceArgs));
    tempFiles.push(reducedFile);
    currentFile = reducedFile;
  }

  return { outputFile: currentFile, tempFiles };
}

export function applySimpleMasteringBoostStage(
  input: StageContext & { inputFile: string }
): { outputFile: string; tempFile: string } {
  const { ffmpeg, fileId, jobId, sampleRate, inputFile, withProgressStage } = input;
  const boostedFile = `${fileId}-${jobId}-simple-boosted.f32`;
  const boostArgs = buildPcmFilterPlan(inputFile, boostedFile, "volume=12dB", sampleRate);
  withProgressStage("simple-mastering-boost", 0.9, 0.0, () => ffmpeg.exec(...boostArgs));
  return { outputFile: boostedFile, tempFile: boostedFile };
}
