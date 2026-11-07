import type { PlaybackDeviceId, ReverbIrId } from "./dsp.js";

export interface IrEntry {
  /** Relative to the app base (served from web/web/irs). */
  readonly url: string;
  readonly label: string;
  /** Gain after afir with a unit-energy IR (gtype=none); measured on the bundled FFmpeg 5.1 core. */
  readonly makeupDb: number;
}

// Whitelists: specs can only select these bundled files, never arbitrary URLs.
// The service worker serves irs/ cache-first: when replacing an IR, give the file a new name.
export const PLAYBACK_DEVICES: Readonly<Record<PlaybackDeviceId, IrEntry>> = {
  // Makeup: IR decoded with the 30 Hz 4th-order highpass and unit energy; stage-on vs stage-off K-weighted
  // loudness (highpass 60 Hz + treble +4 dB @1.5 kHz, astats RMS; ebur128 is unusable on the bundled 5.1
  // core) of -3 dBFS pink noise within 0.2 LU. Harmonic-tone music mix then lands at -0.6/-0.5 (car),
  // +0.7 (cassette) LU. Gramophone split between pink (-1.5) and music mix (+1.8): its makeup is 1.5 dB
  // below the pink-only value (-14.5).
  sedan_2002_front: { url: "irs/sedan_2002_front.wav", label: "Car (front)", makeupDb: -6 },
  sedan_2002_rear: { url: "irs/sedan_2002_rear.wav", label: "Car (rear)", makeupDb: -6.5 },
  gramophone_cabinet: { url: "irs/gramophone_cabinet.wav", label: "Gramophone", makeupDb: -16 },
  cassette_portable: { url: "irs/cassette_portable.wav", label: "Cassette", makeupDb: -9 },
};

export const REVERB_IRS: Readonly<Record<ReverbIrId, IrEntry>> = {
  // Makeup: same K-weighted pink-noise measurement as above, so mix=1 wet loudness ~ dry loudness
  // (music-like mix: -0.3 hotel). Plate: Conner Plate I "5s -45" sweep (replaced the EMT 140, whose author
  // asks that it not be publicly hosted). On the bundled core at -14.5: pink -1.4, music mix 0.0 LU
  // (the EMT at -14 was -1.1 / +0.8). Slightly darker above 4 kHz than the EMT.
  plate_conner_i: { url: "irs/plate_conner_i.wav", label: "Plate", makeupDb: -14.5 },
  hotel_bathroom: { url: "irs/hotel_bathroom.wav", label: "Hotel Bathroom", makeupDb: -7 },
};

export function getPlaybackDevice(id: unknown): IrEntry | undefined {
  return typeof id === "string" && Object.hasOwn(PLAYBACK_DEVICES, id)
    ? PLAYBACK_DEVICES[id as PlaybackDeviceId]
    : undefined;
}

export function getReverbIr(id: unknown): IrEntry | undefined {
  return typeof id === "string" && Object.hasOwn(REVERB_IRS, id)
    ? REVERB_IRS[id as ReverbIrId]
    : undefined;
}
