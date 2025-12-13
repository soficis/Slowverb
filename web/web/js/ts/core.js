// ../shared/dist/index.js
var DSP_LIMITS = {
  tempo: { min: 0.5, max: 1.5, default: 1 },
  pitch: { min: -12, max: 12, default: 0 },
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
  eqWarmth: { min: 0, max: 1, default: 0 },
  hfDamping: { min: 0, max: 1, default: 0 },
  stereoWidth: { min: 0.5, max: 2, default: 1 }
};
function compileFilterChain(spec) {
  const normalized = normalizeSpec(spec);
  const filters = [
    buildTempoFilter(normalized.tempo),
    buildPitchFilter(normalized.pitch),
    buildEqWarmthFilter(normalized.eqWarmth),
    buildReverbFilter(normalized.reverb),
    buildEchoFilter(normalized.echo),
    buildLowPassOrDampingFilter(normalized.lowPassCutoffHz, normalized.hfDamping),
    buildStereoWidthFilter(normalized.stereoWidth),
    normalized.normalize ? buildLoudnessNormalizationFilter() : void 0
  ].filter((value) => Boolean(value));
  return filters.length > 0 ? filters.join(",") : "anull";
}
function normalizeSpec(spec) {
  return {
    tempo: clamp(spec.tempo ?? DSP_LIMITS.tempo.default, DSP_LIMITS.tempo.min, DSP_LIMITS.tempo.max),
    pitch: clamp(spec.pitch ?? DSP_LIMITS.pitch.default, DSP_LIMITS.pitch.min, DSP_LIMITS.pitch.max),
    eqWarmth: clamp(
      spec.eqWarmth ?? DSP_LIMITS.eqWarmth.default,
      DSP_LIMITS.eqWarmth.min,
      DSP_LIMITS.eqWarmth.max
    ),
    lowPassCutoffHz: spec.lowPassCutoffHz !== void 0 ? clamp(spec.lowPassCutoffHz, DSP_LIMITS.lowPassCutoffHz.min, DSP_LIMITS.lowPassCutoffHz.max) : void 0,
    hfDamping: clamp(
      spec.hfDamping ?? DSP_LIMITS.hfDamping.default,
      DSP_LIMITS.hfDamping.min,
      DSP_LIMITS.hfDamping.max
    ),
    stereoWidth: clamp(
      spec.stereoWidth ?? DSP_LIMITS.stereoWidth.default,
      DSP_LIMITS.stereoWidth.min,
      DSP_LIMITS.stereoWidth.max
    ),
    normalize: spec.normalize ?? false,
    reverb: spec.reverb ? normalizeReverb(spec.reverb) : void 0,
    echo: spec.echo ? normalizeEcho(spec.echo) : void 0
  };
}
function normalizeReverb(reverb) {
  return {
    decay: clamp(reverb.decay, DSP_LIMITS.reverb.decay.min, DSP_LIMITS.reverb.decay.max),
    preDelayMs: clamp(
      reverb.preDelayMs,
      DSP_LIMITS.reverb.preDelayMs.min,
      DSP_LIMITS.reverb.preDelayMs.max
    ),
    roomScale: clamp(
      reverb.roomScale ?? DSP_LIMITS.reverb.roomScale.default,
      DSP_LIMITS.reverb.roomScale.min,
      DSP_LIMITS.reverb.roomScale.max
    ),
    mix: clamp(reverb.mix, DSP_LIMITS.reverb.mix.min, DSP_LIMITS.reverb.mix.max)
  };
}
function normalizeEcho(echo) {
  return {
    delayMs: clamp(echo.delayMs, DSP_LIMITS.echo.delayMs.min, DSP_LIMITS.echo.delayMs.max),
    feedback: clamp(echo.feedback, DSP_LIMITS.echo.feedback.min, DSP_LIMITS.echo.feedback.max)
  };
}
function buildTempoFilter(tempo) {
  if (tempo === 1) return void 0;
  const stages = [];
  let remaining = tempo;
  while (remaining < 0.5 || remaining > 2) {
    if (remaining < 0.5) {
      stages.push("atempo=0.5");
      remaining /= 0.5;
    } else {
      stages.push("atempo=2.0");
      remaining /= 2;
    }
  }
  stages.push(`atempo=${remaining.toFixed(4)}`);
  return stages.join(",");
}
function buildPitchFilter(semitones) {
  if (semitones === 0) return void 0;
  const rate = Math.pow(2, semitones / 12);
  return `asetrate=44100*${rate.toFixed(4)},aresample=44100`;
}
function buildEqWarmthFilter(eqWarmth) {
  if (eqWarmth <= 0) return void 0;
  const gain = (eqWarmth * 6).toFixed(1);
  return `equalizer=f=300:t=h:width=200:g=${gain}`;
}
function buildReverbFilter(reverb) {
  if (!reverb || reverb.mix <= 0 || reverb.decay <= 0) return void 0;
  const delay1 = Math.round(reverb.preDelayMs);
  const delay2 = Math.round(delay1 * (1 + reverb.roomScale * 0.5));
  const delay3 = Math.round(delay1 * (1 + reverb.roomScale));
  const decay1 = (reverb.decay * 0.9 * reverb.mix).toFixed(2);
  const decay2 = (reverb.decay * 0.7 * reverb.mix).toFixed(2);
  const decay3 = (reverb.decay * 0.4 * reverb.mix).toFixed(2);
  return `aecho=0.8:0.88:${delay1}|${delay2}|${delay3}:${decay1}|${decay2}|${decay3}`;
}
function buildEchoFilter(echo) {
  if (!echo || echo.feedback <= 0) return void 0;
  const delay = Math.round(echo.delayMs);
  const decay = echo.feedback.toFixed(2);
  return `aecho=0.8:0.9:${delay}:${decay}`;
}
function buildLowPassOrDampingFilter(cutoffHz, hfDamping) {
  if (cutoffHz !== void 0) {
    return buildLowPassFilter(cutoffHz);
  }
  if (hfDamping <= 0) return void 0;
  return buildLowPassFilter(buildHfDampingCutoff(hfDamping));
}
function buildLowPassFilter(cutoffHz) {
  const cutoff = Math.round(cutoffHz);
  return `lowpass=f=${cutoff}`;
}
function buildHfDampingCutoff(hfDamping) {
  return Math.round(2e4 - hfDamping * 18e3);
}
function buildStereoWidthFilter(width) {
  if (width === 1) return void 0;
  if (width < 1) {
    const mix = (1 - width).toFixed(2);
    return `stereotools=mlev=${mix}`;
  }
  const enhance = ((width - 1) * 2 + 1).toFixed(2);
  return `extrastereo=m=${enhance}`;
}
function buildLoudnessNormalizationFilter() {
  return "loudnorm=I=-14:LRA=11:TP=-1.5";
}
function clamp(value, min, max) {
  if (value < min) return min;
  if (value > max) return max;
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
  requestTimeoutMs = 12e4;
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
};
var defaultWorkerFactory = () => new Worker(new URL("../core-worker/dist/worker.js", import.meta.url), { type: "module" });
function createJobId() {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `job-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

export { SlowverbEngine };
