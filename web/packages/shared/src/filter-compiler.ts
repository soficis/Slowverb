import type { DspSpec, EchoSpec, MasteringSpec, ReverbSpec } from "./dsp.js";
import { DSP_LIMITS } from "./dsp.js";

type Limits = { readonly min: number; readonly max: number };
type NormalizedReverb = Readonly<Required<ReverbSpec>>;
type NormalizedEcho = Readonly<EchoSpec>;

const SIMPLE_MASTERING_FILTER_CHAIN =
  "highpass=f=20,acompressor=threshold=-18dB:ratio=2:attack=10:release=200:makeup=1,alimiter=limit=0.95";

export function compileFilterChain(spec: DspSpec): string {
  const filters: string[] = [];

  const timeStretchAlgorithm = spec.quality?.timeStretch ?? "ffmpeg";
  if (timeStretchAlgorithm !== "soundtouch") {
    appendTempo(filters, spec.tempo);
    appendPitch(filters, spec.pitch);
  }
  appendEqWarmth(filters, spec.eqWarmth);
  const reverbAlgorithm = spec.quality?.reverb ?? "ffmpeg";
  if (reverbAlgorithm !== "tone") {
    appendReverb(filters, spec.reverb);
  }
  appendEcho(filters, spec.echo);
  appendLowpass(filters, spec.lowPassCutoffHz, spec.hfDamping);
  appendStereoWidth(filters, spec.stereoWidth);
  appendMastering(filters, spec.mastering);

  return filters.length > 0 ? filters.join(",") : "anull";
}

export function compileFilterChainParts(spec: DspSpec): { pre: string; post: string } {
  const pre: string[] = [];
  const post: string[] = [];

  const timeStretchAlgorithm = spec.quality?.timeStretch ?? "ffmpeg";
  if (timeStretchAlgorithm !== "soundtouch") {
    appendTempo(pre, spec.tempo);
    appendPitch(pre, spec.pitch);
  }
  appendEqWarmth(pre, spec.eqWarmth);

  // NOTE: Reverb is intentionally not included here. The caller can insert a
  // high-quality reverb stage between `pre` and `post` (e.g., Tone-generated IR).

  appendEcho(post, spec.echo);
  appendLowpass(post, spec.lowPassCutoffHz, spec.hfDamping);
  appendStereoWidth(post, spec.stereoWidth);
  appendMastering(post, spec.mastering);

  return {
    pre: pre.length > 0 ? pre.join(",") : "anull",
    post: post.length > 0 ? post.join(",") : "anull",
  };
}

function appendTempo(filters: string[], tempo?: number): void {
  if (tempo === undefined || tempo === 1.0) return;
  filters.push(buildTempoFilter(clamp(tempo, DSP_LIMITS.tempo)));
}

function appendPitch(filters: string[], pitch?: number): void {
  if (pitch === undefined || pitch === 0.0) return;
  filters.push(buildPitchFilter(clamp(pitch, DSP_LIMITS.pitch)));
}

function appendEqWarmth(filters: string[], warmth?: number): void {
  if (warmth === undefined || warmth <= 0) return;
  filters.push(buildEqWarmthFilter(clamp(warmth, DSP_LIMITS.eqWarmth)));
}

function appendReverb(filters: string[], reverb?: ReverbSpec): void {
  if (!reverb) return;
  filters.push(buildReverbFilter(normalizeReverb(reverb)));
}

function appendEcho(filters: string[], echo?: EchoSpec): void {
  if (!echo) return;
  filters.push(buildEchoFilter(normalizeEcho(echo)));
}

function appendLowpass(filters: string[], cutoffHz?: number, hfDamping?: number): void {
  const lowpass = buildLowpassFilter(cutoffHz, hfDamping);
  if (!lowpass) return;
  filters.push(lowpass);
}

function appendStereoWidth(filters: string[], width?: number): void {
  if (width === undefined || width === 1.0) return;
  filters.push(buildStereoFilter(clamp(width, DSP_LIMITS.stereoWidth)));
}

function appendMastering(filters: string[], mastering?: MasteringSpec): void {
  if (!isMasteringEnabled(mastering)) {
    // When mastering is disabled, apply a simple limiter to ensure
    // audio is at a reasonable volume level (prevents inaudible output).
    filters.push(buildNormalizationFilter());
    return;
  }

  const algorithm = mastering?.algorithm ?? "simple";
  if (algorithm !== "simple") return;

  filters.push(buildSimpleMasteringFilterChain());
}

