import createFFmpegCore from "@ffmpeg/core";
import { log } from "@slowverb/shared";
import type {
  InitPayload,
  WorkerEvent,
  WorkerLogLevel,
  WorkerRequest,
  WorkerResultPayload,
} from "@slowverb/shared";
import { clampInt } from "./worker_utils.js";
import {
  buildRenderPlan,
  buildWaveform,
  decodePcm,
  encodePcm,
  ensureFileExists,
  probeWithFfmpeg,
  readOutput,
  renderWithPcmPipeline,
  renderWithPhaseLimiter,
} from "./ffmpeg_pipeline.js";
import type { WorkerFfmpegBridge } from "./worker_types.js";
import {
  isPhaseLimiterEnabled,
  isSimpleMasteringEnabled,
  isSoundTouchEnabled,
  isToneReverbEnabled,
  validateRenderPayload,
} from "./worker_render_rules.js";
import { withProgressStageState, type WorkerProgressState } from "./worker_progress_state.js";

const ctx = self as DedicatedWorkerGlobalScope;

ctx.addEventListener("error", (event) => {
  postEvent({ type: "LOG", level: "error", message: `worker:error ${event.message || event.type}` });
});

ctx.addEventListener("unhandledrejection", (event) => {
  postEvent({ type: "LOG", level: "error", message: `worker:unhandled ${String(event.reason)}` });
});

ctx.addEventListener("messageerror", (event) => {
  postEvent({ type: "LOG", level: "error", message: `worker:messageerror ${String(event.data)}` });
});

const DEFAULT_CORE_URL = "/js/ffmpeg-core.js";
const DEFAULT_WASM_URL = "/js/ffmpeg-core.wasm";
const DEFAULT_WORKER_URL: string | undefined = undefined;

let ffmpeg: WorkerFfmpegBridge | null = null;
let isReady = false;
let activeJobId: string | undefined;
const progressState: WorkerProgressState = { stage: undefined, offset: 0, scale: 1 };
const loadedFiles = new Set<string>();
let logCapture: { active: boolean; lines: string[]; limit: number } | null = null;

ctx.onmessage = (event: MessageEvent<WorkerRequest>) => {
  const request = event.data;
  log("debug", "request:received", { type: request.type, jobId: getJobId(request) });
  handleRequest(request).catch((error) => {
    log("error", "request:failed", { type: request.type, error: (error as Error)?.message });
    postError("Worker request failed", request.requestId, getJobId(request), error);
  });
};

async function handleRequest(request: WorkerRequest): Promise<void> {
  postEvent({ type: "LOG", level: "debug", message: `request:${request.type}` });
  switch (request.type) {
    case "INIT":
      return ensureFfmpeg(request.payload, request.requestId);
    case "LOAD_SOURCE":
      return runWithEngine(() => handleLoadSource(request), request.requestId);
    case "PROBE":
      return runWithEngine(() => handleProbe(request), request.requestId);
    case "RENDER_PREVIEW":
    case "RENDER_FULL":
      return runWithEngine(() => handleRender(request));
    case "WAVEFORM":
      return runWithEngine(() => handleWaveform(request));
    case "CANCEL":
      return handleCancel(request);
    case "PING":
      return handlePing(request);
    case "DECODE_PCM":
      return runWithEngine(() => handleDecodePCM(request), request.requestId);
    case "ENCODE_PCM":
      return runWithEngine(() => handleEncodePCM(request), request.requestId);
  }
}

async function handlePing(request: WorkerRequest & { type: "PING" }): Promise<void> {
  postEvent({ type: "LOG", level: "debug", message: `pong:${request.requestId}` }); postResult(request.requestId, { pong: true });
}

async function runWithEngine(task: () => Promise<void>, requestId?: string): Promise<void> { await ensureFfmpeg(undefined, requestId); await task(); }

async function handleCancel(request: Extract<WorkerRequest, { type: "CANCEL" }>): Promise<void> {
  postEvent({ type: "CANCELLED", requestId: request.requestId, jobId: request.jobId, reason: "Worker terminated" });
  log("warn", "cancel:terminate", { jobId: request.jobId });
  cleanupFiles(...loadedFiles);
  loadedFiles.clear();
  ctx.close();
}

async function ensureFfmpeg(payload?: InitPayload, requestId?: string): Promise<void> {
  if (isReady && ffmpeg) {
    if (requestId) postEvent({ type: "READY", requestId });
    return;
  }

  postEvent({ type: "LOG", level: "info", message: "FFmpeg init: start" });
  postEvent({ type: "LOG", level: "info", message: "FFmpeg init: loading core" });
  ffmpeg = await createCore(payload);
  isReady = true;
  postEvent({ type: "LOG", level: "info", message: "FFmpeg init: ready" });
  postEvent({ type: "READY", requestId });
}

