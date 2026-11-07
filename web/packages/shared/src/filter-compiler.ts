import type { DspSpec, EchoSpec, MasteringSpec, PhaserSpec, ReverbSpec } from "./dsp.js";
import { DSP_LIMITS } from "./dsp.js";

const DEFAULT_SAMPLE_RATE = 44100;

type Limits = { readonly min: number; readonly max: number };
type NormalizedReverb = Readonly<Required<Omit<ReverbSpec, "ir">>>;
type NormalizedEcho = Readonly<EchoSpec>;

const SIMPLE_MASTERING_FILTER_CHAIN =
  "highpass=f=20,acompressor=threshold=-18dB:ratio=2:attack=10:release=200:makeup=1,volume=4dB,alimiter=limit=0.95:level=disabled";

export function compileFilterChain(spec: DspSpec): string {
  const filters: string[] = [];

  appendTimeStretch(filters, spec);
  appendEqWarmth(filters, spec.eqWarmth);
  const reverbAlgorithm = spec.quality?.reverb ?? "ffmpeg";
  if (reverbAlgorithm === "ffmpeg") {
    appendReverb(filters, spec.reverb);
  }
  appendEcho(filters, spec.echo);
  appendPhaser(filters, spec.phaser);
  appendBass(filters, spec.bassGain);
  appendDynaudnorm(filters, spec.dynaudnorm);
  appendLowpass(filters, spec.lowPassCutoffHz, spec.hfDamping);
  appendStereoWidth(filters, spec.stereoWidth);
  appendMastering(filters, spec.mastering);

  return filters.length > 0 ? filters.join(",") : "anull";
}

