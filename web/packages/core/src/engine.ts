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
} from "@slowverb/shared";
import type { DspSpec } from "@slowverb/shared";

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
      const payload = this.buildRenderPayload(request);
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

  private buildRenderPayload(request: RenderRequest): RenderPayload {
    const filterGraph = this.resolveFilterGraph(request);
    return {
      fileId: request.source.fileId,
      filterGraph,
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
}

type PendingRequest = {
  resolve: (payload: unknown) => void;
  reject: (error: Error) => void;
  resolveOnReady?: boolean;
};

class WorkerRunner {
  private readonly worker: Worker;
  private readonly pending = new Map<string, PendingRequest>();
  private readonly callbacks?: RenderCallbacks;
  private requestCounter = 0;
  private readonly requestTimeoutMs = 120_000;

  constructor(factory: WorkerFactory, callbacks?: RenderCallbacks) {
    this.worker = factory();
    this.callbacks = callbacks;
    this.worker.addEventListener("message", (event) => this.handleMessage(event.data as WorkerEvent));
    this.worker.addEventListener("error", (event) => {
      const message = event.message || "Worker error";
      this.rejectAll(new Error(message));
    });
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
    return this.sendWithLog<RenderResultPayload>({ type: type, requestId, jobId, payload }, { transfer: [] });
  }

  async waveform(payload: WaveformPayload, jobId: string): Promise<WorkerResultPayload> {
    const requestId = this.nextRequestId();
    return this.sendWithLog<WorkerResultPayload>({ type: "WAVEFORM", requestId, jobId, payload });
  }

  async cancel(jobId: string): Promise<void> {
    const payload: CancelPayload = { jobId };
    const requestId = this.nextRequestId();
    await this.sendWithLog<void>({ type: "CANCEL", requestId, jobId, payload }).catch(() => { });
  }

  terminate(): void {
    this.rejectAll(new Error("Worker terminated"));
    this.worker.terminate();
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
}

const defaultWorkerFactory: WorkerFactory = () =>
  new Worker(new URL("../core-worker/dist/worker.js", import.meta.url), { type: "module" });

function createJobId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `job-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
