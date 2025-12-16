import createFFmpegCore from "@ffmpeg/core";
import { log } from "@slowverb/shared";
import type {
  InitPayload,
  RenderPayload,
  WorkerEvent,
  WorkerLogLevel,
  WorkerRequest,
  WorkerResultPayload,
} from "@slowverb/shared";

const ctx = self as DedicatedWorkerGlobalScope;

console.info("[slowverb-worker] started", {
  hasProcess: typeof (globalThis as unknown as { process?: unknown }).process !== "undefined",
});

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

let ffmpeg: any | null = null;
let isReady = false;
let activeJobId: string | undefined;
let activeStage: string | undefined;
let activeProgressOffset = 0;
let activeProgressScale = 1;
const loadedFiles = new Set<string>();
let logCapture: { active: boolean; lines: string[]; limit: number } | null = null;

const SIMPLE_MASTERING_FILTER_CHAIN =
  "highpass=f=20,acompressor=threshold=-18dB:ratio=2:attack=10:release=200:makeup=3,alimiter=limit=0.95";

ctx.onmessage = (event: MessageEvent<WorkerRequest>) => {
  const request = event.data;
  log("debug", "request:received", { type: request.type, jobId: getJobId(request) });
  handleRequest(request).catch((error) => {
    log("error", "request:failed", { type: request.type, error: (error as Error)?.message });
    postError("Worker request failed", request.requestId, getJobId(request), error);
  });
};

async function handleRequest(request: WorkerRequest): Promise<void> {
  // Direct console.log to bypass potential log forwarding issues
  console.log(`[slowverb-worker] request:${request.type} (${request.requestId})`);
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
  }
}

async function handlePing(request: WorkerRequest & { type: "PING" }): Promise<void> {
  postEvent({ type: "LOG", level: "debug", message: `pong:${request.requestId}` });
  postResult(request.requestId, { pong: true });
}

async function runWithEngine(task: () => Promise<void>, requestId?: string): Promise<void> {
  console.log(`[slowverb-worker] runWithEngine:start (${requestId})`);
  await ensureFfmpeg(undefined, requestId);
  console.log(`[slowverb-worker] runWithEngine:ffmpeg-ready (${requestId})`);
  await task();
  console.log(`[slowverb-worker] runWithEngine:task-done (${requestId})`);
}

async function handleCancel(request: Extract<WorkerRequest, { type: "CANCEL" }>): Promise<void> {
  postEvent({
    type: "CANCELLED",
    requestId: request.requestId,
    jobId: request.jobId,
    reason: "Worker terminated",
  });
  log("warn", "cancel:terminate", { jobId: request.jobId });
  cleanupFiles(...loadedFiles);
  loadedFiles.clear();
  ctx.close();
}

async function ensureFfmpeg(payload?: InitPayload, requestId?: string): Promise<void> {
  console.log(`[slowverb-worker] ensureFfmpeg:check isReady=${isReady} ffmpeg=${!!ffmpeg} (${requestId})`);
  if (isReady && ffmpeg) {
    if (requestId) postEvent({ type: "READY", requestId });
    console.log(`[slowverb-worker] ensureFfmpeg:already-ready (${requestId})`);
    return;
  }

  postEvent({ type: "LOG", level: "info", message: "FFmpeg init: start" });
  postEvent({ type: "LOG", level: "info", message: "FFmpeg init: loading core" });
  ffmpeg = await createCore(payload);
  isReady = true;
  postEvent({ type: "LOG", level: "info", message: "FFmpeg init: ready" });
  postEvent({ type: "READY", requestId });
}

