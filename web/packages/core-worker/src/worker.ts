import createFFmpegCore from "@ffmpeg/core";
import { compileFilterChain, compileFilterChainParts, log } from "@slowverb/shared";
import type {
  InitPayload,
  RenderPayload,
  WorkerEvent,
  WorkerLogLevel,
  WorkerRequest,
  WorkerResultPayload,
} from "@slowverb/shared";
import { SimpleFilter, SoundTouch } from "soundtouchjs";

const ctx = self as DedicatedWorkerGlobalScope;

console.info("[slowverb-worker] v1.1.2-debug starting", {
  hasProcess: typeof (globalThis as unknown as { process?: unknown }).process !== "undefined",
});

ctx.addEventListener("error", (event) => {
  postEvent({ type: "LOG", level: "error", message: `worker:error ${event.message || event.type}` });
});

ctx.addEventListener("unhandledrejection", (event) => {
  postEvent({ type: "LOG", level: "error", message: `worker:unhandled ${String(event.reason)}` });
});

ctx.addEventListener("messageerror", (event) => {
  postEvent({ type: "LOG", level: "error", message: `worker:messageerror ${String(event.data)}` });
});

const DEFAULT_CORE_URL = "/js/ffmpeg-core.js";
const DEFAULT_WASM_URL = "/js/ffmpeg-core.wasm";
const DEFAULT_WORKER_URL: string | undefined = undefined;

let ffmpeg: any | null = null;
let isReady = false;
let activeJobId: string | undefined;
let activeStage: string | undefined;
let activeProgressOffset = 0;
let activeProgressScale = 1;
const loadedFiles = new Set<string>();
let logCapture: { active: boolean; lines: string[]; limit: number } | null = null;

const SIMPLE_MASTERING_FILTER_CHAIN =
  "highpass=f=20,acompressor=threshold=-18dB:ratio=2:attack=10:release=200:makeup=3,alimiter=limit=0.95";

ctx.onmessage = (event: MessageEvent<WorkerRequest>) => {
  const request = event.data;
  log("debug", "request:received", { type: request.type, jobId: getJobId(request) });
  handleRequest(request).catch((error) => {
    log("error", "request:failed", { type: request.type, error: (error as Error)?.message });
    postError("Worker request failed", request.requestId, getJobId(request), error);
  });
};

async function handleRequest(request: WorkerRequest): Promise<void> {
  // Direct console.log to bypass potential log forwarding issues
  console.log(`[slowverb-worker] request:${request.type} (${request.requestId})`);
  postEvent({ type: "LOG", level: "debug", message: `request:${request.type}` });
  switch (request.type) {
    case "INIT":
      return ensureFfmpeg(request.payload, request.requestId);
    case "LOAD_SOURCE":
      return runWithEngine(() => handleLoadSource(request), request.requestId);
    case "PROBE":
      return runWithEngine(() => handleProbe(request), request.requestId);
    case "RENDER_PREVIEW":
    case "RENDER_FULL":
      return runWithEngine(() => handleRender(request));
    case "WAVEFORM":
      return runWithEngine(() => handleWaveform(request));
    case "CANCEL":
      return handleCancel(request);
    case "PING":
      return handlePing(request);
    case "DECODE_PCM":
      return runWithEngine(() => handleDecodePCM(request), request.requestId);
    case "ENCODE_PCM":
      return runWithEngine(() => handleEncodePCM(request), request.requestId);
  }
}

async function handlePing(request: WorkerRequest & { type: "PING" }): Promise<void> {
  postEvent({ type: "LOG", level: "debug", message: `pong:${request.requestId}` });
  postResult(request.requestId, { pong: true });
}

async function runWithEngine(task: () => Promise<void>, requestId?: string): Promise<void> {
  console.log(`[slowverb-worker] runWithEngine:start (${requestId})`);
  await ensureFfmpeg(undefined, requestId);
  console.log(`[slowverb-worker] runWithEngine:ffmpeg-ready (${requestId})`);
  await task();
  console.log(`[slowverb-worker] runWithEngine:task-done (${requestId})`);
}

async function handleCancel(request: Extract<WorkerRequest, { type: "CANCEL" }>): Promise<void> {
  postEvent({
    type: "CANCELLED",
    requestId: request.requestId,
    jobId: request.jobId,
    reason: "Worker terminated",
  });
  log("warn", "cancel:terminate", { jobId: request.jobId });
  cleanupFiles(...loadedFiles);
  loadedFiles.clear();
  ctx.close();
}

