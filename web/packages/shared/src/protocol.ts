import type { DspSpec, MasteringSpec } from "./dsp.js";

export type WorkerRequestType =
  | "INIT"
  | "LOAD_SOURCE"
  | "PROBE"
  | "RENDER_PREVIEW"
  | "RENDER_FULL"
  | "WAVEFORM"
  | "CANCEL"
  | "PING"
  | "DECODE_PCM"
  | "ENCODE_PCM";

export type ExportFormat = "mp3" | "wav" | "flac" | "aac";

export interface InitPayload {
  readonly coreURL?: string;
  readonly wasmURL?: string;
  readonly workerURL?: string;
  readonly logLevel?: "quiet" | "info" | "warn" | "error" | "debug";
}

export interface LoadSourcePayload {
  readonly fileId: string;
  readonly filename?: string;
  readonly data: ArrayBuffer;
}

export interface ProbePayload {
  readonly fileId: string;
}

export interface RenderPayload {
  readonly fileId: string;
  readonly filterGraph?: string;
  readonly dspSpec?: DspSpec;
  readonly reverbIR?: ArrayBuffer;
  readonly reverbIRSampleRate?: number;
  readonly mastering?: MasteringSpec;
  readonly format: ExportFormat;
  readonly bitrateKbps?: number;
  readonly startSec?: number;
  readonly durationSec?: number;
}

export interface WaveformPayload {
  readonly fileId: string;
  readonly points?: number;
}

export interface CancelPayload {
  readonly jobId: string;
}

export interface DecodePcmPayload {
  readonly fileId: string;
}

export interface EncodePcmPayload {
  readonly left: Float32Array;
  readonly right: Float32Array;
  readonly sampleRate: number;
  readonly format: ExportFormat;
  readonly bitrateKbps?: number;
}

export type WorkerRequest =
  | { type: "INIT"; requestId: string; payload: InitPayload }
  | { type: "LOAD_SOURCE"; requestId: string; payload: LoadSourcePayload }
  | { type: "PROBE"; requestId: string; payload: ProbePayload }
  | { type: "RENDER_PREVIEW"; requestId: string; jobId: string; payload: RenderPayload }
  | { type: "RENDER_FULL"; requestId: string; jobId: string; payload: RenderPayload }
  | { type: "WAVEFORM"; requestId: string; jobId: string; payload: WaveformPayload }
  | { type: "CANCEL"; requestId: string; jobId: string; payload: CancelPayload }
  | { type: "PING"; requestId: string }
  | { type: "DECODE_PCM"; requestId: string; payload: DecodePcmPayload }
  | { type: "ENCODE_PCM"; requestId: string; payload: EncodePcmPayload };

export interface LoadSourceResultPayload {
  readonly fileId: string;
}

export interface ProbeResultPayload {
  readonly fileId: string;
  readonly durationMs: number | null;
  readonly sampleRate: number;
  readonly channels: number;
  readonly format: string;
}

export interface RenderResultPayload {
  readonly fileId: string;
  readonly format: ExportFormat;
  readonly buffer: ArrayBuffer;
}

export interface WaveformResultPayload {
  readonly fileId: string;
  readonly samples: Float32Array;
}

export interface PingResultPayload {
  readonly pong: boolean;
}

export interface DecodePcmResultPayload {
  readonly left: Float32Array;
  readonly right: Float32Array;
  readonly sampleRate: number;
}

export interface EncodePcmResultPayload {
  readonly buffer: ArrayBuffer;
}

export type WorkerResultPayload =
  | LoadSourceResultPayload
  | ProbeResultPayload
  | RenderResultPayload
  | WaveformResultPayload
  | PingResultPayload
  | DecodePcmResultPayload
  | EncodePcmResultPayload;

export type WorkerLogLevel = "info" | "warn" | "error" | "debug";

export type WorkerEvent =
  | { type: "READY"; requestId?: string }
  | { type: "LOG"; level: WorkerLogLevel; message: string }
  | { type: "PROGRESS"; jobId: string; value: number; stage?: string }
  | {
    type: "RESULT";
    requestId: string;
    jobId?: string;
    payload: WorkerResultPayload;
  }
  | { type: "CANCELLED"; requestId?: string; jobId: string; reason?: string }
  | { type: "ERROR"; requestId?: string; jobId?: string; message: string; cause?: string };

export interface EngineInitOptions {
  readonly workerFactory?: () => Worker;
  readonly coreURL?: string;
  readonly wasmURL?: string;
  readonly workerURL?: string;
}

export interface WorkerRuntimeContext {
  ffmpegReady: boolean;
  activeJobId?: string;
}