async function createCore(payload?: InitPayload): Promise<WorkerFfmpegBridge> {
  const coreURL = payload?.coreURL ?? DEFAULT_CORE_URL;
  const wasmURL = payload?.wasmURL ?? DEFAULT_WASM_URL;
  const workerURL = payload?.workerURL ?? DEFAULT_WORKER_URL;

  await logAssetStatus("wasm", wasmURL);

  const mainScriptUrlOrBlob = `${coreURL}#${btoa(JSON.stringify({ wasmURL, workerURL }))}`;
  const core = await (createFFmpegCore as unknown as (options: Record<string, unknown>) => Promise<WorkerFfmpegBridge>)({
    mainScriptUrlOrBlob,
  });

  core.setLogger?.(({ type, message }: { type: string; message: string }) => {
    postEvent({ type: "LOG", level: mapLogLevel(type), message });
    recordLog(message);
  });

  core.setProgress?.(({ progress }: { progress: number }) => {
    if (!activeJobId) return;
    const value = typeof progress === "number" ? progress : 0;
    const scaled = progressState.offset + value * progressState.scale;
    postEvent({ type: "PROGRESS", jobId: activeJobId, value: scaled, stage: progressState.stage });
  });

  return core;
}

async function logAssetStatus(name: string, url: string): Promise<void> {
  try {
    const response = await fetch(url, {
      method: "GET",
      headers: { Range: "bytes=0-0" },
    });
    await response.body?.cancel();
    postEvent({ type: "LOG", level: "info", message: `FFmpeg init: ${name} ${response.status} (${url})` });
  } catch (error) {
    postEvent({
      type: "LOG",
      level: "warn",
      message: `FFmpeg init: ${name} check failed (${url}): ${String(error)}`,
    });
  }
}