async function ensureFfmpeg(payload?: InitPayload, requestId?: string): Promise<void> {
  console.log(`[slowverb-worker] ensureFfmpeg:check isReady=${isReady} ffmpeg=${!!ffmpeg} (${requestId})`);
  if (isReady && ffmpeg) {
    if (requestId) postEvent({ type: "READY", requestId });
    console.log(`[slowverb-worker] ensureFfmpeg:already-ready (${requestId})`);
    return;
  }

  postEvent({ type: "LOG", level: "info", message: "FFmpeg init: start" });
  postEvent({ type: "LOG", level: "info", message: "FFmpeg init: loading core" });
  ffmpeg = await createCore(payload);
  isReady = true;
  postEvent({ type: "LOG", level: "info", message: "FFmpeg init: ready" });
  postEvent({ type: "READY", requestId });
}

async function createCore(payload?: InitPayload): Promise<any> {
  const coreURL = payload?.coreURL ?? DEFAULT_CORE_URL;
  const wasmURL = payload?.wasmURL ?? DEFAULT_WASM_URL;
  const workerURL = payload?.workerURL ?? DEFAULT_WORKER_URL;

  await logAssetStatus("wasm", wasmURL);

  const mainScriptUrlOrBlob = `${coreURL}#${btoa(JSON.stringify({ wasmURL, workerURL }))}`;
  const core = await (createFFmpegCore as unknown as (options: Record<string, unknown>) => Promise<any>)({
    mainScriptUrlOrBlob,
  });

  core.setLogger(({ type, message }: { type: string; message: string }) => {
    postEvent({ type: "LOG", level: mapLogLevel(type), message });
    recordLog(message);
  });

  core.setProgress(({ progress }: { progress: number }) => {
    if (!activeJobId) return;
    const value = typeof progress === "number" ? progress : 0;
    const scaled = activeProgressOffset + value * activeProgressScale;
    postEvent({ type: "PROGRESS", jobId: activeJobId, value: scaled, stage: activeStage });
  });

  return core;
}

async function logAssetStatus(name: string, url: string): Promise<void> {
  try {
    const response = await fetch(url, {
      method: "GET",
      headers: { Range: "bytes=0-0" },
    });
    await response.body?.cancel();
    postEvent({ type: "LOG", level: "info", message: `FFmpeg init: ${name} ${response.status} (${url})` });
  } catch (error) {
    postEvent({
      type: "LOG",
      level: "warn",
      message: `FFmpeg init: ${name} check failed (${url}): ${String(error)}`,
    });
  }
}

