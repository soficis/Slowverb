import { DSP_LIMITS } from "./dsp.js";
import type { DspSpec, EchoSpec, ReverbSpec } from "./dsp.js";

type NormalizedReverb = {
  readonly decay: number;
  readonly preDelayMs: number;
  readonly roomScale: number;
  readonly mix: number;
};

type NormalizedEcho = {
  readonly delayMs: number;
  readonly feedback: number;
};

type NormalizedSpec = {
  readonly tempo: number;
  readonly pitch: number;
  readonly eqWarmth: number;
  readonly lowPassCutoffHz?: number;
  readonly hfDamping: number;
  readonly stereoWidth: number;
  readonly normalize: boolean;
  readonly reverb?: NormalizedReverb;
  readonly echo?: NormalizedEcho;
};

export function compileFilterChain(spec: DspSpec): string {
  const normalized = normalizeSpec(spec);
  const filters = [
    buildTempoFilter(normalized.tempo),
    buildPitchFilter(normalized.pitch),
    buildEqWarmthFilter(normalized.eqWarmth),
    buildReverbFilter(normalized.reverb),
    buildEchoFilter(normalized.echo),
    buildLowPassOrDampingFilter(normalized.lowPassCutoffHz, normalized.hfDamping),
    buildStereoWidthFilter(normalized.stereoWidth),
    normalized.normalize ? buildLoudnessNormalizationFilter() : undefined,
  ].filter((value): value is string => Boolean(value));

  return filters.length > 0 ? filters.join(",") : "anull";
}

function normalizeSpec(spec: DspSpec): NormalizedSpec {
  return {
    tempo: clamp(spec.tempo ?? DSP_LIMITS.tempo.default, DSP_LIMITS.tempo.min, DSP_LIMITS.tempo.max),
    pitch: clamp(spec.pitch ?? DSP_LIMITS.pitch.default, DSP_LIMITS.pitch.min, DSP_LIMITS.pitch.max),
    eqWarmth: clamp(
      spec.eqWarmth ?? DSP_LIMITS.eqWarmth.default,
      DSP_LIMITS.eqWarmth.min,
      DSP_LIMITS.eqWarmth.max,
    ),
    lowPassCutoffHz: spec.lowPassCutoffHz !== undefined
      ? clamp(spec.lowPassCutoffHz, DSP_LIMITS.lowPassCutoffHz.min, DSP_LIMITS.lowPassCutoffHz.max)
      : undefined,
    hfDamping: clamp(
      spec.hfDamping ?? DSP_LIMITS.hfDamping.default,
      DSP_LIMITS.hfDamping.min,
      DSP_LIMITS.hfDamping.max,
    ),
    stereoWidth: clamp(
      spec.stereoWidth ?? DSP_LIMITS.stereoWidth.default,
      DSP_LIMITS.stereoWidth.min,
      DSP_LIMITS.stereoWidth.max,
    ),
    normalize: spec.normalize ?? false,
    reverb: spec.reverb ? normalizeReverb(spec.reverb) : undefined,
    echo: spec.echo ? normalizeEcho(spec.echo) : undefined,
  };
}

function normalizeReverb(reverb: ReverbSpec): NormalizedReverb {
  return {
    decay: clamp(reverb.decay, DSP_LIMITS.reverb.decay.min, DSP_LIMITS.reverb.decay.max),
    preDelayMs: clamp(
      reverb.preDelayMs,
      DSP_LIMITS.reverb.preDelayMs.min,
      DSP_LIMITS.reverb.preDelayMs.max,
    ),
    roomScale: clamp(
      reverb.roomScale ?? DSP_LIMITS.reverb.roomScale.default,
      DSP_LIMITS.reverb.roomScale.min,
      DSP_LIMITS.reverb.roomScale.max,
    ),
    mix: clamp(reverb.mix, DSP_LIMITS.reverb.mix.min, DSP_LIMITS.reverb.mix.max),
  };
}

function normalizeEcho(echo: EchoSpec): NormalizedEcho {
  return {
    delayMs: clamp(echo.delayMs, DSP_LIMITS.echo.delayMs.min, DSP_LIMITS.echo.delayMs.max),
    feedback: clamp(echo.feedback, DSP_LIMITS.echo.feedback.min, DSP_LIMITS.echo.feedback.max),
  };
}

function buildTempoFilter(tempo: number): string | undefined {
  if (tempo === 1.0) return undefined;

  const stages: string[] = [];
  let remaining = tempo;

  while (remaining < 0.5 || remaining > 2.0) {
    if (remaining < 0.5) {
      stages.push("atempo=0.5");
      remaining /= 0.5;
    } else {
      stages.push("atempo=2.0");
      remaining /= 2.0;
    }
  }

  stages.push(`atempo=${remaining.toFixed(4)}`);
  return stages.join(",");
}

function buildPitchFilter(semitones: number): string | undefined {
  if (semitones === 0.0) return undefined;

  const rate = Math.pow(2, semitones / 12);
  return `asetrate=44100*${rate.toFixed(4)},aresample=44100`;
}

function buildEqWarmthFilter(eqWarmth: number): string | undefined {
  if (eqWarmth <= 0) return undefined;

  const gain = (eqWarmth * 6).toFixed(1);
  return `equalizer=f=300:t=h:width=200:g=${gain}`;
}

function buildReverbFilter(reverb?: NormalizedReverb): string | undefined {
  if (!reverb || reverb.mix <= 0 || reverb.decay <= 0) return undefined;

  const delay1 = Math.round(reverb.preDelayMs);
  const delay2 = Math.round(delay1 * (1 + reverb.roomScale * 0.5));
  const delay3 = Math.round(delay1 * (1 + reverb.roomScale));

  const decay1 = (reverb.decay * 0.9 * reverb.mix).toFixed(2);
  const decay2 = (reverb.decay * 0.7 * reverb.mix).toFixed(2);
  const decay3 = (reverb.decay * 0.4 * reverb.mix).toFixed(2);

  return `aecho=0.8:0.88:${delay1}|${delay2}|${delay3}:${decay1}|${decay2}|${decay3}`;
}

function buildEchoFilter(echo?: NormalizedEcho): string | undefined {
  if (!echo || echo.feedback <= 0) return undefined;

  const delay = Math.round(echo.delayMs);
  const decay = echo.feedback.toFixed(2);
  return `aecho=0.8:0.9:${delay}:${decay}`;
}

function buildLowPassOrDampingFilter(
  cutoffHz: number | undefined,
  hfDamping: number,
): string | undefined {
  if (cutoffHz !== undefined) {
    return buildLowPassFilter(cutoffHz);
  }

  if (hfDamping <= 0) return undefined;

  return buildLowPassFilter(buildHfDampingCutoff(hfDamping));
}

function buildLowPassFilter(cutoffHz: number): string {
  const cutoff = Math.round(cutoffHz);
  return `lowpass=f=${cutoff}`;
}

function buildHfDampingCutoff(hfDamping: number): number {
  return Math.round(20000 - hfDamping * 18000);
}

function buildStereoWidthFilter(width: number): string | undefined {
  if (width === 1.0) return undefined;

  if (width < 1.0) {
    const mix = (1.0 - width).toFixed(2);
    return `stereotools=mlev=${mix}`;
  }

  const enhance = ((width - 1.0) * 2 + 1).toFixed(2);
  return `extrastereo=m=${enhance}`;
}

function buildLoudnessNormalizationFilter(): string {
  return "loudnorm=I=-14:LRA=11:TP=-1.5";
}

function clamp(value: number, min: number, max: number): number {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
