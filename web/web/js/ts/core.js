// src/engine.ts
import { compileFilterChain } from "@slowverb/shared";
var SlowverbEngine = class {
  workerFactory;
  initPayload;
  active = /* @__PURE__ */ new Map();
  constructor(options = {}) {
    this.workerFactory = options.workerFactory ?? defaultWorkerFactory;
    this.initPayload = {
      coreURL: options.coreURL,
      wasmURL: options.wasmURL,
      workerURL: options.workerURL
    };
  }
  async renderPreview(request, callbacks) {
    return this.runRender("RENDER_PREVIEW", request, callbacks);
  }
  async renderFull(request, callbacks) {
    return this.runRender("RENDER_FULL", request, callbacks);
  }
  async waveform(request, callbacks) {
    const runner = this.createRunner(callbacks);
    try {
      const jobId = request.source.fileId;
      await this.prepareSource(runner, request.source);
      return runner.waveform({ fileId: request.source.fileId, points: request.points }, jobId);
    } finally {
      runner.terminate();
    }
  }
  async probe(source, callbacks) {
    const runner = this.createRunner(callbacks);
    try {
      await runner.init(this.initPayload);
      await runner.loadSource(source);
      return runner.probe({ fileId: source.fileId });
    } finally {
      runner.terminate();
    }
  }
  async runRender(type, request, callbacks) {
    const runner = this.createRunner(callbacks);
    const jobId = request.jobId ?? createJobId();
    this.active.set(jobId, runner);
    try {
      await this.prepareSource(runner, request.source);
      const payload = this.buildRenderPayload(request);
      const result = await runner.render(type, payload, jobId);
      return { jobId, fileId: payload.fileId, format: payload.format, buffer: result.buffer };
    } finally {
      this.active.delete(jobId);
      runner.terminate();
    }
  }
  createRunner(callbacks) {
    return new WorkerRunner(this.workerFactory, callbacks);
  }
  async prepareSource(runner, source) {
    await runner.init(this.initPayload);
    await runner.loadSource(source);
    await runner.probe({ fileId: source.fileId });
  }
  buildRenderPayload(request) {
    const filterGraph = this.resolveFilterGraph(request);
    return {
      fileId: request.source.fileId,
      filterGraph,
      format: request.format ?? "mp3",
      bitrateKbps: request.bitrateKbps,
      startSec: request.startSec,
      durationSec: request.durationSec
    };
  }
  resolveFilterGraph(request) {
    if (request.filterGraph) return request.filterGraph;
    if (request.dspSpec) return compileFilterChain(request.dspSpec);
    return void 0;
  }
  async cancel(jobId) {
    const runner = this.active.get(jobId);
    if (!runner) return false;
    try {
      await runner.cancel(jobId);
    } finally {
      runner.terminate();
      this.active.delete(jobId);
    }
    return true;
  }
};
var WorkerRunner = class {
  worker;
  pending = /* @__PURE__ */ new Map();
  callbacks;
  requestCounter = 0;
  constructor(factory, callbacks) {
    this.worker = factory();
    this.callbacks = callbacks;
    this.worker.addEventListener("message", (event) => this.handleMessage(event.data));
    this.worker.addEventListener("error", (event) => {
      const message = event.message || "Worker error";
      this.rejectAll(new Error(message));
    });
  }
  async init(payload) {
    await this.send({ type: "INIT", requestId: this.nextRequestId(), payload }, { resolveOnReady: true });
  }
  async loadSource(source) {
    const payload = {
      fileId: source.fileId,
      filename: source.filename,
      data: source.data
    };
    await this.send({ type: "LOAD_SOURCE", requestId: this.nextRequestId(), payload }, { transfer: [source.data] });
  }
  async probe(payload) {
    const requestId = this.nextRequestId();
    return this.send({ type: "PROBE", requestId, payload });
  }
  async render(type, payload, jobId) {
    const requestId = this.nextRequestId();
    return this.send({ type, requestId, jobId, payload }, { transfer: [] });
  }
  async waveform(payload, jobId) {
    const requestId = this.nextRequestId();
    return this.send({ type: "WAVEFORM", requestId, jobId, payload });
  }
  async cancel(jobId) {
    const payload = { jobId };
    const requestId = this.nextRequestId();
    await this.send({ type: "CANCEL", requestId, jobId, payload }).catch(() => {
    });
  }
  terminate() {
    this.rejectAll(new Error("Worker terminated"));
    this.worker.terminate();
  }
  async send(request, options) {
    return new Promise((resolve, reject) => {
      this.pending.set(request.requestId, {
        resolve,
        reject,
        resolveOnReady: options?.resolveOnReady
      });
      this.worker.postMessage(request, options?.transfer ?? []);
    });
  }
  handleMessage(event) {
    this.forwardEvent(event);
    if (event.type === "READY") {
      this.resolveIfPending(event.requestId, void 0, true);
      return;
    }
    if (event.type === "RESULT") {
      this.resolveIfPending(event.requestId, event.payload);
      return;
    }
    if (event.type === "ERROR") {
      const error = new Error(event.message);
      this.rejectIfPending(event.requestId, error);
      return;
    }
    if (event.type === "CANCELLED") {
      const message = event.reason ?? "Job cancelled";
      this.rejectIfPending(event.requestId, new Error(message));
    }
  }
  resolveIfPending(requestId, payload, readyOnly = false) {
    if (!requestId) return;
    const pending = this.pending.get(requestId);
    if (!pending) return;
    if (readyOnly && !pending.resolveOnReady) return;
    this.pending.delete(requestId);
    pending.resolve(payload);
  }
  rejectIfPending(requestId, error) {
    if (!requestId) {
      this.rejectAll(error);
      return;
    }
    const pending = this.pending.get(requestId);
    if (!pending) return;
    this.pending.delete(requestId);
    pending.reject(error);
  }
  rejectAll(error) {
    for (const pending of this.pending.values()) {
      pending.reject(error);
    }
    this.pending.clear();
  }
  forwardEvent(event) {
    if (!this.callbacks) return;
    if (event.type === "LOG") {
      this.callbacks.onLog?.(event.level, event.message);
      return;
    }
    if (event.type === "PROGRESS") {
      this.callbacks.onProgress?.(event.value, event.stage);
    }
  }
  nextRequestId() {
    this.requestCounter += 1;
    return `req-${this.requestCounter}-${Date.now()}`;
  }
};
var defaultWorkerFactory = () => new Worker(new URL("../core-worker/dist/worker.js", import.meta.url), { type: "module" });
function createJobId() {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `job-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
export {
  SlowverbEngine
};