async function handleLoadSource(request: Extract<WorkerRequest, { type: "LOAD_SOURCE" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const data = new Uint8Array(request.payload.data);
  ffmpeg.FS.writeFile(request.payload.fileId, data);
  loadedFiles.add(request.payload.fileId);

  postEvent({
    type: "LOG",
    level: "info",
    message: `load:ok (${request.payload.fileId}) size=${data.byteLength}`,
  });
  postResult(request.requestId, { fileId: request.payload.fileId });

  // Diagnostic: schedule heartbeat to confirm event loop is still alive after LOAD_SOURCE
  setTimeout(() => {
    postEvent({ type: "LOG", level: "debug", message: `load:heartbeat (${request.payload.fileId}) event-loop-alive` });
  }, 100);
}

async function handleProbe(request: Extract<WorkerRequest, { type: "PROBE" }>): Promise<void> {
  console.log(`[slowverb-worker] handleProbe:start`, request);
  if (!ffmpeg) throw new Error("FFmpeg not initialized");

  const fileId = request.payload.fileId;
  console.log(`[slowverb-worker] handleProbe:fileId=${fileId}`);

  console.log(`[slowverb-worker] handleProbe:about-to-postEvent-probe-start`);
  postEvent({ type: "LOG", level: "info", message: `probe:start (${fileId})` });
  console.log(`[slowverb-worker] handleProbe:postEvent-done`);

  console.log(`[slowverb-worker] handleProbe:about-to-ensureFileExists`);
  ensureFileExists(fileId);
  console.log(`[slowverb-worker] handleProbe:ensureFileExists-done`);

  postEvent({ type: "LOG", level: "debug", message: `probe:exists (${fileId})` });

  const warnTimeout = setTimeout(() => {
    postEvent({ type: "LOG", level: "warn", message: `probe:still-running (${fileId})` });
  }, 10_000);

  try {
    console.log(`[slowverb-worker] handleProbe:about-to-probeWithFfmpeg`);
    const metadata = await probeWithFfmpeg(fileId);
    console.log(`[slowverb-worker] handleProbe:probeWithFfmpeg-done`, metadata);
    postEvent({ type: "LOG", level: "info", message: `probe:ok (${fileId}) durationMs=${metadata.durationMs ?? "null"}` });
    postResult(request.requestId, metadata);
    console.log(`[slowverb-worker] handleProbe:result-posted`);
  } finally {
    clearTimeout(warnTimeout);
  }
}

async function handleRender(
  request: Extract<WorkerRequest, { type: "RENDER_PREVIEW" | "RENDER_FULL" }>
): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");

  const { payload, jobId, type } = request;
  const isPreview = type === "RENDER_PREVIEW";
  const shouldUsePhaseLimiter = isPhaseLimiterEnabled(payload);
  const shouldUseSoundTouch = isSoundTouchEnabled(payload);
  const shouldUseToneReverb = isToneReverbEnabled(payload);
  const shouldUsePcmPipeline = shouldUseSoundTouch || shouldUseToneReverb;
  const filesToCleanup = new Set<string>([payload.fileId]);

  activeJobId = jobId;
  try {
    if (!shouldUsePhaseLimiter && !shouldUsePcmPipeline) {
      const { args, outputFile } = buildRenderPlan(payload, jobId, isPreview);
      filesToCleanup.add(outputFile);
      log("info", "render:start", { jobId, fileId: payload.fileId, format: payload.format });
      try {
        withProgressStage("processing", 0, 1, () => ffmpeg.exec(...args));
      } catch (error) {
        const fallbackGraph = stripSimpleMasteringFromFilterGraph(payload.filterGraph);
        if (!fallbackGraph) throw error;

        log("warn", "render:retry-without-mastering", { jobId, fileId: payload.fileId });
        const fallbackPlan = buildRenderPlan({ ...payload, filterGraph: fallbackGraph }, jobId, isPreview);
        filesToCleanup.add(fallbackPlan.outputFile);
        withProgressStage("processing", 0, 1, () => ffmpeg.exec(...fallbackPlan.args));
      }
      const buffer = await readOutput(outputFile);
      log("info", "render:ok", { jobId, outputFile });
      postRenderResult(request, buffer);
      return;
    }

    if (shouldUsePhaseLimiter && !shouldUsePcmPipeline) {
      log("info", "render:start(phaselimiter)", { jobId, fileId: payload.fileId, format: payload.format });
      const result = await renderWithPhaseLimiter(payload, jobId, isPreview);
      filesToCleanup.add(result.outputFile);
      for (const temp of result.tempFiles) filesToCleanup.add(temp);
      log("info", "render:ok(phaselimiter)", { jobId, outputFile: result.outputFile });
      postRenderResult(request, result.buffer);
      return;
    }

    log("info", "render:start(pcm-pipeline)", {
      jobId,
      fileId: payload.fileId,
      format: payload.format,
      soundtouch: shouldUseSoundTouch,
      toneReverb: shouldUseToneReverb,
      phaselimiter: shouldUsePhaseLimiter,
    });

    try {
      const result = await renderWithPcmPipeline(payload, jobId, isPreview, {
        applyPhaseLimiter: shouldUsePhaseLimiter,
      });
      filesToCleanup.add(result.outputFile);
      for (const temp of result.tempFiles) filesToCleanup.add(temp);
      log("info", "render:ok(pcm-pipeline)", { jobId, outputFile: result.outputFile });
      postRenderResult(request, result.buffer);
      return;
    } catch (error) {
      if (!shouldUseSoundTouch) throw error;

      log("warn", "render:pcm-pipeline-failed:fallback-ffmpeg", {
        jobId,
        fileId: payload.fileId,
        error: (error as Error)?.message ?? String(error),
      });

      const fallback = buildFallbackRenderPayload(payload);
      if (shouldUsePhaseLimiter) {
        const result = await renderWithPhaseLimiter(fallback, jobId, isPreview);
        filesToCleanup.add(result.outputFile);
        for (const temp of result.tempFiles) filesToCleanup.add(temp);
        postRenderResult(request, result.buffer);
        return;
      }

      const { args, outputFile } = buildRenderPlan(fallback, jobId, isPreview);
      filesToCleanup.add(outputFile);
      withProgressStage("processing", 0, 1, () => ffmpeg.exec(...args));
      const buffer = await readOutput(outputFile);
      postRenderResult(request, buffer);
      return;
    }
  } finally {
    activeJobId = undefined;
    activeStage = undefined;
    activeProgressOffset = 0;
    activeProgressScale = 1;
    log("debug", "render:cleanup", { jobId });
    cleanupFiles(...filesToCleanup);
  }
}

function isPhaseLimiterEnabled(payload: RenderPayload): boolean {
  const mastering = payload.mastering;
  if (!mastering) return false;
  return mastering.enabled === true && (mastering.algorithm === "phaselimiter" || mastering.algorithm === "phaselimiter_pro");
}

function isSoundTouchEnabled(payload: RenderPayload): boolean {
  const spec = payload.dspSpec;
  const algorithm = spec?.quality?.timeStretch ?? "ffmpeg";
  if (algorithm !== "soundtouch") return false;
  const tempo = typeof spec?.tempo === "number" ? spec.tempo : 1.0;
  const pitch = typeof spec?.pitch === "number" ? spec.pitch : 0.0;
  return tempo !== 1.0 || pitch !== 0.0;
}

function isToneReverbEnabled(payload: RenderPayload): boolean {
  const spec = payload.dspSpec;
  const algorithm = spec?.quality?.reverb ?? "ffmpeg";
  return algorithm === "tone" && spec?.reverb != null;
}