function isMasteringEnabled(mastering?: MasteringSpec): boolean {
  return mastering?.enabled === true;
}

function buildSimpleMasteringFilterChain(): string {
  return SIMPLE_MASTERING_FILTER_CHAIN;
}

// When mastering is off, apply moderate volume boost + limiter to compensate for signal chain
function buildNormalizationFilter(): string {
  // 6dB boost + limiter
  return "volume=6dB,alimiter=limit=0.95:level_in=1:level_out=1";
}


function buildTempoFilter(tempo: number): string {
  if (tempo >= 0.5 && tempo <= 2.0) {
    return `atempo=${tempo.toFixed(4)}`;
  }

  const filters: string[] = [];
  let remaining = tempo;

  while (remaining < 0.5) {
    filters.push("atempo=0.5");
    remaining /= 0.5;
  }
  while (remaining > 2.0) {
    filters.push("atempo=2.0");
    remaining /= 2.0;
  }

  filters.push(`atempo=${remaining.toFixed(4)}`);
  return filters.join(",");
}

function buildPitchFilter(semitones: number): string {
  const rate = Math.pow(2, semitones / 12);
  return `asetrate=44100*${rate.toFixed(4)},aresample=44100:filter_size=64:phase_shift=10`;
}

function buildEqWarmthFilter(warmth: number): string {
  const gain = (warmth * 6).toFixed(1);
  return `equalizer=f=300:t=h:width=200:g=${gain}`;
}

function buildReverbFilter(reverb: NormalizedReverb): string {
  const d1 = reverb.preDelayMs;
  const scale = 1 + reverb.roomScale;
  const d2 = Math.round(d1 * (1 + 0.35 * scale));
  const d3 = Math.round(d1 * (1 + 0.7 * scale));
  const d4 = Math.round(d1 * (1.4 + 0.6 * scale));
  const d5 = Math.round(d1 * (1.9 + 0.8 * scale));

  const decay = reverb.decay;
  const mix = reverb.mix;

  return `aecho=0.8:${mix.toFixed(2)}:${d1}|${d2}|${d3}|${d4}|${d5}:${(decay * 0.8).toFixed(2)}|${(decay * 0.6).toFixed(2)}|${(decay * 0.4).toFixed(2)}|${(decay * 0.25).toFixed(2)}|${(decay * 0.1).toFixed(2)}`;
}

function buildEchoFilter(echo: NormalizedEcho): string {
  // Reduced mix to 0.2 and feedback to 0.6 to fix "echo-y" percussion
  return `aecho=0.8:0.2:${echo.delayMs}:0.6`;
}

function buildLowpassFilter(cutoffHz?: number, hfDamping?: number): string | null {
  if (cutoffHz !== undefined) {
    const clamped = clamp(cutoffHz, DSP_LIMITS.lowPassCutoffHz);
    return `lowpass=f=${clamped}`;
  }
  if (hfDamping !== undefined && hfDamping > 0) {
    const clamped = clamp(hfDamping, DSP_LIMITS.hfDamping);
    const cutoff = Math.round(20000 - clamped * 18000);
    return `lowpass=f=${cutoff}`;
  }
  return null;
}

function buildStereoFilter(width: number): string {
  if (width < 1.0) {
    return `stereotools=mlev=${width.toFixed(2)}`;
  }

  const m = (width - 1) * 2.5;
  return `extrastereo=m=${m.toFixed(2)}`;
}

function normalizeReverb(reverb: ReverbSpec): NormalizedReverb {
  return {
    decay: clamp(reverb.decay, DSP_LIMITS.reverb.decay),
    preDelayMs: clamp(reverb.preDelayMs, DSP_LIMITS.reverb.preDelayMs),
    roomScale: clamp(
      reverb.roomScale ?? DSP_LIMITS.reverb.roomScale.default,
      DSP_LIMITS.reverb.roomScale
    ),
    mix: clamp(reverb.mix, DSP_LIMITS.reverb.mix),
  };
}

function normalizeEcho(echo: EchoSpec): NormalizedEcho {
  return {
    delayMs: clamp(echo.delayMs, DSP_LIMITS.echo.delayMs),
    feedback: clamp(echo.feedback, DSP_LIMITS.echo.feedback),
  };
}

function clamp(value: number, limits: Limits): number {
  if (value < limits.min) return limits.min;
  if (value > limits.max) return limits.max;
  return value;
}