async function createCore(payload?: InitPayload): Promise<any> {
  const coreURL = payload?.coreURL ?? DEFAULT_CORE_URL;
  const wasmURL = payload?.wasmURL ?? DEFAULT_WASM_URL;
  const workerURL = payload?.workerURL ?? DEFAULT_WORKER_URL;

  await logAssetStatus("wasm", wasmURL);

  const mainScriptUrlOrBlob = `${coreURL}#${btoa(JSON.stringify({ wasmURL, workerURL }))}`;
  const core = await (createFFmpegCore as unknown as (options: Record<string, unknown>) => Promise<any>)({
    mainScriptUrlOrBlob,
  });

  core.setLogger(({ type, message }: { type: string; message: string }) => {
    postEvent({ type: "LOG", level: mapLogLevel(type), message });
    recordLog(message);
  });

  core.setProgress(({ progress }: { progress: number }) => {
    if (!activeJobId) return;
    const value = typeof progress === "number" ? progress : 0;
    const scaled = activeProgressOffset + value * activeProgressScale;
    postEvent({ type: "PROGRESS", jobId: activeJobId, value: scaled, stage: activeStage });
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

  // Diagnostic: schedule heartbeat to confirm event loop is still alive after LOAD_SOURCE
  setTimeout(() => {
    postEvent({ type: "LOG", level: "debug", message: `load:heartbeat (${request.payload.fileId}) event-loop-alive` });
  }, 100);
}

async function handleProbe(request: Extract<WorkerRequest, { type: "PROBE" }>): Promise<void> {
  console.log(`[slowverb-worker] handleProbe:start`, request);
  if (!ffmpeg) throw new Error("FFmpeg not initialized");

  const fileId = request.payload.fileId;
  console.log(`[slowverb-worker] handleProbe:fileId=${fileId}`);

  console.log(`[slowverb-worker] handleProbe:about-to-postEvent-probe-start`);
  postEvent({ type: "LOG", level: "info", message: `probe:start (${fileId})` });
  console.log(`[slowverb-worker] handleProbe:postEvent-done`);

  console.log(`[slowverb-worker] handleProbe:about-to-ensureFileExists`);
  ensureFileExists(fileId);
  console.log(`[slowverb-worker] handleProbe:ensureFileExists-done`);

  postEvent({ type: "LOG", level: "debug", message: `probe:exists (${fileId})` });

  const warnTimeout = setTimeout(() => {
    postEvent({ type: "LOG", level: "warn", message: `probe:still-running (${fileId})` });
  }, 10_000);

  try {
    console.log(`[slowverb-worker] handleProbe:about-to-probeWithFfmpeg`);
    const metadata = await probeWithFfmpeg(fileId);
    console.log(`[slowverb-worker] handleProbe:probeWithFfmpeg-done`, metadata);
    postEvent({ type: "LOG", level: "info", message: `probe:ok (${fileId}) durationMs=${metadata.durationMs ?? "null"}` });
    postResult(request.requestId, metadata);
    console.log(`[slowverb-worker] handleProbe:result-posted`);
  } finally {
    clearTimeout(warnTimeout);
  }
}

async function handleRender(
  request: Extract<WorkerRequest, { type: "RENDER_PREVIEW" | "RENDER_FULL" }>
): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");

  const { payload, jobId, type } = request;
  const isPreview = type === "RENDER_PREVIEW";
  const shouldUsePhaseLimiter = isPhaseLimiterEnabled(payload);
  const filesToCleanup = new Set<string>([payload.fileId]);

  activeJobId = jobId;
  try {
    if (!shouldUsePhaseLimiter) {
      const { args, outputFile } = buildRenderPlan(payload, jobId, isPreview);
      filesToCleanup.add(outputFile);
      log("info", "render:start", { jobId, fileId: payload.fileId, format: payload.format });
      try {
        withProgressStage("processing", 0, 1, () => ffmpeg.exec(...args));
      } catch (error) {
        const fallbackGraph = stripSimpleMasteringFromFilterGraph(payload.filterGraph);
        if (!fallbackGraph) throw error;

        log("warn", "render:retry-without-mastering", { jobId, fileId: payload.fileId });
        const fallbackPlan = buildRenderPlan({ ...payload, filterGraph: fallbackGraph }, jobId, isPreview);
        filesToCleanup.add(fallbackPlan.outputFile);
        withProgressStage("processing", 0, 1, () => ffmpeg.exec(...fallbackPlan.args));
      }
      const buffer = await readOutput(outputFile);
      log("info", "render:ok", { jobId, outputFile });
      postRenderResult(request, buffer);
      return;
    }

    log("info", "render:start(phaselimiter)", { jobId, fileId: payload.fileId, format: payload.format });
    const result = await renderWithPhaseLimiter(payload, jobId, isPreview);
    filesToCleanup.add(result.outputFile);
    for (const temp of result.tempFiles) filesToCleanup.add(temp);
    log("info", "render:ok(phaselimiter)", { jobId, outputFile: result.outputFile });
    postRenderResult(request, result.buffer);
  } finally {
    activeJobId = undefined;
    activeStage = undefined;
    activeProgressOffset = 0;
    activeProgressScale = 1;
    log("debug", "render:cleanup", { jobId });
    cleanupFiles(...filesToCleanup);
  }
}

function isPhaseLimiterEnabled(payload: RenderPayload): boolean {
  const mastering = payload.mastering;
  if (!mastering) return false;
  return mastering.enabled === true && mastering.algorithm === "phaselimiter";
}

function withProgressStage(stage: string, offset: number, scale: number, run: () => void): void {
  const prevStage = activeStage;
  const prevOffset = activeProgressOffset;
  const prevScale = activeProgressScale;

  activeStage = stage;
  activeProgressOffset = offset;
  activeProgressScale = scale;
  try {
    run();
  } finally {
    activeStage = prevStage;
    activeProgressOffset = prevOffset;
    activeProgressScale = prevScale;
  }
}

async function renderWithPhaseLimiter(
  payload: RenderPayload,
  jobId: string,
  isPreview: boolean
): Promise<{ buffer: ArrayBuffer; outputFile: string; tempFiles: string[] }> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");

  const sampleRate = 44100;
  const decodeFile = `${payload.fileId}-${jobId}-decode.f32`;
  const masteredFile = `${payload.fileId}-${jobId}-mastered.f32`;
  const outputFile = buildOutputName(payload.fileId, jobId, payload.format, isPreview);

  try {
    const decodeArgs = buildDecodePlan(payload, decodeFile, sampleRate, isPreview);
    postEvent({ type: "PROGRESS", jobId, value: 0, stage: "decoding" });
    withProgressStage("decoding", 0, 0.2, () => ffmpeg.exec(...decodeArgs));

    const { left, right } = readAndSplitF32Stereo(decodeFile);

    postEvent({ type: "PROGRESS", jobId, value: 0.2, stage: "mastering" });
    const processed = await processWithPhaseLimiter(left, right, sampleRate, jobId);

    writeInterleavedF32Stereo(masteredFile, processed.left, processed.right);

    const encodeArgs = buildEncodePlan(masteredFile, outputFile, payload, sampleRate);
    postEvent({ type: "PROGRESS", jobId, value: 0.8, stage: "encoding" });
    withProgressStage("encoding", 0.8, 0.2, () => ffmpeg.exec(...encodeArgs));

    const buffer = await readOutput(outputFile);
    return { buffer, outputFile, tempFiles: [decodeFile, masteredFile] };
  } catch (error) {
    log("warn", "render:phaselimiter-failed", {
      jobId,
      fileId: payload.fileId,
      error: (error as Error)?.message ?? String(error),
    });

    // Fallback: render with simple mastering via FFmpeg filter chain.
    const filterGraph = appendSimpleMasteringToFilterGraph(payload.filterGraph);
    const fallbackPayload: RenderPayload = {
      ...payload,
      filterGraph,
      mastering: { enabled: true, algorithm: "simple" },
    };
    const plan = buildRenderPlan(fallbackPayload, jobId, isPreview);
    withProgressStage("processing", 0, 1, () => ffmpeg.exec(...plan.args));
    const buffer = await readOutput(plan.outputFile);
    return { buffer, outputFile: plan.outputFile, tempFiles: [decodeFile, masteredFile] };
  }
}

