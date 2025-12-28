import { compileFilterChain } from "@slowverb/shared";
import type {
  CancelPayload,
  EngineInitOptions,
  ExportFormat,
  InitPayload,
  LoadSourcePayload,
  PingResultPayload,
  ProbeResultPayload,
  RenderPayload,
  RenderResultPayload,
  WaveformPayload,
  WorkerEvent,
  WorkerLogLevel,
  WorkerRequest,
  WorkerResultPayload,
  DecodePcmPayload,
  EncodePcmPayload,
  DecodePcmResultPayload,
  EncodePcmResultPayload,
} from "@slowverb/shared";
import type { DspSpec } from "@slowverb/shared";
import { Reverb, start as toneStart } from "tone";

type WorkerFactory = () => Worker;

export interface SourceData {
  readonly fileId: string;
  readonly filename?: string;
  readonly data: ArrayBuffer;
}

export interface RenderRequest {
  readonly source: SourceData;
  readonly filterGraph?: string;
  readonly dspSpec?: DspSpec;
  readonly format?: ExportFormat;
  readonly bitrateKbps?: number;
  readonly startSec?: number;
  readonly durationSec?: number;
  readonly jobId?: string;
}

export interface RenderResult {
  readonly jobId: string;
  readonly fileId: string;
  readonly format: ExportFormat;
  readonly buffer: ArrayBuffer;
}

export interface RenderCallbacks {
  readonly onProgress?: (value: number, stage?: string) => void;
  readonly onLog?: (level: WorkerLogLevel, message: string) => void;
}

export interface WaveformRequest {
  readonly source: SourceData;
  readonly points?: number;
}

export class SlowverbEngine {
  private readonly workerFactory: WorkerFactory;
  private readonly initPayload: InitPayload;
  private readonly active = new Map<string, WorkerRunner>();
  private readonly toneReverbIrCache = new Map<string, { pcm: ArrayBuffer; sampleRate: number }>();

  constructor(options: EngineInitOptions = {}) {
    this.workerFactory = options.workerFactory ?? defaultWorkerFactory;
    this.initPayload = {
      coreURL: options.coreURL,
      wasmURL: options.wasmURL,
      workerURL: options.workerURL,
    };
  }

  async renderPreview(request: RenderRequest, callbacks?: RenderCallbacks): Promise<RenderResult> {
    return this.runRender("RENDER_PREVIEW", request, callbacks);
  }

  async renderFull(request: RenderRequest, callbacks?: RenderCallbacks): Promise<RenderResult> {
    return this.runRender("RENDER_FULL", request, callbacks);
  }

  async waveform(request: WaveformRequest, callbacks?: RenderCallbacks): Promise<WorkerResultPayload> {
    const runner = this.createRunner(callbacks);
    try {
      const jobId = request.source.fileId;
      await this.prepareSource(runner, request.source);
      return await runner.waveform({ fileId: request.source.fileId, points: request.points }, jobId);
    } finally {
      runner.terminate();
    }
  }

