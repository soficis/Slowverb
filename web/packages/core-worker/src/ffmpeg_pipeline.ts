import { compileFilterChainParts } from "@slowverb/shared";
import type {
  EncodePcmPayload,
  ProbeResultPayload,
  RenderPayload,
  WorkerEvent,
} from "@slowverb/shared";
import {
  addCodecArgs,
  addInputArgs,
  addTrimArgs,
  buildDecodePlan,
  buildEncodePlan,
  buildOutputName,
  buildPcmFilterPlan,
  buildRawDecodePlan,
  chooseWaveformSampleRate,
  clampNumber,
  computePeaks,
  normalizeInPlace,
  parseProbeLogs,
  readAndSplitF32Stereo,
  writeInterleavedF32Stereo,
} from "./worker_utils.js";
import type { WorkerFfmpegBridge } from "./worker_types.js";
import { runSoundTouchStage } from "./soundtouch_pipeline.js";
import {
  applyPhaseLimiterStage,
  applySimpleMasteringBoostStage,
  isSimpleMasteringWithToneReverb,
} from "./mastering_pipeline.js";

interface ProgressCallbacks {
  postEvent: (event: WorkerEvent) => void;
  withProgressStage: (stage: string, offset: number, scale: number, run: () => void) => void;
  postMasteringWarning: (jobId: string, fileId: string, message: string, cause?: unknown) => void;
}

interface ProbeCallbacks {
  postEvent: (event: WorkerEvent) => void;
  startLogCapture: (limit: number) => { active: boolean; lines: string[]; limit: number };
  stopLogCapture: (capture: { active: boolean }) => void;
}

export function buildRenderPlan(
  payload: RenderPayload,
  jobId: string,
  isPreview: boolean
): { args: string[]; outputFile: string } {
  const args: string[] = [];
  addTrimArgs(args, payload, isPreview);
  addInputArgs(args, payload);
  addCodecArgs(args, payload.format, payload.bitrateKbps);
  const outputFile = buildOutputName(payload.fileId, jobId, payload.format, isPreview);
  args.push("-y", outputFile);
  return { args, outputFile };
}

export function readOutput(ffmpeg: WorkerFfmpegBridge, path: string): ArrayBuffer {
  const bytes = ffmpeg.FS.readFile(path);
  if (!(bytes instanceof Uint8Array)) throw new Error("Expected binary output from FFmpeg");
  const copy = bytes.slice();
  return copy.buffer;
}

export async function renderWithPhaseLimiter(
  ffmpeg: WorkerFfmpegBridge,
  payload: RenderPayload,
  jobId: string,
  isPreview: boolean,
  callbacks: ProgressCallbacks
): Promise<{ buffer: ArrayBuffer; outputFile: string; tempFiles: string[] }> {
  const sampleRate = 44100;
  const decodeFile = `${payload.fileId}-${jobId}-decode.f32`;
  const outputFile = buildOutputName(payload.fileId, jobId, payload.format, isPreview);

  try {
    const decodeArgs = buildDecodePlan(payload, decodeFile, sampleRate, isPreview);
    callbacks.postEvent({ type: "PROGRESS", jobId, value: 0, stage: "decoding" });
    callbacks.withProgressStage("decoding", 0, 0.2, () => ffmpeg.exec(...decodeArgs));

    const mastering = payload.mastering;
    if (!mastering?.enabled) {
      throw new Error("PhaseLimiter pipeline requires mastering.enabled=true");
    }

    const algorithm = mastering.algorithm;
    if (algorithm !== "phaselimiter" && algorithm !== "phaselimiter_pro") {
      throw new Error(`Unsupported PhaseLimiter algorithm: ${String(algorithm)}`);
    }

    const mastered = await applyPhaseLimiterStage({
      ffmpeg,
      fileId: payload.fileId,
      jobId,
      sampleRate,
      inputFile: decodeFile,
      algorithm,
      mastering,
      progressRange: { offset: 0.2, scale: 0.6 },
      isToneReverbEnabled: false,
      withProgressStage: callbacks.withProgressStage,
      postProgress: (id, value, stage) =>
          callbacks.postEvent({ type: "PROGRESS", jobId: id, value, stage }),
    });

    const encodeArgs = buildEncodePlan(mastered.outputFile, outputFile, payload, sampleRate);
    callbacks.postEvent({ type: "PROGRESS", jobId, value: 0.8, stage: "encoding" });
    callbacks.withProgressStage("encoding", 0.8, 0.2, () => ffmpeg.exec(...encodeArgs));

    const buffer = readOutput(ffmpeg, outputFile);
    return { buffer, outputFile, tempFiles: [decodeFile, ...mastered.tempFiles] };
  } catch (error) {
    callbacks.postMasteringWarning(
      jobId,
      payload.fileId,
      "PhaseLimiter mastering failed. Render aborted to prevent silent degradation.",
      error
    );
    throw error;
  }
}