function buildDecodePlan(payload: RenderPayload, outputFile: string, sampleRate: number, isPreview: boolean): string[] {
  const args: string[] = [];
  addTrimArgs(args, payload, isPreview);
  args.push("-i", payload.fileId);
  if (payload.filterGraph && payload.filterGraph !== "anull") {
    args.push("-af", payload.filterGraph);
  }
  args.push("-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", outputFile);
  return args;
}

function buildEncodePlan(inputFile: string, outputFile: string, payload: RenderPayload, sampleRate: number): string[] {
  const args: string[] = [];
  args.push("-f", "f32le", "-ac", "2", "-ar", `${sampleRate}`, "-i", inputFile);
  addCodecArgs(args, payload);
  args.push("-y", outputFile);
  return args;
}

function readAndSplitF32Stereo(path: string): { left: Float32Array; right: Float32Array } {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const bytes = ffmpeg.FS.readFile(path);
  if (!(bytes instanceof Uint8Array)) throw new Error("Expected binary PCM output from FFmpeg");

  const pcm = bytes.slice().buffer;
  const interleaved = new Float32Array(pcm);
  if (interleaved.length % 2 !== 0) throw new Error("Invalid stereo PCM length");

  const frames = interleaved.length / 2;
  const left = new Float32Array(frames);
  const right = new Float32Array(frames);
  for (let i = 0; i < frames; i++) {
    left[i] = interleaved[i * 2];
    right[i] = interleaved[i * 2 + 1];
  }

  return { left, right };
}