export function compileFilterChainParts(spec: DspSpec): { pre: string; post: string } {
  const pre: string[] = [];
  const post: string[] = [];

  appendTimeStretch(pre, spec);
  appendEqWarmth(pre, spec.eqWarmth);

  // NOTE: Reverb is intentionally not included here. The caller can insert a
  // high-quality reverb stage between `pre` and `post` (e.g., Tone-generated IR).

  appendEcho(post, spec.echo);
  appendPhaser(post, spec.phaser);
  appendBass(post, spec.bassGain);
  appendDynaudnorm(post, spec.dynaudnorm);
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

// FFmpeg time-stretch (SoundTouch runs as a separate PCM stage). Any pitch change goes through the
// asetrate+atempo builder so tempo stays exactly as requested; a bare asetrate pitch shift also
// changed speed (tempo 0.86 + pitch -2.61 rendered at 0.74x). coupledMode without a pitch keeps
// SoX `speed` behaviour (pitch follows tempo).
function appendTimeStretch(filters: string[], spec: DspSpec): void {
  if ((spec.quality?.timeStretch ?? "ffmpeg") === "soundtouch") return;
  const pitch = spec.pitch;
  const hasPitch = typeof pitch === "number" && Number.isFinite(pitch) && pitch !== 0;
  if (spec.coupledMode || hasPitch) {
    filters.push(buildCoupledSpeedFilter(spec.tempo, pitch));
    return;
  }
  appendTempo(filters, spec.tempo);
}

function appendEqWarmth(filters: string[], warmth?: number): void {
  if (warmth === undefined || warmth <= 0) return;
  filters.push(buildEqWarmthFilter(clamp(warmth, DSP_LIMITS.eqWarmth)));
}

function appendReverb(filters: string[], reverb?: ReverbSpec): void {
  if (!reverb) return;
  if (!(reverb.mix > 0)) return;
  filters.push(buildReverbFilter(normalizeReverb(reverb)));
}

function appendEcho(filters: string[], echo?: EchoSpec): void {
  if (!echo) return;
  if (!(echo.delayMs > 0) || !(echo.feedback > 0)) return;
  if (!Number.isFinite(echo.delayMs) || !Number.isFinite(echo.feedback)) return;
  filters.push(buildEchoFilter(normalizeEcho(echo)));
}

function appendPhaser(filters: string[], phaser?: PhaserSpec): void {
  if (!phaser) return;
  filters.push(buildPhaserFilter(phaser));
}

function appendBass(filters: string[], bassGain?: number): void {
  if (typeof bassGain !== "number" || !Number.isFinite(bassGain) || bassGain === 0) return;
  filters.push(buildBassFilter(Math.max(-20, Math.min(20, bassGain))));
}

function appendDynaudnorm(filters: string[], enabled?: boolean): void {
  if (!enabled) return;
  filters.push(buildDynaudnormFilter());
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

// When mastering is off, apply a small boost + limiter. level=disabled stops alimiter's auto-level from
// pushing peaks to exactly 0 dBFS (clips after lossy encode). 3 dB keeps most presets within ~1 dB of
// input RMS now that reverb/echo no longer attenuate (measured on the bundled FFmpeg 5.1 core).
function buildNormalizationFilter(): string {
  return "volume=3dB,alimiter=limit=0.95:level=disabled";
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

function buildPhaserFilter(phaser: PhaserSpec): string {
  const num = (v: unknown, min: number, max: number, def: number): number =>
    typeof v === "number" && Number.isFinite(v) ? Math.min(max, Math.max(min, v)) : def;
  const type = phaser.type === "t" ? "t" : "s";
  return `aphaser=in_gain=0.9:out_gain=0.85:delay=${num(phaser.delayMs, 0, 5, 3)}:decay=${num(phaser.decay, 0, 0.99, 0.4)}:speed=${num(phaser.speedHz, 0.1, 2, 0.5)}:type=${type}`;
}

function buildBassFilter(gain: number): string {
  // Low-shelf EQ at 100Hz (approximation of SoX bass)
  return `bass=g=${gain.toFixed(1)}:f=100:width_type=q:width=0.5`;
}

function buildDynaudnormFilter(): string {
  return `dynaudnorm=framelen=150:gausssize=15`;
}

function buildCoupledSpeedFilter(rawTempo?: number, pitch?: number): string {
  // asetrate changes BOTH speed and pitch (like SoX `speed`); a residual atempo
  // restores the requested tempo when pitch is specified independently.
  const tempo =
    typeof rawTempo === "number" && Number.isFinite(rawTempo) ? clamp(rawTempo, DSP_LIMITS.tempo) : 1;
  const rate =
    typeof pitch === "number" && Number.isFinite(pitch)
      ? Math.pow(2, clamp(pitch, DSP_LIMITS.pitch) / 12)
      : tempo;
  let filter = `aresample=${DEFAULT_SAMPLE_RATE},asetrate=${DEFAULT_SAMPLE_RATE}*${rate.toFixed(4)},aresample=${DEFAULT_SAMPLE_RATE}:filter_size=64:phase_shift=10`;
  const residual = tempo / rate;
  if (Math.abs(residual - 1) > 1e-4) filter += `,${buildTempoFilter(residual)}`;
  return filter;
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

  // Dry stays at unity (in/out gain 1); mix scales only the wet taps.
  const taps = [0.8, 0.6, 0.4, 0.25, 0.1].map((k) => (decay * k * mix).toFixed(5)).join("|");
  return `aecho=1:1:${d1}|${d2}|${d3}|${d4}|${d5}:${taps}`;
}

// Dry stays at unity; only the single echo tap is scaled. The old chain used a fixed tap of 0.6 and an
// out_gain of 0.2 (-14 dB on everything). The tap now follows the spec: feedback * 0.5 (feedback 0.4 -> 0.2).
const ECHO_TAP_PER_FEEDBACK = 0.5;

function buildEchoFilter(echo: NormalizedEcho): string {
  const tap = Math.max(0.0001, Math.min(1, echo.feedback * ECHO_TAP_PER_FEEDBACK));
  return `aecho=1:1:${echo.delayMs}:${tap.toFixed(4)}`;
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
    hfDamping: clamp(
      reverb.hfDamping ?? DSP_LIMITS.hfDamping.default,
      DSP_LIMITS.hfDamping
    ),
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