  async probe(source: SourceData, callbacks?: RenderCallbacks): Promise<ProbeResultPayload> {
    const runner = this.createRunner(callbacks);
    try {
      await runner.init(this.initPayload);
      await runner.loadSource(source);

      // Diagnostic: verify worker is responsive before PROBE
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

  async decodeToFloatPCM(source: SourceData, callbacks?: RenderCallbacks): Promise<DecodePcmResultPayload> {
    const runner = this.createRunner(callbacks);
    try {
      await this.prepareSource(runner, source);
      return await runner.decodePCM({ fileId: source.fileId });
    } finally {
      runner.terminate();
    }
  }

  async encodeFromFloatPCM(
    payload: EncodePcmPayload,
    callbacks?: RenderCallbacks
  ): Promise<EncodePcmResultPayload> {
    const runner = this.createRunner(callbacks);
    try {
      await runner.init(this.initPayload);
      return await runner.encodePCM(payload);
    } finally {
      runner.terminate();
    }
  }

  private async runRender(
    type: "RENDER_PREVIEW" | "RENDER_FULL",
    request: RenderRequest,
    callbacks?: RenderCallbacks
  ): Promise<RenderResult> {
    const runner = this.createRunner(callbacks);
    const jobId = request.jobId ?? createJobId();
    this.active.set(jobId, runner);

    try {
      await this.prepareSource(runner, request.source);
      const payload = await this.buildRenderPayload(request);
      const result = await runner.render(type, payload, jobId);
      return { jobId, fileId: payload.fileId, format: payload.format, buffer: result.buffer };
    } finally {
      this.active.delete(jobId);
      runner.terminate();
    }
  }

  private createRunner(callbacks?: RenderCallbacks): WorkerRunner {
    return new WorkerRunner(this.workerFactory, callbacks);
  }

  private async prepareSource(runner: WorkerRunner, source: SourceData): Promise<void> {
    await runner.init(this.initPayload);
    await runner.loadSource(source);

    // Diagnostic: verify worker is still responsive after LOAD_SOURCE
    const pingOk = await runner.ping();
    if (!pingOk) {
      throw new Error("Worker stopped responding after LOAD_SOURCE (ping failed)");
    }

    await runner.probe({ fileId: source.fileId });
  }

  private async buildRenderPayload(request: RenderRequest): Promise<RenderPayload> {
    const filterGraph = this.resolveFilterGraph(request);
    const toneIr = await this.resolveToneReverbIR(request.dspSpec);
    return {
      fileId: request.source.fileId,
      filterGraph,
      dspSpec: request.dspSpec,
      reverbIR: toneIr?.pcm,
      reverbIRSampleRate: toneIr?.sampleRate,
      mastering: request.dspSpec?.mastering,
      format: request.format ?? "mp3",
      bitrateKbps: request.bitrateKbps,
      startSec: request.startSec,
      durationSec: request.durationSec,
    };
  }

  private resolveFilterGraph(request: RenderRequest): string | undefined {
    if (request.filterGraph) return request.filterGraph;
    if (request.dspSpec) return compileFilterChain(request.dspSpec);
    return undefined;
  }

  private async resolveToneReverbIR(
    spec?: DspSpec
  ): Promise<{ pcm: ArrayBuffer; sampleRate: number } | null> {
    if (!spec) return null;
    if ((spec.quality?.reverb ?? "ffmpeg") !== "tone") return null;
    if (!spec.reverb) return null;
    if (spec.reverb.mix <= 0) return null;

    const key = JSON.stringify({
      decay: spec.reverb.decay,
      preDelayMs: spec.reverb.preDelayMs,
      roomScale: spec.reverb.roomScale ?? null,
    });

    const cached = this.toneReverbIrCache.get(key);
    if (cached) {
      return { pcm: cached.pcm.slice(0), sampleRate: cached.sampleRate };
    }

    try {
      const generated = await withTimeout(generateToneReverbIr(spec.reverb), 12_000, "Tone IR generation timed out");
      this.toneReverbIrCache.set(key, generated);
      return { pcm: generated.pcm.slice(0), sampleRate: generated.sampleRate };
    } catch (error) {
      console.warn("[SlowverbEngine] Tone reverb IR generation failed; falling back to FFmpeg reverb", error);
      return null;
    }
  }

  async cancel(jobId: string): Promise<boolean> {
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

  async resumeAudioContext(): Promise<boolean> {
    try {
      await toneStart();
      return true;
    } catch (error) {
      console.debug("[SlowverbEngine] Tone.start() blocked or failed", error);
      return false;
    }
  }
}

type PendingRequest = {
  resolve: (payload: unknown) => void;
  reject: (error: Error) => void;
  resolveOnReady?: boolean;
};

class WorkerRunner {
  private readonly worker: Worker;
  private readonly onMessage: (event: MessageEvent<WorkerEvent>) => void;
  private readonly onError: (event: ErrorEvent) => void;
  private readonly pending = new Map<string, PendingRequest>();
  private readonly callbacks?: RenderCallbacks;
  private requestCounter = 0;
  private readonly requestTimeoutMs = 600_000; // 10 minutes for Level 5 mastering

  constructor(factory: WorkerFactory, callbacks?: RenderCallbacks) {
    this.worker = factory();
    this.callbacks = callbacks;
    this.onMessage = (event) => this.handleMessage(event.data as WorkerEvent);
    this.onError = (event) => {
      const message = event.message || "Worker error";
      this.rejectAll(new Error(message));
    };
    this.worker.addEventListener("message", this.onMessage);
    this.worker.addEventListener("error", this.onError);
  }

  async init(payload: InitPayload): Promise<void> {
    await this.sendWithLog<void>(
      { type: "INIT", requestId: this.nextRequestId(), payload },
      { resolveOnReady: true }
    );
  }

  async loadSource(source: SourceData): Promise<void> {
    const payload: LoadSourcePayload = {
      fileId: source.fileId,
      filename: source.filename,
      data: source.data,
    };
    await this.sendWithLog(
      { type: "LOAD_SOURCE", requestId: this.nextRequestId(), payload },
      { transfer: [source.data] }
    );
  }

  async probe(payload: { fileId: string }): Promise<ProbeResultPayload> {
    const requestId = this.nextRequestId();
    return this.sendWithLog<ProbeResultPayload>({ type: "PROBE", requestId, payload });
  }

  async ping(): Promise<boolean> {
    const requestId = this.nextRequestId();
    try {
      await this.sendWithLog<PingResultPayload>({ type: "PING", requestId });
      return true;
    } catch {
      return false;
    }
  }

  async render(
    type: "RENDER_PREVIEW" | "RENDER_FULL",
    payload: RenderPayload,
    jobId: string
  ): Promise<RenderResultPayload> {
    const requestId = this.nextRequestId();
    const transfer: Transferable[] = [];
    if (payload.reverbIR) transfer.push(payload.reverbIR);
    return this.sendWithLog<RenderResultPayload>({ type: type, requestId, jobId, payload }, { transfer });
  }

  async waveform(payload: WaveformPayload, jobId: string): Promise<WorkerResultPayload> {
    const requestId = this.nextRequestId();
    return this.sendWithLog<WorkerResultPayload>({ type: "WAVEFORM", requestId, jobId, payload });
  }

  async decodePCM(payload: DecodePcmPayload): Promise<DecodePcmResultPayload> {
    const requestId = this.nextRequestId();
    return this.sendWithLog<DecodePcmResultPayload>({ type: "DECODE_PCM", requestId, payload });
  }

  async encodePCM(payload: EncodePcmPayload): Promise<EncodePcmResultPayload> {
    const requestId = this.nextRequestId();
    const transfer = [payload.left.buffer, payload.right.buffer];
    return this.sendWithLog<EncodePcmResultPayload>({ type: "ENCODE_PCM", requestId, payload }, { transfer });
  }

  async cancel(jobId: string): Promise<void> {
    const payload: CancelPayload = { jobId };
    const requestId = this.nextRequestId();
    await this.sendWithLog<void>({ type: "CANCEL", requestId, jobId, payload }).catch(() => { });
  }

  terminate(): void {
    this.rejectAll(new Error("Worker terminated"));
    this.worker.terminate();
    this.worker.removeEventListener("message", this.onMessage);
    this.worker.removeEventListener("error", this.onError);
    this.runGc();
  }

  private async send<T extends WorkerResultPayload | void>(
    request: WorkerRequest,
    options?: { transfer?: Transferable[]; resolveOnReady?: boolean }
  ): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      this.pending.set(request.requestId, {
        resolve: resolve as unknown as (payload: unknown) => void,
        reject,
        resolveOnReady: options?.resolveOnReady,
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

  private async sendWithLog<T extends WorkerResultPayload | void>(
    request: WorkerRequest,
    options?: { transfer?: Transferable[]; resolveOnReady?: boolean }
  ): Promise<T> {
    this.callbacks?.onLog?.("debug", `worker:send ${request.type} (${request.requestId})`);

    const timeout = setTimeout(() => {
      this.callbacks?.onLog?.("error", `worker:timeout ${request.type} (${request.requestId})`);
      this.rejectIfPending(request.requestId, new Error(`Worker timeout: ${request.type}`));
    }, this.requestTimeoutMs);

    try {
      return await this.send<T>(request, options);
    } finally {
      clearTimeout(timeout);
    }
  }

  private handleMessage(event: WorkerEvent): void {
    this.forwardEvent(event);

    if (event.type === "READY") {
      this.resolveIfPending(event.requestId, undefined, true);
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

  private resolveIfPending(requestId?: string, payload?: unknown, readyOnly = false): void {
    if (!requestId) return;
    const pending = this.pending.get(requestId);
    if (!pending) return;
    if (readyOnly && !pending.resolveOnReady) return;
    this.pending.delete(requestId);
    pending.resolve(payload);
  }

  private rejectIfPending(requestId: string | undefined, error: Error): void {
    if (!requestId) {
      this.rejectAll(error);
      return;
    }
    const pending = this.pending.get(requestId);
    if (!pending) return;
    this.pending.delete(requestId);
    pending.reject(error);
  }

  private rejectAll(error: Error): void {
    for (const pending of this.pending.values()) {
      pending.reject(error);
    }
    this.pending.clear();
  }

  private forwardEvent(event: WorkerEvent): void {
    if (!this.callbacks) return;

    if (event.type === "LOG") {
      this.callbacks.onLog?.(event.level, event.message);
      return;
    }

    if (event.type === "PROGRESS") {
      this.callbacks.onProgress?.(event.value, event.stage);
    }
  }

  private nextRequestId(): string {
    this.requestCounter += 1;
    return `req-${this.requestCounter}-${Date.now()}`;
  }

  private runGc(): void {
    const maybeGc = (globalThis as { gc?: () => void }).gc;
    if (typeof maybeGc === "function") {
      maybeGc();
    }
  }
}

async function generateToneReverbIr(
  reverb: NonNullable<DspSpec["reverb"]>
): Promise<{ pcm: ArrayBuffer; sampleRate: number }> {
  // Ensure AudioContext is started (required for browser autoplay policy)
  try {
    await toneStart();
  } catch (e) {
    console.warn("[generateToneReverbIr] Tone.start() failed:", e);
  }

  const decaySeconds = clampNumber(0.1 + reverb.decay * 6.0, 0.1, 8.0);
  const roomScale = clampNumber(reverb.roomScale ?? 0.5, 0.0, 1.0);
  const scaledDecay = clampNumber(decaySeconds * (0.7 + roomScale * 0.2), 0.1, 8.0);
  const preDelaySeconds = clampNumber(reverb.preDelayMs, 0, 500) / 1000;

  const effect = new Reverb({ decay: scaledDecay, preDelay: preDelaySeconds });
  try {
    // Wait for the Reverb effect to be fully ready
    await effect.ready;

    // Give the internal convolver time to fully initialize
    await new Promise(resolve => setTimeout(resolve, 100));

    // Access the internal convolver - Tone.js v15 structure
    const effectAny = effect as any;
    let audioBuffer: AudioBuffer | undefined;

    // Try multiple access patterns for different Tone.js versions
    // Pattern 1: Tone.js v15+ with _convolver.buffer as a Tone Param
    if (effectAny._convolver?.buffer) {
      const bufferParam = effectAny._convolver.buffer;
      if (typeof bufferParam?.get === "function") {
        audioBuffer = bufferParam.get();
      } else if (bufferParam instanceof AudioBuffer) {
        audioBuffer = bufferParam;
      } else if (typeof bufferParam === "object" && bufferParam?.value instanceof AudioBuffer) {
        audioBuffer = bufferParam.value;
      }
    }

    // Pattern 2: Direct _convolver access
    if (!audioBuffer && effectAny._convolver) {
      const convolver = effectAny._convolver;
      if (convolver.buffer instanceof AudioBuffer) {
        audioBuffer = convolver.buffer;
      } else if (convolver._buffer instanceof AudioBuffer) {
        audioBuffer = convolver._buffer;
      }
    }

    // Pattern 3: Try accessing via the convolver's internal structure
    if (!audioBuffer && effectAny.convolver) {
      const convolver = effectAny.convolver;
      if (typeof convolver.buffer?.get === "function") {
        audioBuffer = convolver.buffer.get();
      } else if (convolver.buffer instanceof AudioBuffer) {
        audioBuffer = convolver.buffer;
      }
    }

    // Pattern 4: Generate our own simple impulse response if Tone.js doesn't provide one
    if (!audioBuffer) {
      console.warn("[generateToneReverbIr] Could not access Tone Reverb buffer, generating synthetic IR");
      const sampleRate = 44100;
      const irLength = Math.floor(scaledDecay * sampleRate);
      const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
      audioBuffer = audioCtx.createBuffer(2, irLength, sampleRate);

      // Generate exponential decay impulse response
      for (let channel = 0; channel < 2; channel++) {
        const data = audioBuffer.getChannelData(channel);
        for (let i = 0; i < irLength; i++) {
          const t = i / sampleRate;
          const decay = Math.exp(-3 * t / scaledDecay);
          // Add some randomness for natural reverb character
          data[i] = (Math.random() * 2 - 1) * decay * 0.5;
        }
      }
      audioCtx.close();
    }

    const channels = audioBuffer.numberOfChannels;
    const frames = audioBuffer.length;
    const left = audioBuffer.getChannelData(0);
    const right = audioBuffer.getChannelData(channels > 1 ? 1 : 0);

    const interleaved = new Float32Array(frames * 2);
    for (let i = 0; i < frames; i += 1) {
      interleaved[i * 2] = left[i];
      interleaved[i * 2 + 1] = right[i];
    }

    return { pcm: interleaved.buffer, sampleRate: audioBuffer.sampleRate };
  } finally {
    effect.dispose();
  }
}


async function withTimeout<T>(promise: Promise<T>, timeoutMs: number, message: string): Promise<T> {
  let timeoutHandle: ReturnType<typeof setTimeout> | null = null;
  try {
    return await Promise.race([
      promise,
      new Promise<T>((_, reject) => {
        timeoutHandle = setTimeout(() => reject(new Error(message)), timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutHandle) clearTimeout(timeoutHandle);
  }
}

function clampNumber(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

const defaultWorkerFactory: WorkerFactory = () =>
  new Worker(new URL("../core-worker/dist/worker.js", import.meta.url), { type: "module" });

function createJobId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `job-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