function writeInterleavedF32Stereo(path: string, left: Float32Array, right: Float32Array): void {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  if (left.length !== right.length) throw new Error("Channel length mismatch");

  const frames = left.length;
  const interleaved = new Float32Array(frames * 2);
  for (let i = 0; i < frames; i++) {
    interleaved[i * 2] = left[i];
    interleaved[i * 2 + 1] = right[i];
  }
  ffmpeg.FS.writeFile(path, new Uint8Array(interleaved.buffer));
}

function appendSimpleMasteringToFilterGraph(filterGraph?: string): string {
  if (!filterGraph || filterGraph === "anull") return SIMPLE_MASTERING_FILTER_CHAIN;
  if (filterGraph.endsWith(SIMPLE_MASTERING_FILTER_CHAIN)) return filterGraph;
  return `${filterGraph},${SIMPLE_MASTERING_FILTER_CHAIN}`;
}

async function processWithPhaseLimiter(
  leftChannel: Float32Array,
  rightChannel: Float32Array,
  sampleRate: number,
  jobId: string
): Promise<{ left: Float32Array; right: Float32Array }> {
  return new Promise((resolve, reject) => {
    const worker = new Worker("/js/phase_limiter_worker.js");

    const onMessage = (event: MessageEvent) => {
      const data = event.data ?? {};
      const type = data.type;
      if (type === "progress") {
        const percent = typeof data.percent === "number" ? data.percent : 0;
        const scaled = 0.2 + clamp01(percent) * 0.6;
        postEvent({ type: "PROGRESS", jobId, value: scaled, stage: "mastering" });
        return;
      }
      if (type === "complete") {
        worker.removeEventListener("message", onMessage);
        worker.removeEventListener("error", onError);
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
        worker.terminate();
        reject(new Error(data.error ?? "PhaseLimiter worker error"));
      }
    };

    const onError = (event: ErrorEvent) => {
      worker.removeEventListener("message", onMessage);
      worker.removeEventListener("error", onError);
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
          config: { targetLufs: -14.0, bassPreservation: 0.5 },
        },
        [leftChannel.buffer, rightChannel.buffer]
      );
    } catch (error) {
      worker.removeEventListener("message", onMessage);
      worker.removeEventListener("error", onError);
      worker.terminate();
      reject(error);
    }
  });
}

function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

