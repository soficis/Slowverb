export type TempoFactor = number;
export type PitchSemitones = number;
export type NormalizedUnit = number;
export type SpecVersion = "1.0.0";

export type MasteringAlgorithm = "simple" | "phaselimiter" | "phaselimiter_pro";

export interface MasteringSpec {
  readonly enabled?: boolean;
  readonly algorithm?: MasteringAlgorithm;
}

export interface ReverbSpec {
  readonly decay: NormalizedUnit;
  readonly preDelayMs: number;
  readonly roomScale?: NormalizedUnit;
  readonly mix: NormalizedUnit;
}

export interface EchoSpec {
  readonly delayMs: number;
  readonly feedback: NormalizedUnit;
}

export interface DspSpec {
  readonly specVersion: SpecVersion;
  readonly tempo?: TempoFactor;
  readonly pitch?: PitchSemitones;
  readonly reverb?: ReverbSpec;
  readonly echo?: EchoSpec;
  readonly lowPassCutoffHz?: number;
  readonly eqWarmth?: NormalizedUnit;
  readonly hfDamping?: NormalizedUnit;
  readonly stereoWidth?: number;
  readonly mastering?: MasteringSpec;
  readonly normalize?: boolean;
}

export const DSP_SPEC_VERSION: SpecVersion = "1.0.0";

export const DSP_LIMITS = {
  tempo: { min: 0.5, max: 1.5, default: 1.0 },
  pitch: { min: -12.0, max: 12.0, default: 0.0 },
  reverb: {
    decay: { min: 0.0, max: 0.99, default: 0.4 },
    preDelayMs: { min: 20, max: 500, default: 60 },
    roomScale: { min: 0.0, max: 1.0, default: 0.7 },
    mix: { min: 0.0, max: 1.0, default: 0.3 },
  },
  echo: {
    delayMs: { min: 50, max: 1000, default: 300 },
    feedback: { min: 0.0, max: 0.9, default: 0.4 },
  },
  lowPassCutoffHz: { min: 200, max: 20000, default: 20000 },
  eqWarmth: { min: 0.0, max: 1.0, default: 0.0 },
  hfDamping: { min: 0.0, max: 1.0, default: 0.0 },
  stereoWidth: { min: 0.5, max: 2.0, default: 1.0 },
} as const;

export const PRESET_ORDER = [
  "SLOWED_REVERB",
  "VAPORWAVE_CHILL",
  "NIGHTCORE",
  "ECHO_SLOW",
  "LOFI",
  "AMBIENT",
  "DEEP_BASS",
  "CRYSTAL_CLEAR",
  "UNDERWATER",
  "SYNTHWAVE",
  "SLOW_MOTION",
  "MANUAL",
] as const;

export type PresetId = (typeof PRESET_ORDER)[number];

