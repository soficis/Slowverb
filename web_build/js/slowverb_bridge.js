import { SlowverbEngine } from "./ts/core.js";

console.info("[SlowverbBridge] loaded");

const CORE_URL = "/js/ffmpeg-core.js";
const WASM_URL = "/js/ffmpeg-core.wasm";
const WORKER_URL = undefined;
const WORKER_ENTRY = "/js/ts/worker.js";

const engine = new SlowverbEngine({
  workerFactory: () => new Worker(WORKER_ENTRY, { type: "module" }),
  coreURL: CORE_URL,
  wasmURL: WASM_URL,
  workerURL: WORKER_URL,
});

let progressHandler = null;
let logHandler = null;

function setProgressHandler(fn) {
  progressHandler = typeof fn === "function" ? fn : null;
}

function setLogHandler(fn) {
  logHandler = typeof fn === "function" ? fn : null;
}

async function loadAndProbe(source) {
  const sourcePayload = source?.source ?? source;
  console.info("[SlowverbBridge] loadAndProbe:start", {
    fileId: sourcePayload?.fileId,
  });
  const normalized = normalizeSource(sourcePayload);
  const result = await engine.probe(normalized, buildCallbacks(normalized.fileId));
  console.info("[SlowverbBridge] loadAndProbe:ok", { fileId: result.fileId });
  return { type: "probe-ok", payload: result };
}

async function renderPreview(params) {
  console.info("[SlowverbBridge] renderPreview:start", {
    fileId: params?.source?.fileId,
  });
  const normalized = normalizeRender(params);
  const jobId = normalized.jobId ?? createJobId();
  const result = await engine.renderPreview({ ...normalized, jobId }, buildCallbacks(jobId));
  console.info("[SlowverbBridge] renderPreview:ok", { jobId, fileId: result.fileId });
  return { type: "render-preview-ok", payload: { buffer: result.buffer, jobId } };
}

async function renderFull(params) {
  console.info("[SlowverbBridge] renderFull:start", {
    fileId: params?.source?.fileId,
  });
  const normalized = normalizeRender(params);
  const jobId = normalized.jobId ?? createJobId();
  const result = await engine.renderFull({ ...normalized, jobId }, buildCallbacks(jobId));
  console.info("[SlowverbBridge] renderFull:ok", { jobId, fileId: result.fileId });
  return {
    type: "render-full-ok",
    payload: { outputBuffer: result.buffer, format: result.format, jobId },
  };
}

async function waveform(params) {
  const normalized = normalizeWaveform(params);
  const result = await engine.waveform(normalized, buildCallbacks(normalized.source.fileId));
  return { type: "waveform-ok", payload: result };
}

async function cancel(jobId) {
  await engine.cancel(jobId);
  return { type: "cancel-ok", jobId };
}

function buildCallbacks(jobId) {
  return {
    onProgress: (value, stage) => emitProgress(jobId, value, stage),
    onLog: (level, message) => emitLog(jobId, level, message),
  };
}

function normalizeSource(source) {
  const data = toArrayBuffer(source.data ?? source.bytes);
  return {
    fileId: source.fileId,
    filename: source.filename ?? "source",
    data,
  };
}

function normalizeRender(params) {
  const source = normalizeSource(params.source);
  return {
    source,
    filterGraph: params.filterGraph ?? params.filterChain,
    dspSpec: params.dspSpec ?? params.spec,
    format: params.format ?? "mp3",
    bitrateKbps: params.bitrateKbps,
    startSec: params.startSec,
    durationSec: params.durationSec,
    jobId: params.jobId,
  };
}

function normalizeWaveform(params) {
  return {
    source: normalizeSource(params.source),
    points: params.points ?? 256,
  };
}

function toArrayBuffer(value) {
  if (value instanceof ArrayBuffer) return value;
  if (ArrayBuffer.isView(value)) {
    const offset = value.byteOffset ?? 0;
    const length = value.byteLength ?? value.buffer.byteLength;
    return value.buffer.slice(offset, offset + length);
  }
  if (typeof value === "string") throw new Error("Expected binary audio data");
  return new Uint8Array(value).buffer;
}

function emitProgress(jobId, value, stage) {
  if (progressHandler) {
    progressHandler({ jobId, value, stage });
  }
}

function emitLog(jobId, level, message) {
  const logLine = `[SlowverbBridge][${jobId ?? "job"}][${level}] ${message}`;
  if (level === "error") console.error(logLine);
  else if (level === "warn") console.warn(logLine);
  else if (level === "debug") console.debug(logLine);
  else console.info(logLine);
  if (logHandler) {
    logHandler({ jobId, level, message });
  }
}

function createJobId() {
  return typeof crypto !== "undefined" && crypto.randomUUID
    ? crypto.randomUUID()
    : `job-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function getMemoryUsage() {
  const perf = performance;
  const memory = perf && perf.memory;
  if (!memory) return null;
  return {
    usedJSHeapSize: memory.usedJSHeapSize,
    totalJSHeapSize: memory.totalJSHeapSize,
    jsHeapSizeLimit: memory.jsHeapSizeLimit,
  };
}

window.SlowverbBridge = {
  loadAndProbe,
  renderPreview,
  renderFull,
  waveform,
  cancel,
  setProgressHandler,
  setLogHandler,
  getMemoryUsage,
};