interface PcmPipelineOptions {
  applyPhaseLimiter: boolean;
  useSoundTouch: boolean;
  useToneReverb: boolean;
}

export async function renderWithPcmPipeline(
  ffmpeg: WorkerFfmpegBridge,
  payload: RenderPayload,
  jobId: string,
  isPreview: boolean,
  options: PcmPipelineOptions,
  callbacks: ProgressCallbacks
): Promise<{ buffer: ArrayBuffer; outputFile: string; tempFiles: string[] }> {
  const sampleRate = 44100;
  const rawFile = `${payload.fileId}-${jobId}-raw.f32`;
  const stretchedFile = `${payload.fileId}-${jobId}-stretched.f32`;
  const effectsFile = `${payload.fileId}-${jobId}-effects.f32`;
  const outputFile = buildOutputName(payload.fileId, jobId, payload.format, isPreview);

  const tempFiles: string[] = [rawFile];
  let currentPcmFile = rawFile;

  const decodeArgs = buildRawDecodePlan(payload, rawFile, sampleRate, isPreview);
  callbacks.postEvent({ type: "PROGRESS", jobId, value: 0, stage: "decoding" });
  callbacks.withProgressStage("decoding", 0, 0.15, () => ffmpeg.exec(...decodeArgs));

  if (options.useSoundTouch) {
    currentPcmFile = runSoundTouchStage(
      ffmpeg,
      payload,
      rawFile,
      stretchedFile,
      jobId,
      { offset: 0.15, scale: 0.2 },
      (id, value, stage) => callbacks.postEvent({ type: "PROGRESS", jobId: id, value, stage })
    );
    tempFiles.push(stretchedFile);
  }

  if (options.useToneReverb) {
    if (!payload.dspSpec?.reverb) {
      throw new Error("Tone reverb enabled but dspSpec.reverb missing");
    }
    if (!payload.reverbIR) {
      callbacks.postMasteringWarning(
        jobId,
        payload.fileId,
        "Tone reverb IR generation failed. Render aborted to avoid fallback audio."
      );
      throw new Error("Tone reverb enabled but reverbIR was not provided");
    }

    const irFile = `${payload.fileId}-${jobId}-ir.f32`;
    ffmpeg.FS.writeFile(irFile, new Uint8Array(payload.reverbIR));
    tempFiles.push(irFile);

    const { pre, post } = compileFilterChainParts(payload.dspSpec);
    const mix = clampNumber(payload.dspSpec.reverb.mix, 0.0, 1.0);
    const dry = (1 - mix).toFixed(4);
    const wet = mix.toFixed(4);
    const irSampleRate = typeof payload.reverbIRSampleRate === "number"
      ? payload.reverbIRSampleRate
      : sampleRate;

    const args: string[] = [];
    args.push("-f", "f32le", "-ac", "2", "-ar", `${sampleRate}`, "-i", currentPcmFile);
    args.push("-f", "f32le", "-ac", "2", "-ar", `${irSampleRate}`, "-i", irFile);

    const chains: string[] = [];
    chains.push(`[0:a]${pre === "anull" ? "anull" : pre}[pre]`);
    chains.push(`[1:a]${irSampleRate === sampleRate ? "anull" : `aresample=${sampleRate}`}[ir]`);
    chains.push(`[pre][ir]afir=dry=${dry}:wet=${wet},volume=42dB[wet]`);
    chains.push(`[wet]${post === "anull" ? "anull" : post}[out]`);

    args.push("-filter_complex", chains.join(";"));
    args.push("-map", "[out]");
    args.push("-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", effectsFile);

    callbacks.postEvent({ type: "PROGRESS", jobId, value: 0.35, stage: "effects" });
    callbacks.withProgressStage("effects", 0.35, 0.35, () => ffmpeg.exec(...args));
    tempFiles.push(effectsFile);
    currentPcmFile = effectsFile;
  } else if (payload.filterGraph && payload.filterGraph !== "anull") {
    const filterArgs = buildPcmFilterPlan(currentPcmFile, effectsFile, payload.filterGraph, sampleRate);
    callbacks.postEvent({ type: "PROGRESS", jobId, value: 0.35, stage: "effects" });
    callbacks.withProgressStage("effects", 0.35, 0.35, () => ffmpeg.exec(...filterArgs));
    tempFiles.push(effectsFile);
    currentPcmFile = effectsFile;
  }

  if (options.applyPhaseLimiter) {
    const mastering = payload.mastering;
    if (!mastering?.enabled) {
      throw new Error("PhaseLimiter pipeline requires mastering.enabled=true");
    }

    const algorithm = mastering.algorithm;
    if (algorithm !== "phaselimiter" && algorithm !== "phaselimiter_pro") {
      throw new Error(`Unsupported PhaseLimiter algorithm: ${String(algorithm)}`);
    }
    const mastered = await applyPhaseLimiterStage({
      ffmpeg,
      fileId: payload.fileId,
      jobId,
      sampleRate,
      inputFile: currentPcmFile,
      algorithm,
      mastering,
      progressRange: { offset: 0.7, scale: 0.2 },
      isToneReverbEnabled: options.useToneReverb,
      withProgressStage: callbacks.withProgressStage,
      postProgress: (id, value, stage) =>
          callbacks.postEvent({ type: "PROGRESS", jobId: id, value, stage }),
    });

    tempFiles.push(...mastered.tempFiles);
    currentPcmFile = mastered.outputFile;
  }

  if (isSimpleMasteringWithToneReverb(payload.mastering, options.useToneReverb)) {
    const boosted = applySimpleMasteringBoostStage({
      ffmpeg,
      fileId: payload.fileId,
      jobId,
      sampleRate,
      inputFile: currentPcmFile,
      withProgressStage: callbacks.withProgressStage,
      postProgress: () => {},
    });
    tempFiles.push(boosted.tempFile);
    currentPcmFile = boosted.outputFile;
  }

  const encodeArgs = buildEncodePlan(currentPcmFile, outputFile, payload, sampleRate);
  callbacks.postEvent({ type: "PROGRESS", jobId, value: 0.9, stage: "encoding" });
  callbacks.withProgressStage("encoding", 0.9, 0.1, () => ffmpeg.exec(...encodeArgs));

  const buffer = readOutput(ffmpeg, outputFile);
  return { buffer, outputFile, tempFiles };
}