async function handleWaveform(request: Extract<WorkerRequest, { type: "WAVEFORM" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const points = clampInt(request.payload.points ?? 256, 32, 8192);
  const fileId = request.payload.fileId;
  const jobId = request.jobId;

  activeJobId = jobId;
  try {
    const waveform = await buildWaveform(fileId, points, jobId);
    postResult(request.requestId, waveform, [waveform.samples.buffer]);
  } finally {
    activeJobId = undefined;
  }
}

function buildRenderPlan(payload: RenderPayload, jobId: string, isPreview: boolean): { args: string[]; outputFile: string } {
  const args: string[] = [];
  addTrimArgs(args, payload, isPreview);
  addInputArgs(args, payload);
  addCodecArgs(args, payload);
  const outputFile = buildOutputName(payload.fileId, jobId, payload.format, isPreview);
  args.push("-y", outputFile);
  return { args, outputFile };
}

function addTrimArgs(args: string[], payload: RenderPayload, isPreview: boolean): void {
  if (!isPreview) return;
  const start = payload.startSec ?? 0;
  args.push("-ss", `${start}`);
  if (payload.durationSec != null) {
    args.push("-t", `${payload.durationSec}`);
  }
}

function addInputArgs(args: string[], payload: RenderPayload): void {
  args.push("-i", payload.fileId);
  if (payload.filterGraph && payload.filterGraph !== "anull") {
    args.push("-af", payload.filterGraph);
  }
}

function stripSimpleMasteringFromFilterGraph(filterGraph?: string): string | null {
  if (!filterGraph || filterGraph === "anull") return null;
  if (!filterGraph.endsWith(SIMPLE_MASTERING_FILTER_CHAIN)) return null;

  const withoutSuffix = filterGraph.slice(0, -SIMPLE_MASTERING_FILTER_CHAIN.length);
  const withoutTrailingComma = withoutSuffix.endsWith(",")
    ? withoutSuffix.slice(0, -1)
    : withoutSuffix;

  return withoutTrailingComma.length > 0 ? withoutTrailingComma : "anull";
}

function addCodecArgs(args: string[], payload: RenderPayload): void {
  switch (payload.format) {
    case "mp3":
      args.push("-c:a", "libmp3lame");
      if (payload.bitrateKbps) args.push("-b:a", `${payload.bitrateKbps}k`);
      return;
    case "wav":
      args.push("-c:a", "pcm_s16le");
      return;
    case "flac":
      args.push("-c:a", "flac");
      return;
    case "aac":
      args.push("-c:a", "aac");
      if (payload.bitrateKbps) args.push("-b:a", `${payload.bitrateKbps}k`);
      return;
  }
}

function buildOutputName(fileId: string, jobId: string, format: string, isPreview: boolean): string {
  const suffix = isPreview ? "preview" : "full";
  return `${fileId}-${jobId || "job"}-${suffix}.${format}`;
}

async function readOutput(path: string): Promise<ArrayBuffer> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const bytes = ffmpeg.FS.readFile(path);
  if (!(bytes instanceof Uint8Array)) throw new Error("Expected binary output from FFmpeg");
  const copy = bytes.slice();
  return copy.buffer;
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

function mapLogLevel(level?: string): WorkerLogLevel {
  if (level === "error" || level === "warn" || level === "debug") return level;
  return "info";
}

function recordLog(message: string): void {
  if (!logCapture?.active) return;
  if (logCapture.lines.length >= logCapture.limit) return;
  logCapture.lines.push(message);
}

async function probeWithFfmpeg(fileId: string): Promise<{
  fileId: string;
  durationMs: number | null;
  sampleRate: number;
  channels: number;
  format: string;
}> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const capture = startLogCapture(250);
  try {
    postEvent({ type: "LOG", level: "debug", message: "probe:exec start" });
    // Use a tiny decode window to force ffmpeg to exit quickly while still printing stream metadata.
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
    postEvent({ type: "LOG", level: "debug", message: `probe:exec done ret=${ret}` });
  } catch (error) {
    postEvent({
      type: "LOG",
      level: "debug",
      message: `probe:exec threw ${String((error as Error)?.message ?? error)}`,
    });
  } finally {
    stopLogCapture(capture);
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

function startLogCapture(limit: number): { active: boolean; lines: string[]; limit: number } {
  logCapture = { active: true, lines: [], limit };
  return logCapture;
}

function stopLogCapture(capture: { active: boolean }): void {
  if (logCapture === capture) {
    logCapture.active = false;
    logCapture = null;
  }
}

function parseProbeLogs(lines: readonly string[]): {
  durationMs: number | null;
  sampleRate?: number;
  channels?: number;
  format?: string;
} {
  const duration = findDurationMs(lines);
  const format = findInputFormat(lines);
  const audio = findAudioStream(lines);
  return {
    durationMs: duration,
    format,
    sampleRate: audio?.sampleRate,
    channels: audio?.channels,
  };
}

function findDurationMs(lines: readonly string[]): number | null {
  for (const line of lines) {
    const match = /Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/.exec(line);
    if (!match) continue;
    const hours = Number(match[1]);
    const minutes = Number(match[2]);
    const seconds = Number(match[3]);
    if (!Number.isFinite(hours) || !Number.isFinite(minutes) || !Number.isFinite(seconds)) continue;
    return Math.round((hours * 3600 + minutes * 60 + seconds) * 1000);
  }
  return null;
}

function findInputFormat(lines: readonly string[]): string | undefined {
  for (const line of lines) {
    const match = /Input\s+#\d+,\s*([^,]+),\s*from\s*/.exec(line);
    if (match) return match[1].trim();
  }
  return undefined;
}

function findAudioStream(lines: readonly string[]): { sampleRate?: number; channels?: number } | undefined {
  for (const line of lines) {
    if (!line.includes("Audio:")) continue;
    const sampleRate = parseSampleRate(line);
    const channels = parseChannels(line);
    if (sampleRate || channels) return { sampleRate, channels };
  }
  return undefined;
}

function parseSampleRate(line: string): number | undefined {
  const match = /(\d{4,6})\s*Hz/.exec(line);
  if (!match) return undefined;
  const value = Number(match[1]);
  return Number.isFinite(value) ? value : undefined;
}

function parseChannels(line: string): number | undefined {
  if (line.includes(" mono")) return 1;
  if (line.includes(" stereo")) return 2;
  const surround = /\b([57])\.(1)\b/.exec(line);
  if (surround) {
    const base = Number(surround[1]);
    return base + 1;
  }
  return undefined;
}

async function buildWaveform(fileId: string, points: number, jobId: string): Promise<{ fileId: string; samples: Float32Array }> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  ensureFileExists(fileId);
  const probe = await probeWithFfmpeg(fileId);
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

function ensureFileExists(path: string): void {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const analyzed = ffmpeg.FS.analyzePath(path);
  if (!analyzed?.exists) {
    throw new Error(`FFmpeg FS missing input: ${path}`);
  }
}

function chooseWaveformSampleRate(points: number, durationSec?: number): number {
  const samplesPerPoint = 64;
  if (!durationSec || durationSec <= 0) return 2000;
  const desired = Math.ceil((points * samplesPerPoint) / durationSec);
  return clampInt(desired, 500, 8000);
}

function computePeaks(samples: Float32Array, points: number): Float32Array {
  const peaks = new Float32Array(points);
  if (samples.length === 0) return peaks;
  const window = Math.max(1, Math.floor(samples.length / points));

  for (let i = 0; i < points; i += 1) {
    const start = i * window;
    const end = i === points - 1 ? samples.length : Math.min(samples.length, start + window);
    let max = 0;
    for (let j = start; j < end; j += 1) {
      const value = Math.abs(samples[j]);
      if (value > max) max = value;
    }
    peaks[i] = max;
  }
  return peaks;
}

function normalizeInPlace(values: Float32Array): void {
  let max = 0;
  for (let i = 0; i < values.length; i += 1) {
    if (values[i] > max) max = values[i];
  }
  if (max <= 0) return;
  for (let i = 0; i < values.length; i += 1) {
    values[i] = values[i] / max;
  }
}

function clampInt(value: number, min: number, max: number): number {
  const rounded = Math.round(value);
  if (rounded < min) return min;
  if (rounded > max) return max;
  return rounded;
}