export const PRESETS: Record<PresetId, DspSpec> = {
  SLOWED_REVERB: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 0.95,
    pitch: -2.0,
    reverb: {
      decay: 0.7,
      preDelayMs: 60,
      roomScale: 0.7,
      mix: 0.3,
    },
    echo: {
      delayMs: 200,
      feedback: 0.2,
    },
    eqWarmth: 0.4,
  },
  VAPORWAVE_CHILL: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 0.78,
    pitch: -3.0,
    lowPassCutoffHz: 2800,
    reverb: {
      decay: 0.8,
      preDelayMs: 100,
      roomScale: 0.8,
      mix: 0.4,
    },
    echo: {
      delayMs: 400,
      feedback: 0.4,
    },
    eqWarmth: 0.7,
  },
  NIGHTCORE: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 1.25,
    pitch: 4.0,
    reverb: {
      decay: 0.3,
      preDelayMs: 30,
      roomScale: 0.5,
      mix: 0.1,
    },
    echo: {
      delayMs: 100,
      feedback: 0.1,
    },
    eqWarmth: 0.2,
  },
  ECHO_SLOW: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 0.65,
    pitch: -4.0,
    reverb: {
      decay: 0.6,
      preDelayMs: 80,
      roomScale: 0.7,
      mix: 0.25,
    },
    echo: {
      delayMs: 500,
      feedback: 0.8,
    },
    eqWarmth: 0.5,
  },
  LOFI: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 0.92,
    pitch: -1.0,
    reverb: {
      decay: 0.5,
      preDelayMs: 50,
      roomScale: 0.6,
      mix: 0.2,
    },
    echo: {
      delayMs: 300,
      feedback: 0.3,
    },
    eqWarmth: 0.8,
    hfDamping: 0.3,
  },
  AMBIENT: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 0.7,
    pitch: -2.5,
    reverb: {
      decay: 0.9,
      preDelayMs: 120,
      roomScale: 0.9,
      mix: 0.5,
    },
    echo: {
      delayMs: 600,
      feedback: 0.6,
    },
    eqWarmth: 0.3,
    stereoWidth: 1.5,
  },
  DEEP_BASS: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 0.8,
    pitch: -5.0,
    reverb: {
      decay: 0.4,
      preDelayMs: 40,
      roomScale: 0.5,
      mix: 0.15,
    },
    echo: {
      delayMs: 200,
      feedback: 0.2,
    },
    eqWarmth: 0.9,
  },
  CRYSTAL_CLEAR: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 1.0,
    pitch: 2.0,
    reverb: {
      decay: 0.2,
      preDelayMs: 20,
      roomScale: 0.3,
      mix: 0.1,
    },
    echo: {
      delayMs: 100,
      feedback: 0.1,
    },
    eqWarmth: 0.1,
  },
  UNDERWATER: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 0.72,
    pitch: -3.5,
    lowPassCutoffHz: 1500,
    reverb: {
      decay: 0.85,
      preDelayMs: 100,
      roomScale: 0.8,
      mix: 0.45,
    },
    echo: {
      delayMs: 500,
      feedback: 0.5,
    },
    eqWarmth: 0.6,
    hfDamping: 0.7,
  },
  SYNTHWAVE: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 1.05,
    pitch: 1.0,
    reverb: {
      decay: 0.6,
      preDelayMs: 70,
      roomScale: 0.7,
      mix: 0.3,
    },
    echo: {
      delayMs: 400,
      feedback: 0.4,
    },
    eqWarmth: 0.4,
    stereoWidth: 1.3,
  },
  SLOW_MOTION: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 0.55,
    pitch: -6.0,
    reverb: {
      decay: 0.7,
      preDelayMs: 90,
      roomScale: 0.7,
      mix: 0.35,
    },
    echo: {
      delayMs: 600,
      feedback: 0.6,
    },
    eqWarmth: 0.5,
  },
  MANUAL: {
    specVersion: DSP_SPEC_VERSION,
    tempo: 1.0,
    pitch: 0.0,
  },
} as const;

export const PRESET_METADATA: Record<PresetId, { name: string; description: string }> = {
  SLOWED_REVERB: {
    name: "Slowed + Reverb",
    description: "Classic dreamy vaporwave effect",
  },
  VAPORWAVE_CHILL: {
    name: "Vaporwave Chill",
    description: "Warm, nostalgic sound",
  },
  NIGHTCORE: { name: "Nightcore", description: "Fast & energetic" },
  ECHO_SLOW: { name: "Echo Slow", description: "Hazy with deep echoes" },
  LOFI: { name: "Lo-Fi", description: "Warm, relaxed lo-fi sound" },
  AMBIENT: { name: "Ambient Space", description: "Ethereal, floating atmosphere" },
  DEEP_BASS: { name: "Deep Bass", description: "Heavy low-end focus" },
  CRYSTAL_CLEAR: { name: "Crystal Clear", description: "Crisp, bright sound" },
  UNDERWATER: { name: "Underwater", description: "Submerged, muffled atmosphere" },
  SYNTHWAVE: { name: "Synthwave", description: "Retro 80s vibes" },
  SLOW_MOTION: { name: "Slow Motion", description: "Extreme slow-down effect" },
  MANUAL: { name: "Manual", description: "Full control over all params" },
} as const;