async function handleLoadSource(request: Extract<WorkerRequest, { type: "LOAD_SOURCE" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const data = new Uint8Array(request.payload.data);
  ffmpeg.FS.writeFile(request.payload.fileId, data);
  loadedFiles.add(request.payload.fileId);

  postEvent({
    type: "LOG",
    level: "info",
    message: `load:ok (${request.payload.fileId}) size=${data.byteLength}`,
  });
  postResult(request.requestId, { fileId: request.payload.fileId });
}

async function handleProbe(request: Extract<WorkerRequest, { type: "PROBE" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");

  const fileId = request.payload.fileId;
  postEvent({ type: "LOG", level: "info", message: `probe:start (${fileId})` });
  ensureFileExists(ffmpeg, fileId);

  postEvent({ type: "LOG", level: "debug", message: `probe:exists (${fileId})` });

  const warnTimeout = setTimeout(() => {
    postEvent({ type: "LOG", level: "warn", message: `probe:still-running (${fileId})` });
  }, 10_000);

  try {
    const metadata = await probeWithFfmpeg(ffmpeg, fileId, {
      postEvent,
      startLogCapture,
      stopLogCapture,
    });
    postEvent({ type: "LOG", level: "info", message: `probe:ok (${fileId}) durationMs=${metadata.durationMs ?? "null"}` });
    postResult(request.requestId, metadata);
  } finally {
    clearTimeout(warnTimeout);
  }
}

async function handleRender(
  request: Extract<WorkerRequest, { type: "RENDER_PREVIEW" | "RENDER_FULL" }>
): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const engine = ffmpeg;

  const { payload, jobId, type } = request;
  validateRenderPayload(payload);
  const isPreview = type === "RENDER_PREVIEW";
  const shouldUsePhaseLimiter = isPhaseLimiterEnabled(payload);
  const shouldUseSoundTouch = isSoundTouchEnabled(payload);
  const shouldUseToneReverb = isToneReverbEnabled(payload);
  const shouldUsePcmPipeline = shouldUseSoundTouch || shouldUseToneReverb;
  const filesToCleanup = new Set<string>([payload.fileId]);

  activeJobId = jobId;
  try {
    if (!shouldUsePhaseLimiter && !shouldUsePcmPipeline) {
      const { args, outputFile } = buildRenderPlan(payload, jobId, isPreview);
      filesToCleanup.add(outputFile);
      log("info", "render:start", { jobId, fileId: payload.fileId, format: payload.format });
      try {
        withProgressStage("processing", 0, 1, () => engine.exec(...args));
      } catch (error) {
        if (isSimpleMasteringEnabled(payload)) {
          postMasteringWarning(
            jobId,
            payload.fileId,
            "Mastering failed. The render was stopped to preserve deterministic output.",
            error
          );
        }
        throw error;
      }
      const buffer = readOutput(engine, outputFile);
      log("info", "render:ok", { jobId, outputFile });
      postRenderResult(request, buffer);
      return;
    }

    if (shouldUsePhaseLimiter && !shouldUsePcmPipeline) {
      log("info", "render:start(phaselimiter)", { jobId, fileId: payload.fileId, format: payload.format });
      const result = await renderWithPhaseLimiter(engine, payload, jobId, isPreview, {
        postEvent,
        withProgressStage,
        postMasteringWarning,
      });
      filesToCleanup.add(result.outputFile);
      for (const temp of result.tempFiles) filesToCleanup.add(temp);
      log("info", "render:ok(phaselimiter)", { jobId, outputFile: result.outputFile });
      postRenderResult(request, result.buffer);
      return;
    }

    log("info", "render:start(pcm-pipeline)", {
      jobId,
      fileId: payload.fileId,
      format: payload.format,
      soundtouch: shouldUseSoundTouch,
      toneReverb: shouldUseToneReverb,
      phaselimiter: shouldUsePhaseLimiter,
    });

    const result = await renderWithPcmPipeline(
      engine,
      payload,
      jobId,
      isPreview,
      {
        applyPhaseLimiter: shouldUsePhaseLimiter,
        useSoundTouch: shouldUseSoundTouch,
        useToneReverb: shouldUseToneReverb,
      },
      { postEvent, withProgressStage, postMasteringWarning }
    );
    filesToCleanup.add(result.outputFile);
    for (const temp of result.tempFiles) filesToCleanup.add(temp);
    log("info", "render:ok(pcm-pipeline)", { jobId, outputFile: result.outputFile });
    postRenderResult(request, result.buffer);
    return;
  } finally {
    activeJobId = undefined;
    progressState.stage = undefined;
    progressState.offset = 0;
    progressState.scale = 1;
    log("debug", "render:cleanup", { jobId });
    cleanupFiles(...filesToCleanup);
  }
}

function withProgressStage(stage: string, offset: number, scale: number, run: () => void): void {
  withProgressStageState(progressState, stage, offset, scale, run);
}

async function handleWaveform(request: Extract<WorkerRequest, { type: "WAVEFORM" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const points = clampInt(request.payload.points ?? 256, 32, 8192);
  const fileId = request.payload.fileId;
  const jobId = request.jobId;

  activeJobId = jobId;
  try {
    const waveform = await buildWaveform(ffmpeg, fileId, points, jobId, {
      postEvent,
      startLogCapture,
      stopLogCapture,
    }, cleanupFiles);
    postResult(request.requestId, waveform, [waveform.samples.buffer]);
  } finally {
    activeJobId = undefined;
  }
}

async function handleDecodePCM(request: Extract<WorkerRequest, { type: "DECODE_PCM" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const { fileId } = request.payload;
  const { left, right, sampleRate } = await decodePcm(ffmpeg, fileId, cleanupFiles);
  postResult(request.requestId, { type: "DECODE_PCM_RESULT", left, right, sampleRate } as any, [
    left.buffer,
    right.buffer,
  ]);
}

async function handleEncodePCM(request: Extract<WorkerRequest, { type: "ENCODE_PCM" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const buffer = await encodePcm(ffmpeg, request.payload, cleanupFiles);
  postResult(request.requestId, { fileId: "encoded", format: request.payload.format, buffer }, [buffer]);
}

function cleanupFiles(...paths: string[]): void {
  if (!ffmpeg) return;
  for (const path of paths) {
    if (!path) continue;
    try {
      ffmpeg.FS.unlink(path);
      loadedFiles.delete(path);
    } catch {
      // Best-effort cleanup
    }
  }
}

function postResult(requestId: string, payload: WorkerResultPayload, transfer?: Transferable[]): void {
  postEvent({ type: "RESULT", requestId, payload }, transfer);
}

function postRenderResult(
  request: Extract<WorkerRequest, { type: "RENDER_PREVIEW" | "RENDER_FULL" }>,
  buffer: ArrayBuffer
): void {
  postResult(request.requestId, { fileId: request.payload.fileId, format: request.payload.format, buffer }, [buffer]);
}

function getJobId(request: WorkerRequest): string | undefined {
  return "jobId" in request ? request.jobId : undefined;
}

function postEvent(event: WorkerEvent, transfer?: Transferable[]): void {
  ctx.postMessage(event, transfer ?? []);
}

function postError(message: string, requestId?: string, jobId?: string, cause?: unknown): void {
  const causeMessage = cause instanceof Error ? cause.message : cause ? String(cause) : undefined;
  const detail = cause instanceof Error && cause.stack ? `${causeMessage}\n${cause.stack}` : causeMessage;
  log("error", "worker:error", { jobId, message, cause: detail });
  postEvent({ type: "ERROR", requestId, jobId, message, cause: detail });
}

function postMasteringWarning(jobId: string, fileId: string, message: string, cause?: unknown): void {
  const causeMessage = cause instanceof Error ? cause.message : cause ? String(cause) : undefined;
  const warningMessage = causeMessage ? `${message} Cause: ${causeMessage}` : message;
  postEvent({
    type: "LOG",
    level: "warn",
    message: `mastering-warning:${warningMessage} (job=${jobId}, file=${fileId})`,
  });
}

function mapLogLevel(level?: string): WorkerLogLevel {
  return level === "error" || level === "warn" || level === "debug" ? level : "info";
}

function recordLog(message: string): void {
  if (logCapture?.active && logCapture.lines.length < logCapture.limit) logCapture.lines.push(message);
}

function startLogCapture(limit: number): { active: boolean; lines: string[]; limit: number } {
  return (logCapture = { active: true, lines: [], limit });
}

function stopLogCapture(capture: { active: boolean }): void {
  if (logCapture === capture) { logCapture.active = false; logCapture = null; }
}