export async function probeWithFfmpeg(
  ffmpeg: WorkerFfmpegBridge,
  fileId: string,
  callbacks: ProbeCallbacks
): Promise<ProbeResultPayload> {
  const capture = callbacks.startLogCapture(250);
  try {
    callbacks.postEvent({ type: "LOG", level: "debug", message: "probe:exec start" });
    const ret = ffmpeg.exec(
      "-hide_banner",
      "-t",
      "0.01",
      "-i",
      fileId,
      "-vn",
      "-sn",
      "-dn",
      "-f",
      "null",
      "-"
    );
    callbacks.postEvent({ type: "LOG", level: "debug", message: `probe:exec done ret=${ret}` });
  } catch (error) {
    callbacks.postEvent({
      type: "LOG",
      level: "debug",
      message: `probe:exec threw ${String((error as Error)?.message ?? error)}`,
    });
  } finally {
    callbacks.stopLogCapture(capture);
  }

  const parsed = parseProbeLogs(capture.lines);
  return {
    fileId,
    durationMs: parsed.durationMs,
    sampleRate: parsed.sampleRate ?? 44100,
    channels: parsed.channels ?? 2,
    format: parsed.format ?? "unknown",
  };
}

export function ensureFileExists(ffmpeg: WorkerFfmpegBridge, path: string): void {
  const analyzed = ffmpeg.FS.analyzePath(path);
  if (!analyzed?.exists) {
    throw new Error(`FFmpeg FS missing input: ${path}`);
  }
}

