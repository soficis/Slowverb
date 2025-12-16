// ../shared/dist/index.js
var DSP_LIMITS = {
  tempo: { min: 0.5, max: 1.5},
  pitch: { min: -12, max: 12},
  reverb: {
    decay: { min: 0, max: 0.99},
    preDelayMs: { min: 20, max: 500},
    roomScale: { min: 0, max: 1, default: 0.7 },
    mix: { min: 0, max: 1}
  },
  echo: {
    delayMs: { min: 50, max: 1e3},
    feedback: { min: 0, max: 0.9}
  },
  lowPassCutoffHz: { min: 200, max: 2e4},
  eqWarmth: { min: 0, max: 1},
  hfDamping: { min: 0, max: 1},
  stereoWidth: { min: 0.5, max: 2}
};
var SIMPLE_MASTERING_FILTER_CHAIN = "highpass=f=20,acompressor=threshold=-18dB:ratio=2:attack=10:release=200:makeup=3,alimiter=limit=0.95";
function compileFilterChain(spec) {
  const filters = [];
  appendTempo(filters, spec.tempo);
  appendPitch(filters, spec.pitch);
  appendEqWarmth(filters, spec.eqWarmth);
  appendReverb(filters, spec.reverb);
  appendEcho(filters, spec.echo);
  appendLowpass(filters, spec.lowPassCutoffHz, spec.hfDamping);
  appendStereoWidth(filters, spec.stereoWidth);
  appendMastering(filters, spec.mastering);
  return filters.length > 0 ? filters.join(",") : "anull";
}
function appendTempo(filters, tempo) {
  if (tempo === void 0 || tempo === 1) return;
  filters.push(buildTempoFilter(clamp(tempo, DSP_LIMITS.tempo)));
}
function appendPitch(filters, pitch) {
  if (pitch === void 0 || pitch === 0) return;
  filters.push(buildPitchFilter(clamp(pitch, DSP_LIMITS.pitch)));
}
function appendEqWarmth(filters, warmth) {
  if (warmth === void 0 || warmth <= 0) return;
  filters.push(buildEqWarmthFilter(clamp(warmth, DSP_LIMITS.eqWarmth)));
}
function appendReverb(filters, reverb) {
  if (!reverb) return;
  filters.push(buildReverbFilter(normalizeReverb(reverb)));
}
function appendEcho(filters, echo) {
  if (!echo) return;
  filters.push(buildEchoFilter(normalizeEcho(echo)));
}
function appendLowpass(filters, cutoffHz, hfDamping) {
  const lowpass = buildLowpassFilter(cutoffHz, hfDamping);
  if (!lowpass) return;
  filters.push(lowpass);
}
function appendStereoWidth(filters, width) {
  if (width === void 0 || width === 1) return;
  filters.push(buildStereoFilter(clamp(width, DSP_LIMITS.stereoWidth)));
}
function appendMastering(filters, mastering) {
  if (!isMasteringEnabled(mastering)) return;
  const algorithm = mastering?.algorithm ?? "simple";
  if (algorithm !== "simple") return;
  filters.push(buildSimpleMasteringFilterChain());
}
function isMasteringEnabled(mastering) {
  return mastering?.enabled === true;
}
function buildSimpleMasteringFilterChain() {
  return SIMPLE_MASTERING_FILTER_CHAIN;
}
function buildTempoFilter(tempo) {
  if (tempo >= 0.5 && tempo <= 2) {
    return `atempo=${tempo.toFixed(4)}`;
  }
  const filters = [];
  let remaining = tempo;
  while (remaining < 0.5) {
    filters.push("atempo=0.5");
    remaining /= 0.5;
  }
  while (remaining > 2) {
    filters.push("atempo=2.0");
    remaining /= 2;
  }
  filters.push(`atempo=${remaining.toFixed(4)}`);
  return filters.join(",");
}
function buildPitchFilter(semitones) {
  const rate = Math.pow(2, semitones / 12);
  return `asetrate=44100*${rate.toFixed(4)},aresample=44100`;
}
function buildEqWarmthFilter(warmth) {
  const gain = (warmth * 6).toFixed(1);
  return `equalizer=f=300:t=h:width=200:g=${gain}`;
}
function buildReverbFilter(reverb) {
  const d1 = reverb.preDelayMs;
  const d2 = Math.round(d1 * (1 + reverb.roomScale * 0.5));
  const d3 = Math.round(d2 * 1.3);
  const decay = reverb.decay;
  const mix = reverb.mix;
  return `aecho=0.8:${mix.toFixed(2)}:${d1}|${d2}|${d3}:${(decay * 0.9).toFixed(2)}|${(decay * 0.7).toFixed(2)}|${(decay * 0.4).toFixed(2)}`;
}
function buildEchoFilter(echo) {
  return `aecho=0.8:0.5:${echo.delayMs}:${echo.feedback.toFixed(2)}`;
}
function buildLowpassFilter(cutoffHz, hfDamping) {
  if (cutoffHz !== void 0) {
    const clamped = clamp(cutoffHz, DSP_LIMITS.lowPassCutoffHz);
    return `lowpass=f=${clamped}`;
  }
  if (hfDamping !== void 0 && hfDamping > 0) {
    const clamped = clamp(hfDamping, DSP_LIMITS.hfDamping);
    const cutoff = Math.round(2e4 - clamped * 18e3);
    return `lowpass=f=${cutoff}`;
  }
  return null;
}
function buildStereoFilter(width) {
  if (width < 1) {
    return `stereotools=mlev=${width.toFixed(2)}`;
  }
  const m = (width - 1) * 2.5;
  return `extrastereo=m=${m.toFixed(2)}`;
}
function normalizeReverb(reverb) {
  return {
    decay: clamp(reverb.decay, DSP_LIMITS.reverb.decay),
    preDelayMs: clamp(reverb.preDelayMs, DSP_LIMITS.reverb.preDelayMs),
    roomScale: clamp(
      reverb.roomScale ?? DSP_LIMITS.reverb.roomScale.default,
      DSP_LIMITS.reverb.roomScale
    ),
    mix: clamp(reverb.mix, DSP_LIMITS.reverb.mix)
  };
}
function normalizeEcho(echo) {
  return {
    delayMs: clamp(echo.delayMs, DSP_LIMITS.echo.delayMs),
    feedback: clamp(echo.feedback, DSP_LIMITS.echo.feedback)
  };
}
function clamp(value, limits) {
  if (value < limits.min) return limits.min;
  if (value > limits.max) return limits.max;
  return value;
}