function buildFallbackRenderPayload(payload: RenderPayload): RenderPayload {
  const spec = payload.dspSpec;
  if (!spec) return payload;

  const fallbackSpec = {
    ...spec,
    quality: { ...(spec.quality ?? {}), timeStretch: "ffmpeg" as const, reverb: "ffmpeg" as const },
  };

  return {
    ...payload,
    dspSpec: fallbackSpec,
    filterGraph: compileFilterChain(fallbackSpec),
    reverbIR: undefined,
    reverbIRSampleRate: undefined,
  };
}

function buildFallbackReverbRenderPayload(payload: RenderPayload): RenderPayload {
  const spec = payload.dspSpec;
  if (!spec) return payload;

  const fallbackSpec = {
    ...spec,
    quality: { ...(spec.quality ?? {}), reverb: "ffmpeg" as const },
  };

  return {
    ...payload,
    dspSpec: fallbackSpec,
    filterGraph: compileFilterChain(fallbackSpec),
    reverbIR: undefined,
    reverbIRSampleRate: undefined,
  };
}

function withProgressStage(stage: string, offset: number, scale: number, run: () => void): void {
  const prevStage = activeStage;
  const prevOffset = activeProgressOffset;
  const prevScale = activeProgressScale;

  activeStage = stage;
  activeProgressOffset = offset;
  activeProgressScale = scale;
  try {
    run();
  } finally {
    activeStage = prevStage;
    activeProgressOffset = prevOffset;
    activeProgressScale = prevScale;
  }
}

async function renderWithPhaseLimiter(
  payload: RenderPayload,
  jobId: string,
  isPreview: boolean
): Promise<{ buffer: ArrayBuffer; outputFile: string; tempFiles: string[] }> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");

  const sampleRate = 44100;
  const decodeFile = `${payload.fileId}-${jobId}-decode.f32`;
  const masteredFile = `${payload.fileId}-${jobId}-mastered.f32`;
  const outputFile = buildOutputName(payload.fileId, jobId, payload.format, isPreview);

  try {
    const decodeArgs = buildDecodePlan(payload, decodeFile, sampleRate, isPreview);
    postEvent({ type: "PROGRESS", jobId, value: 0, stage: "decoding" });
    withProgressStage("decoding", 0, 0.2, () => ffmpeg.exec(...decodeArgs));

    const { left, right } = readAndSplitF32Stereo(decodeFile);

    postEvent({ type: "PROGRESS", jobId, value: 0.2, stage: "mastering" });
    const algorithm = payload.mastering!.algorithm as string;
    const processed = await processWithPhaseLimiter(left, right, sampleRate, jobId, algorithm, payload.mastering);

    writeInterleavedF32Stereo(masteredFile, processed.left, processed.right);

    const encodeArgs = buildEncodePlan(masteredFile, outputFile, payload, sampleRate);
    postEvent({ type: "PROGRESS", jobId, value: 0.8, stage: "encoding" });
    withProgressStage("encoding", 0.8, 0.2, () => ffmpeg.exec(...encodeArgs));

    const buffer = await readOutput(outputFile);
    return { buffer, outputFile, tempFiles: [decodeFile, masteredFile] };
  } catch (error) {
    log("warn", "render:phaselimiter-failed", {
      jobId,
      fileId: payload.fileId,
      error: (error as Error)?.message ?? String(error),
    });

    // Fallback: render with simple mastering via FFmpeg filter chain.
    const filterGraph = appendSimpleMasteringToFilterGraph(payload.filterGraph);
    const fallbackPayload: RenderPayload = {
      ...payload,
      filterGraph,
      mastering: { enabled: true, algorithm: "simple" },
    };
    const plan = buildRenderPlan(fallbackPayload, jobId, isPreview);
    withProgressStage("processing", 0, 1, () => ffmpeg.exec(...plan.args));
    const buffer = await readOutput(plan.outputFile);
    return { buffer, outputFile: plan.outputFile, tempFiles: [decodeFile, masteredFile] };
  }
}

