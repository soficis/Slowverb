/**
 * Scales an interleaved stereo IR in place to unit energy per channel.
 * Returns false (leaving data untouched) if a channel has zero or non-finite energy.
 */
export function normalizeStereoIrEnergy(data: Float32Array): boolean {
  const energy = [0, 0];
  for (let i = 0; i < data.length; i += 1) energy[i & 1] += data[i] * data[i];
  if (!energy.every((e) => e > 0 && Number.isFinite(e))) return false;
  const scale = energy.map((e) => 1 / Math.sqrt(e));
  for (let i = 0; i < data.length; i += 1) data[i] *= scale[i & 1];
  return true;
}