// src/engine.ts
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
      return await runner.waveform({ fileId: request.source.fileId, points: request.points }, jobId);
    } finally {
      runner.terminate();
    }
  }
  async probe(source, callbacks) {
    const runner = this.createRunner(callbacks);
    try {
      await runner.init(this.initPayload);
      await runner.loadSource(source);
      callbacks?.onLog?.("debug", `probe:ping-check starting`);
      const pingOk = await runner.ping();
      callbacks?.onLog?.("debug", `probe:ping-check result=${pingOk}`);
      if (!pingOk) {
        throw new Error("Worker stopped responding after LOAD_SOURCE (ping failed)");
      }
      return await runner.probe({ fileId: source.fileId });
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
    const pingOk = await runner.ping();
    if (!pingOk) {
      throw new Error("Worker stopped responding after LOAD_SOURCE (ping failed)");
    }
    await runner.probe({ fileId: source.fileId });
  }
  buildRenderPayload(request) {
    const filterGraph = this.resolveFilterGraph(request);
    return {
      fileId: request.source.fileId,
      filterGraph,
      mastering: request.dspSpec?.mastering,
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
  onMessage;
  onError;
  pending = /* @__PURE__ */ new Map();
  callbacks;
  requestCounter = 0;
  requestTimeoutMs = 12e4;
  constructor(factory, callbacks) {
    this.worker = factory();
    this.callbacks = callbacks;
    this.onMessage = (event) => this.handleMessage(event.data);
    this.onError = (event) => {
      const message = event.message || "Worker error";
      this.rejectAll(new Error(message));
    };
    this.worker.addEventListener("message", this.onMessage);
    this.worker.addEventListener("error", this.onError);
  }
  async init(payload) {
    await this.sendWithLog(
      { type: "INIT", requestId: this.nextRequestId(), payload },
      { resolveOnReady: true }
    );
  }
  async loadSource(source) {
    const payload = {
      fileId: source.fileId,
      filename: source.filename,
      data: source.data
    };
    await this.sendWithLog(
      { type: "LOAD_SOURCE", requestId: this.nextRequestId(), payload },
      { transfer: [source.data] }
    );
  }
  async probe(payload) {
    const requestId = this.nextRequestId();
    return this.sendWithLog({ type: "PROBE", requestId, payload });
  }
  async ping() {
    const requestId = this.nextRequestId();
    try {
      await this.sendWithLog({ type: "PING", requestId });
      return true;
    } catch {
      return false;
    }
  }
  async render(type, payload, jobId) {
    const requestId = this.nextRequestId();
    return this.sendWithLog({ type, requestId, jobId, payload }, { transfer: [] });
  }
  async waveform(payload, jobId) {
    const requestId = this.nextRequestId();
    return this.sendWithLog({ type: "WAVEFORM", requestId, jobId, payload });
  }
  async cancel(jobId) {
    const payload = { jobId };
    const requestId = this.nextRequestId();
    await this.sendWithLog({ type: "CANCEL", requestId, jobId, payload }).catch(() => {
    });
  }
  terminate() {
    this.rejectAll(new Error("Worker terminated"));
    this.worker.terminate();
    this.worker.removeEventListener("message", this.onMessage);
    this.worker.removeEventListener("error", this.onError);
    this.runGc();
  }
  async send(request, options) {
    return new Promise((resolve, reject) => {
      this.pending.set(request.requestId, {
        resolve,
        reject,
        resolveOnReady: options?.resolveOnReady
      });
      try {
        this.worker.postMessage(request, options?.transfer ?? []);
      } catch (postError) {
        this.callbacks?.onLog?.("error", `worker:postMessage failed for ${request.type}: ${String(postError)}`);
        this.pending.delete(request.requestId);
        reject(new Error(`postMessage failed: ${String(postError)}`));
      }
    });
  }
  async sendWithLog(request, options) {
    this.callbacks?.onLog?.("debug", `worker:send ${request.type} (${request.requestId})`);
    const timeout = setTimeout(() => {
      this.callbacks?.onLog?.("error", `worker:timeout ${request.type} (${request.requestId})`);
      this.rejectIfPending(request.requestId, new Error(`Worker timeout: ${request.type}`));
    }, this.requestTimeoutMs);
    try {
      return await this.send(request, options);
    } finally {
      clearTimeout(timeout);
    }
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
      const detail = event.cause ? `${event.message}: ${event.cause}` : event.message;
      this.callbacks?.onLog?.("error", detail);
      const error = new Error(detail);
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
  runGc() {
    const maybeGc = globalThis.gc;
    if (typeof maybeGc === "function") {
      maybeGc();
    }
  }
};
var defaultWorkerFactory = () => new Worker(new URL("../core-worker/dist/worker.js", import.meta.url), { type: "module" });
function createJobId() {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `job-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

export { SlowverbEngine };