async function renderWithPcmPipeline(
  payload: RenderPayload,
  jobId: string,
  isPreview: boolean,
  options: { applyPhaseLimiter: boolean }
): Promise<{ buffer: ArrayBuffer; outputFile: string; tempFiles: string[] }> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");

  const sampleRate = 44100;
  const rawFile = `${payload.fileId}-${jobId}-raw.f32`;
  const stretchedFile = `${payload.fileId}-${jobId}-stretched.f32`;
  const effectsFile = `${payload.fileId}-${jobId}-effects.f32`;
  const masteredFile = `${payload.fileId}-${jobId}-mastered.f32`;
  const outputFile = buildOutputName(payload.fileId, jobId, payload.format, isPreview);

  const tempFiles: string[] = [rawFile];
  let currentPcmFile = rawFile;

  // 1) Decode to float PCM (no filter graph applied; we need raw samples for SoundTouch/Tone).
  const decodeArgs = buildRawDecodePlan(payload, rawFile, sampleRate, isPreview);
  postEvent({ type: "PROGRESS", jobId, value: 0, stage: "decoding" });
  withProgressStage("decoding", 0, 0.15, () => ffmpeg.exec(...decodeArgs));

  // 2) High-quality time stretch / pitch-shift with SoundTouchJS.
  if (isSoundTouchEnabled(payload)) {
    const { tempo, pitchSemitones } = resolveTimeStretchParams(payload);
    postEvent({ type: "PROGRESS", jobId, value: 0.15, stage: "time-stretch" });
    const stretched = applySoundTouch(rawFile, tempo, pitchSemitones, jobId);
    writeInterleavedF32(stretchedFile, stretched);
    tempFiles.push(stretchedFile);
    currentPcmFile = stretchedFile;
    postEvent({ type: "PROGRESS", jobId, value: 0.35, stage: "time-stretch" });
  }

  // 3) Apply remaining FFmpeg filter graph (eq/reverb/echo/lowpass/stereo/simple mastering), if any.
  if (isToneReverbEnabled(payload)) {
    if (!payload.dspSpec || !payload.dspSpec.reverb) {
      throw new Error("Tone reverb enabled but dspSpec.reverb missing");
    }
    if (!payload.reverbIR) {
      log("warn", "tone-reverb:missing-ir:fallback-ffmpeg", { jobId, fileId: payload.fileId });
      const fallback = buildFallbackReverbRenderPayload(payload);
      if (fallback.filterGraph && fallback.filterGraph !== "anull") {
        const filterArgs = buildPcmFilterPlan(currentPcmFile, effectsFile, fallback.filterGraph, sampleRate);
        postEvent({ type: "PROGRESS", jobId, value: 0.35, stage: "effects" });
        withProgressStage("effects", 0.35, 0.35, () => ffmpeg.exec(...filterArgs));
        tempFiles.push(effectsFile);
        currentPcmFile = effectsFile;
      }
    } else {
      const irFile = `${payload.fileId}-${jobId}-ir.f32`;
      ffmpeg.FS.writeFile(irFile, new Uint8Array(payload.reverbIR));
      tempFiles.push(irFile);

      const { pre, post } = compileFilterChainParts(payload.dspSpec);
      const mix = clampNumber(payload.dspSpec.reverb.mix, 0.0, 1.0);
      const dry = (1 - mix).toFixed(4);
      const wet = mix.toFixed(4);
      const irSampleRate = typeof payload.reverbIRSampleRate === "number" ? payload.reverbIRSampleRate : sampleRate;

      const args: string[] = [];
      args.push("-f", "f32le", "-ac", "2", "-ar", `${sampleRate}`, "-i", currentPcmFile);
      args.push("-f", "f32le", "-ac", "2", "-ar", `${irSampleRate}`, "-i", irFile);

      const chains: string[] = [];
      chains.push(`[0:a]${pre === "anull" ? "anull" : pre}[pre]`);
      chains.push(`[1:a]${irSampleRate === sampleRate ? "anull" : `aresample=${sampleRate}`}[ir]`);
      chains.push(`[pre][ir]afir=dry=${dry}:wet=${wet}[wet]`);
      chains.push(`[wet]${post === "anull" ? "anull" : post}[out]`);

      args.push("-filter_complex", chains.join(";"));
      args.push("-map", "[out]");
      args.push("-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", effectsFile);

      postEvent({ type: "PROGRESS", jobId, value: 0.35, stage: "effects" });
      withProgressStage("effects", 0.35, 0.35, () => ffmpeg.exec(...args));
      tempFiles.push(effectsFile);
      currentPcmFile = effectsFile;
    }
  } else if (payload.filterGraph && payload.filterGraph !== "anull") {
    const filterArgs = buildPcmFilterPlan(currentPcmFile, effectsFile, payload.filterGraph, sampleRate);
    postEvent({ type: "PROGRESS", jobId, value: 0.35, stage: "effects" });
    withProgressStage("effects", 0.35, 0.35, () => ffmpeg.exec(...filterArgs));
    tempFiles.push(effectsFile);
    currentPcmFile = effectsFile;
  }

  // 4) Optional PhaseLimiter mastering on PCM.
  if (options.applyPhaseLimiter) {
    const { left, right } = readAndSplitF32Stereo(currentPcmFile);

    postEvent({ type: "PROGRESS", jobId, value: 0.7, stage: "mastering" });
    const algorithm = payload.mastering!.algorithm as string;
    const processed = await processWithPhaseLimiter(left, right, sampleRate, jobId, algorithm, payload.mastering, {
      offset: 0.7,
      scale: 0.2,
    });
    writeInterleavedF32Stereo(masteredFile, processed.left, processed.right);
    tempFiles.push(masteredFile);
    currentPcmFile = masteredFile;
  }

  // 5) Encode from float PCM to target format.
  const encodeArgs = buildEncodePlan(currentPcmFile, outputFile, payload, sampleRate);
  postEvent({ type: "PROGRESS", jobId, value: 0.9, stage: "encoding" });
  withProgressStage("encoding", 0.9, 0.1, () => ffmpeg.exec(...encodeArgs));

  const buffer = await readOutput(outputFile);
  return { buffer, outputFile, tempFiles };
}

