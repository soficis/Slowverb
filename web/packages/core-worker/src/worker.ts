import { FFmpeg } from "@ffmpeg/ffmpeg";
import type {
  InitPayload,
  RenderPayload,
  WorkerEvent,
  WorkerLogLevel,
  WorkerRequest,
  WorkerResultPayload,
} from "@slowverb/shared";

const ctx = self as DedicatedWorkerGlobalScope;

const DEFAULT_CORE_URL = "/js/ffmpeg-core.js";
const DEFAULT_WASM_URL = "/js/ffmpeg-core.wasm";
const DEFAULT_WORKER_URL: string | undefined = undefined;

let ffmpeg: FFmpeg | null = null;
let isReady = false;
let activeJobId: string | undefined;
const loadedFiles = new Set<string>();
let logCapture: { active: boolean; lines: string[]; limit: number } | null = null;

ctx.onmessage = (event: MessageEvent<WorkerRequest>) => {
  const request = event.data;
  handleRequest(request).catch((error) => {
    postError("Worker request failed", request.requestId, getJobId(request), error);
  });
};

async function handleRequest(request: WorkerRequest): Promise<void> {
  switch (request.type) {
    case "INIT":
      return ensureFfmpeg(request.payload, request.requestId);
    case "LOAD_SOURCE":
      return runWithEngine(() => handleLoadSource(request), request.requestId);
    case "PROBE":
      return runWithEngine(() => handleProbe(request));
    case "RENDER_PREVIEW":
    case "RENDER_FULL":
      return runWithEngine(() => handleRender(request));
    case "WAVEFORM":
      return runWithEngine(() => handleWaveform(request));
    case "CANCEL":
      return handleCancel(request);
  }
}

async function runWithEngine(task: () => Promise<void>, requestId?: string): Promise<void> {
  await ensureFfmpeg(undefined, requestId);
  await task();
}

async function handleCancel(request: Extract<WorkerRequest, { type: "CANCEL" }>): Promise<void> {
  postEvent({
    type: "CANCELLED",
    requestId: request.requestId,
    jobId: request.jobId,
    reason: "Worker terminated",
  });
  ctx.close();
}

async function ensureFfmpeg(payload?: InitPayload, requestId?: string): Promise<void> {
  if (isReady && ffmpeg) {
    if (requestId) postEvent({ type: "READY", requestId });
    return;
  }

  ffmpeg = new FFmpeg();
  attachFfmpegHooks(ffmpeg);
  await loadFfmpegCore(payload);
  isReady = true;
  postEvent({ type: "READY", requestId });
}

function attachFfmpegHooks(instance: FFmpeg): void {
  instance.on("log", ({ type, message }) => {
    postEvent({ type: "LOG", level: mapLogLevel(type), message });
    recordLog(message);
  });

  instance.on("progress", ({ progress }) => {
    if (!activeJobId) return;
    const value = typeof progress === "number" ? progress : 0;
    postEvent({ type: "PROGRESS", jobId: activeJobId, value });
  });
}

async function loadFfmpegCore(payload?: InitPayload): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not created");
  const coreURL = payload?.coreURL ?? DEFAULT_CORE_URL;
  const wasmURL = payload?.wasmURL ?? DEFAULT_WASM_URL;
  const workerURL = payload?.workerURL ?? DEFAULT_WORKER_URL;
  const loadOptions: Parameters<FFmpeg["load"]>[0] = { coreURL, wasmURL };
  if (workerURL) loadOptions.workerURL = workerURL;
  await ffmpeg.load(loadOptions);
}

async function handleLoadSource(request: Extract<WorkerRequest, { type: "LOAD_SOURCE" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const data = new Uint8Array(request.payload.data);
  await ffmpeg.writeFile(request.payload.fileId, data);
  loadedFiles.add(request.payload.fileId);

  postResult(request.requestId, { fileId: request.payload.fileId });
}

async function handleProbe(request: Extract<WorkerRequest, { type: "PROBE" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");

  const fileId = request.payload.fileId;
  await ffmpeg.readFile(fileId);
  const metadata = await probeWithFfmpeg(fileId);
  postResult(request.requestId, metadata);
}

async function handleRender(
  request: Extract<WorkerRequest, { type: "RENDER_PREVIEW" | "RENDER_FULL" }>
): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");

  const { payload, jobId, type } = request;
  const isPreview = type === "RENDER_PREVIEW";
  const { args, outputFile } = buildRenderPlan(payload, jobId, isPreview);

  activeJobId = jobId;
  try {
    await ffmpeg.exec(args);
    const buffer = await readOutput(outputFile);
    postRenderResult(request, buffer);
  } finally {
    activeJobId = undefined;
    await cleanupOutput(outputFile);
  }
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
  const data = await ffmpeg.readFile(path);
  if (typeof data === "string") {
    throw new Error("Expected binary output from FFmpeg");
  }
  const buffer = data.buffer;
  if (buffer instanceof ArrayBuffer) {
    return buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
  }
  const copy = data.slice();
  return copy.buffer;
}

async function cleanupOutput(path: string): Promise<void> {
  if (!ffmpeg) return;
  try {
    await ffmpeg.deleteFile(path);
  } catch {
    // cleanup best effort
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
    await ffmpeg.exec(["-hide_banner", "-i", fileId]);
  } catch {
    // Expected: "At least one output file must be specified" after printing metadata.
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
  await ffmpeg.readFile(fileId);
  const probe = await probeWithFfmpeg(fileId);
  const durationSec = probe.durationMs != null ? probe.durationMs / 1000 : undefined;
  const sampleRate = chooseWaveformSampleRate(points, durationSec);
  const outputFile = `waveform_${jobId}.f32`;

  try {
    await ffmpeg.exec([
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
      "-y",
      outputFile,
    ]);

    const bytes = await ffmpeg.readFile(outputFile);
    if (typeof bytes === "string") throw new Error("Waveform output is not binary");
    const sampleCount = Math.floor(bytes.byteLength / 4);
    const floatSamples = new Float32Array(bytes.buffer, bytes.byteOffset, sampleCount);
    const peaks = computePeaks(floatSamples, points);
    normalizeInPlace(peaks);
    return { fileId, samples: peaks };
  } finally {
    await cleanupOutput(outputFile);
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