export async function buildWaveform(
  ffmpeg: WorkerFfmpegBridge,
  fileId: string,
  points: number,
  jobId: string,
  callbacks: ProbeCallbacks,
  cleanupFiles: (...paths: string[]) => void
): Promise<{ fileId: string; samples: Float32Array }> {
  ensureFileExists(ffmpeg, fileId);
  const probe = await probeWithFfmpeg(ffmpeg, fileId, callbacks);
  const durationSec = probe.durationMs != null ? probe.durationMs / 1000 : undefined;
  const sampleRate = chooseWaveformSampleRate(points, durationSec);
  const outputFile = `waveform_${jobId}.f32`;

  try {
    ffmpeg.exec(
      "-hide_banner",
      "-i",
      fileId,
      "-vn",
      "-ac",
      "1",
      "-ar",
      `${sampleRate}`,
      "-f",
      "f32le",
      outputFile
    );

    const bytes = ffmpeg.FS.readFile(outputFile);
    if (!(bytes instanceof Uint8Array)) throw new Error("Waveform output is not binary");
    const sampleCount = Math.floor(bytes.byteLength / 4);
    const floatSamples = new Float32Array(bytes.buffer, bytes.byteOffset, sampleCount);
    const peaks = computePeaks(floatSamples, points);
    normalizeInPlace(peaks);
    return { fileId, samples: peaks };
  } finally {
    cleanupFiles(fileId, outputFile);
  }
}

export async function decodePcm(
  ffmpeg: WorkerFfmpegBridge,
  fileId: string,
  cleanupFiles: (...paths: string[]) => void
): Promise<{ left: Float32Array; right: Float32Array; sampleRate: number }> {
  const sampleRate = 44100;
  const tempFile = `${fileId}-decode.f32`;
  try {
    ffmpeg.exec("-i", fileId, "-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", tempFile);
    const { left, right } = readAndSplitF32Stereo(ffmpeg.FS, tempFile);
    return { left, right, sampleRate };
  } finally {
    cleanupFiles(tempFile);
  }
}

export async function encodePcm(
  ffmpeg: WorkerFfmpegBridge,
  payload: EncodePcmPayload,
  cleanupFiles: (...paths: string[]) => void
): Promise<ArrayBuffer> {
  const inputFile = "raw-input.f32";
  const outputFile = `output.${payload.format}`;
  try {
    writeInterleavedF32Stereo(ffmpeg.FS, inputFile, payload.left, payload.right);
    const args = ["-f", "f32le", "-ac", "2", "-ar", `${payload.sampleRate}`, "-i", inputFile];
    addCodecArgs(args, payload.format, payload.bitrateKbps);
    args.push("-y", outputFile);
    ffmpeg.exec(...args);
    return readOutput(ffmpeg, outputFile);
  } finally {
    cleanupFiles(inputFile, outputFile);
  }
}