function buildDecodePlan(payload: RenderPayload, outputFile: string, sampleRate: number, isPreview: boolean): string[] {
  const args: string[] = [];
  addTrimArgs(args, payload, isPreview);
  args.push("-i", payload.fileId);
  if (payload.filterGraph && payload.filterGraph !== "anull") {
    args.push("-af", payload.filterGraph);
  }
  args.push("-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", outputFile);
  return args;
}

function buildRawDecodePlan(payload: RenderPayload, outputFile: string, sampleRate: number, isPreview: boolean): string[] {
  const args: string[] = [];
  addTrimArgs(args, payload, isPreview);
  args.push("-i", payload.fileId);
  args.push("-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", outputFile);
  return args;
}

function buildPcmFilterPlan(inputFile: string, outputFile: string, filterGraph: string, sampleRate: number): string[] {
  const args: string[] = [];
  args.push("-f", "f32le", "-ac", "2", "-ar", `${sampleRate}`, "-i", inputFile);
  if (filterGraph !== "anull") {
    args.push("-af", filterGraph);
  }
  args.push("-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", outputFile);
  return args;
}

function buildEncodePlan(inputFile: string, outputFile: string, payload: RenderPayload, sampleRate: number): string[] {
  const args: string[] = [];
  args.push("-f", "f32le", "-ac", "2", "-ar", `${sampleRate}`, "-i", inputFile);
  addCodecArgs(args, payload);
  args.push("-y", outputFile);
  return args;
}

function readAndSplitF32Stereo(path: string): { left: Float32Array; right: Float32Array } {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const bytes = ffmpeg.FS.readFile(path);
  if (!(bytes instanceof Uint8Array)) throw new Error("Expected binary PCM output from FFmpeg");

  const pcm = bytes.slice().buffer;
  const interleaved = new Float32Array(pcm);
  if (interleaved.length % 2 !== 0) throw new Error("Invalid stereo PCM length");

  const frames = interleaved.length / 2;
  const left = new Float32Array(frames);
  const right = new Float32Array(frames);
  for (let i = 0; i < frames; i++) {
    left[i] = interleaved[i * 2];
    right[i] = interleaved[i * 2 + 1];
  }

  return { left, right };
}

function writeInterleavedF32Stereo(path: string, left: Float32Array, right: Float32Array): void {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  if (left.length !== right.length) throw new Error("Channel length mismatch");

  const frames = left.length;
  const interleaved = new Float32Array(frames * 2);
  for (let i = 0; i < frames; i++) {
    interleaved[i * 2] = left[i];
    interleaved[i * 2 + 1] = right[i];
  }
  ffmpeg.FS.writeFile(path, new Uint8Array(interleaved.buffer));
}

function readInterleavedF32(path: string): Float32Array {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const bytes = ffmpeg.FS.readFile(path);
  if (!(bytes instanceof Uint8Array)) throw new Error("Expected binary PCM output from FFmpeg");
  const pcm = bytes.slice().buffer;
  const interleaved = new Float32Array(pcm);
  if (interleaved.length % 2 !== 0) throw new Error("Invalid stereo PCM length");
  return interleaved;
}

function writeInterleavedF32(path: string, interleaved: Float32Array): void {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const bytes = new Uint8Array(interleaved.buffer, interleaved.byteOffset, interleaved.byteLength);
  ffmpeg.FS.writeFile(path, bytes);
}

function resolveTimeStretchParams(payload: RenderPayload): { tempo: number; pitchSemitones: number } {
  const spec = payload.dspSpec;
  const tempo = typeof spec?.tempo === "number" ? spec.tempo : 1.0;
  const pitchSemitones = typeof spec?.pitch === "number" ? spec.pitch : 0.0;
  return {
    tempo: clampNumber(tempo, 0.5, 2.0),
    pitchSemitones: clampNumber(pitchSemitones, -12.0, 12.0),
  };
}

