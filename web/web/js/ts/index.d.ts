import { DspSpec, ExportFormat, WorkerLogLevel, EngineInitOptions, WorkerResultPayload, ProbeResultPayload, DecodePcmResultPayload, EncodePcmPayload, EncodePcmResultPayload } from '@slowverb/shared';

interface SourceData {
    readonly fileId: string;
    readonly filename?: string;
    readonly data: ArrayBuffer;
}
interface RenderRequest {
    readonly source: SourceData;
    readonly filterGraph?: string;
    readonly dspSpec?: DspSpec;
    readonly format?: ExportFormat;
    readonly bitrateKbps?: number;
    readonly startSec?: number;
    readonly durationSec?: number;
    readonly jobId?: string;
}
interface RenderResult {
    readonly jobId: string;
    readonly fileId: string;
    readonly format: ExportFormat;
    readonly buffer: ArrayBuffer;
}
interface RenderCallbacks {
    readonly onProgress?: (value: number, stage?: string) => void;
    readonly onLog?: (level: WorkerLogLevel, message: string) => void;
}
interface WaveformRequest {
    readonly source: SourceData;
    readonly points?: number;
}
declare class SlowverbEngine {
    private readonly workerFactory;
    private readonly initPayload;
    private readonly active;
    private readonly toneReverbIrCache;
    constructor(options?: EngineInitOptions);
    renderPreview(request: RenderRequest, callbacks?: RenderCallbacks): Promise<RenderResult>;
    renderFull(request: RenderRequest, callbacks?: RenderCallbacks): Promise<RenderResult>;
    waveform(request: WaveformRequest, callbacks?: RenderCallbacks): Promise<WorkerResultPayload>;
    probe(source: SourceData, callbacks?: RenderCallbacks): Promise<ProbeResultPayload>;
    decodeToFloatPCM(source: SourceData, callbacks?: RenderCallbacks): Promise<DecodePcmResultPayload>;
    encodeFromFloatPCM(payload: EncodePcmPayload, callbacks?: RenderCallbacks): Promise<EncodePcmResultPayload>;
    private runRender;
    private createRunner;
    private prepareSource;
    private buildRenderPayload;
    private resolveFilterGraph;
    private resolveToneReverbIR;
    cancel(jobId: string): Promise<boolean>;
    resumeAudioContext(): Promise<boolean>;
}

export { type RenderCallbacks, type RenderRequest, type RenderResult, SlowverbEngine, type SourceData, type WaveformRequest };
