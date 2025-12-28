declare module "soundtouchjs" {
  export class SoundTouch {
    tempo: number;
    rate: number;
    pitch: number;
    pitchSemitones: number;
    stretch: {
      setParameters: (
        sampleRate: number,
        sequenceMs: number,
        seekWindowMs: number,
        overlapMs: number
      ) => void;
    };
  }

  export class SimpleFilter {
    sourcePosition: number;
    constructor(
      sourceSound: {
        extract: (target: Float32Array, numFrames?: number, position?: number) => number;
      },
      pipe: unknown,
      callback?: () => void
    );
    extract: (target: Float32Array, numFrames?: number) => number;
  }
}