function applySoundTouch(inputFile: string, tempo: number, pitchSemitones: number, jobId: string): Float32Array {
  const input = readInterleavedF32(inputFile);
  const totalFrames = Math.floor(input.length / 2);

  const soundTouch = new SoundTouch();
  // Ensure the internal Stretch instance is configured for our sample rate.
  soundTouch.stretch?.setParameters?.(44100, 0, 0, 0);
  soundTouch.tempo = tempo;
  soundTouch.pitchSemitones = pitchSemitones;

  class InterleavedStereoSource {
    private position = 0;
    constructor(private readonly samples: Float32Array) {}
    extract(target: Float32Array, numFrames: number = 0, position: number = 0): number {
      this.position = position;
      const start = position * 2;
      const availableFrames = Math.max(0, Math.floor((this.samples.length - start) / 2));
      const frames = Math.max(0, Math.min(numFrames, availableFrames));
      if (frames > 0) {
        target.set(this.samples.subarray(start, start + frames * 2));
      }
      return frames;
    }
  }

  const filter = new SimpleFilter(new InterleavedStereoSource(input), soundTouch);
  const chunkFrames = 16384;
  const chunk = new Float32Array(chunkFrames * 2);
  const chunks: Float32Array[] = [];

  let lastEmit = -1;
  for (;;) {
    const frames = filter.extract(chunk, chunkFrames);
    if (frames === 0) break;
    chunks.push(chunk.slice(0, frames * 2));

    const sourceFrames = filter.sourcePosition ?? 0;
    const percent = totalFrames > 0 ? clamp01(sourceFrames / totalFrames) : 1;
    if (percent - lastEmit >= 0.05) {
      postEvent({ type: "PROGRESS", jobId, value: 0.15 + percent * 0.2, stage: "time-stretch" });
      lastEmit = percent;
    }
  }

  const totalSamples = chunks.reduce((sum, block) => sum + block.length, 0);
  const output = new Float32Array(totalSamples);
  let offset = 0;
  for (const block of chunks) {
    output.set(block, offset);
    offset += block.length;
  }
  return output;
}

