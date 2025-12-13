export type TempoFactor = number;
export type PitchSemitones = number;
export type NormalizedUnit = number;

export interface ReverbSpec {
  readonly decay: NormalizedUnit;
  readonly preDelayMs: number;
  readonly mix: NormalizedUnit;
}

export interface EchoSpec {
  readonly delayMs: number;
  readonly feedback: NormalizedUnit;
}

export interface DspSpec {
  readonly specVersion: "1.0.0";
  readonly tempo?: TempoFactor;
  readonly pitch?: PitchSemitones;
  readonly reverb?: ReverbSpec;
  readonly echo?: EchoSpec;
  readonly lowPassCutoffHz?: number;
  readonly normalize?: boolean;
}

export const DSP_SPEC_VERSION = "1.0.0" as const;
