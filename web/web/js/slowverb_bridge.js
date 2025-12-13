import { SlowverbEngine } from "./ts/core.js";

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
  const normalized = normalizeSource(source);
  const result = await engine.probe(normalized, buildCallbacks());
  return { type: "probe-ok", payload: result };
}

async function renderPreview(params) {
  const normalized = normalizeRender(params);
  const jobId = normalized.jobId ?? createJobId();
  const result = await engine.renderPreview({ ...normalized, jobId }, buildCallbacks(jobId));
  return { type: "render-preview-ok", payload: { buffer: result.buffer, jobId } };
}

async function renderFull(params) {
  const normalized = normalizeRender(params);
  const jobId = normalized.jobId ?? createJobId();
  const result = await engine.renderFull({ ...normalized, jobId }, buildCallbacks(jobId));
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
  if (ArrayBuffer.isView(value)) return value.buffer;
  if (typeof value === "string") throw new Error("Expected binary audio data");
  return new Uint8Array(value).buffer;
}

function emitProgress(jobId, value, stage) {
  if (progressHandler) {
    progressHandler({ jobId, value, stage });
  }
}

function emitLog(jobId, level, message) {
  if (logHandler) {
    logHandler({ jobId, level, message });
  }
}

function createJobId() {
  return typeof crypto !== "undefined" && crypto.randomUUID
    ? crypto.randomUUID()
    : `job-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

window.SlowverbBridge = {
  loadAndProbe,
  renderPreview,
  renderFull,
  waveform,
  cancel,
  setProgressHandler,
  setLogHandler,
};