function clampNumber(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

function appendSimpleMasteringToFilterGraph(filterGraph?: string): string {
  if (!filterGraph || filterGraph === "anull") return SIMPLE_MASTERING_FILTER_CHAIN;
  if (filterGraph.endsWith(SIMPLE_MASTERING_FILTER_CHAIN)) return filterGraph;
  return `${filterGraph},${SIMPLE_MASTERING_FILTER_CHAIN}`;
}

async function processWithPhaseLimiter(
  leftChannel: Float32Array,
  rightChannel: Float32Array,
  sampleRate: number,
  jobId: string,
  algorithm: string,
  mastering?: RenderPayload["mastering"],
  progressRange: { offset: number; scale: number } = { offset: 0.2, scale: 0.6 }
): Promise<{ left: Float32Array; right: Float32Array }> {
  return new Promise((resolve, reject) => {
    const isPro = algorithm === "phaselimiter_pro";
    const workerScript = isPro ? "/js/phase_limiter_pro_worker.js" : "/js/phase_limiter_worker.js";
    const masteringConfig = mastering ?? {};
    const config = isPro
      ? { mode: Math.round(masteringConfig.mode ?? 5) }
      : {
          targetLufs: typeof masteringConfig.targetLufs === "number" ? masteringConfig.targetLufs : -14.0,
          bassPreservation:
            typeof masteringConfig.bassPreservation === "number"
              ? masteringConfig.bassPreservation
              : 0.5,
        };
    const worker = new Worker(workerScript);

    const onMessage = (event: MessageEvent) => {
      const data = event.data ?? {};
      const type = data.type;
      if (type === "progress") {
        const percent = typeof data.percent === "number" ? data.percent : 0;
        const scaled = progressRange.offset + clamp01(percent) * progressRange.scale;
        postEvent({ type: "PROGRESS", jobId, value: scaled, stage: "mastering" });
        return;
      }
      if (type === "complete") {
        worker.removeEventListener("message", onMessage);
        worker.removeEventListener("error", onError);
        worker.terminate();

        const left = data.leftChannel;
        const right = data.rightChannel;
        if (!(left instanceof Float32Array) || !(right instanceof Float32Array)) {
          reject(new Error("Invalid PhaseLimiter worker result"));
          return;
        }
        resolve({ left, right });
        return;
      }
      if (type === "error") {
        worker.removeEventListener("message", onMessage);
        worker.removeEventListener("error", onError);
        worker.terminate();
        reject(new Error(data.error ?? "PhaseLimiter worker error"));
      }
    };

    const onError = (event: ErrorEvent) => {
      worker.removeEventListener("message", onMessage);
      worker.removeEventListener("error", onError);
      worker.terminate();
      reject(new Error(event.message || "PhaseLimiter worker crashed"));
    };

    worker.addEventListener("message", onMessage);
    worker.addEventListener("error", onError);

    try {
      worker.postMessage(
        {
          leftChannel,
          rightChannel,
          sampleRate,
          config,
        },
        [leftChannel.buffer, rightChannel.buffer]
      );
    } catch (error) {
      worker.removeEventListener("message", onMessage);
      worker.removeEventListener("error", onError);
      worker.terminate();
      reject(error);
    }
  });
}

function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
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

async function handleDecodePCM(request: Extract<WorkerRequest, { type: "DECODE_PCM" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const { fileId } = request.payload;
  const sampleRate = 44100;
  const tempFile = `${fileId}-decode.f32`;
  try {
    const args = ["-i", fileId, "-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", tempFile];
    await ffmpeg.exec(...args);
    const { left, right } = readAndSplitF32Stereo(tempFile);
    postResult(request.requestId, { type: "DECODE_PCM_RESULT", left, right, sampleRate } as any, [
      left.buffer,
      right.buffer,
    ]);
  } finally {
    cleanupFiles(tempFile);
  }
}

async function handleEncodePCM(request: Extract<WorkerRequest, { type: "ENCODE_PCM" }>): Promise<void> {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const { left, right, sampleRate, format } = request.payload;
  console.log(`[slowverb-worker] handleEncodePCM: start mapping ${left.length} samples`);
  const mid = Math.floor(left.length / 2);
  console.log(`[slowverb-worker] handleEncodePCM: sample check (mid) L=${left[mid]} R=${right[mid]}`);
  const inputFile = `raw-input.f32`;
  const outputFile = `output.${format}`;
  try {
    writeInterleavedF32Stereo(inputFile, left, right);
    const args = ["-f", "f32le", "-ac", "2", "-ar", `${sampleRate}`, "-i", inputFile];
    const dummyPayload: RenderPayload = {
      fileId: "dummy",
      format,
      bitrateKbps: request.payload.bitrateKbps,
    };
    addCodecArgs(args, dummyPayload);
    args.push("-y", outputFile);
    await ffmpeg.exec(...args);
    const buffer = await readOutput(outputFile);
    postResult(request.requestId, { fileId: "encoded", format, buffer }, [buffer]);
  } finally {
    cleanupFiles(inputFile, outputFile);
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

function stripSimpleMasteringFromFilterGraph(filterGraph?: string): string | null {
  if (!filterGraph || filterGraph === "anull") return null;
  if (!filterGraph.endsWith(SIMPLE_MASTERING_FILTER_CHAIN)) return null;

  const withoutSuffix = filterGraph.slice(0, -SIMPLE_MASTERING_FILTER_CHAIN.length);
  const withoutTrailingComma = withoutSuffix.endsWith(",")
    ? withoutSuffix.slice(0, -1)
    : withoutSuffix;

  return withoutTrailingComma.length > 0 ? withoutTrailingComma : "anull";
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
  const bytes = ffmpeg.FS.readFile(path);
  if (!(bytes instanceof Uint8Array)) throw new Error("Expected binary output from FFmpeg");
  const copy = bytes.slice();
  return copy.buffer;
}

function cleanupFiles(...paths: string[]): void {
  if (!ffmpeg) return;
  for (const path of paths) {
    if (!path) continue;
    try {
      ffmpeg.FS.unlink(path);
      loadedFiles.delete(path);
    } catch {
      // Best-effort cleanup
    }
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
  log("error", "worker:error", { jobId, message, cause: detail });
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
    postEvent({ type: "LOG", level: "debug", message: "probe:exec start" });
    // Use a tiny decode window to force ffmpeg to exit quickly while still printing stream metadata.
    const ret = ffmpeg.exec(
      "-hide_banner",
      "-t",
      "0.01",
      "-i",
      fileId,
      "-vn",
      "-sn",
      "-dn",
      "-f",
      "null",
      "-"
    );
    postEvent({ type: "LOG", level: "debug", message: `probe:exec done ret=${ret}` });
  } catch (error) {
    postEvent({
      type: "LOG",
      level: "debug",
      message: `probe:exec threw ${String((error as Error)?.message ?? error)}`,
    });
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
  ensureFileExists(fileId);
  const probe = await probeWithFfmpeg(fileId);
  const durationSec = probe.durationMs != null ? probe.durationMs / 1000 : undefined;
  const sampleRate = chooseWaveformSampleRate(points, durationSec);
  const outputFile = `waveform_${jobId}.f32`;

  try {
    ffmpeg.exec(
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
      outputFile
    );

    const bytes = ffmpeg.FS.readFile(outputFile);
    if (!(bytes instanceof Uint8Array)) throw new Error("Waveform output is not binary");
    const sampleCount = Math.floor(bytes.byteLength / 4);
    const floatSamples = new Float32Array(bytes.buffer, bytes.byteOffset, sampleCount);
    const peaks = computePeaks(floatSamples, points);
    normalizeInPlace(peaks);
    return { fileId, samples: peaks };
  } finally {
    cleanupFiles(fileId, outputFile);
  }
}

function ensureFileExists(path: string): void {
  if (!ffmpeg) throw new Error("FFmpeg not initialized");
  const analyzed = ffmpeg.FS.analyzePath(path);
  if (!analyzed?.exists) {
    throw new Error(`FFmpeg FS missing input: ${path}`);
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
