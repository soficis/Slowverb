import type { RenderPayload } from "@slowverb/shared";

export function isPhaseLimiterEnabled(payload: RenderPayload): boolean {
  const mastering = payload.mastering;
  if (!mastering) return false;
  return mastering.enabled === true && (
    mastering.algorithm === "phaselimiter" || mastering.algorithm === "phaselimiter_pro"
  );
}

export function isSoundTouchEnabled(payload: RenderPayload): boolean {
  const spec = payload.dspSpec;
  const algorithm = spec?.quality?.timeStretch ?? "ffmpeg";
  if (algorithm !== "soundtouch") return false;
  const tempo = typeof spec?.tempo === "number" ? spec.tempo : 1.0;
  const pitch = typeof spec?.pitch === "number" ? spec.pitch : 0.0;
  return tempo !== 1.0 || pitch !== 0.0;
}

export function isToneReverbEnabled(payload: RenderPayload): boolean {
  const spec = payload.dspSpec;
  const algorithm = spec?.quality?.reverb ?? "ffmpeg";
  return algorithm === "tone" && spec?.reverb != null;
}

export function isSimpleMasteringEnabled(payload: RenderPayload): boolean {
  return payload.mastering?.enabled === true && payload.mastering?.algorithm === "simple";
}

export function validateRenderPayload(payload: RenderPayload): void {
  if (payload.mastering?.enabled === true) {
    const algorithm = payload.mastering.algorithm;
    if (algorithm !== "simple" && algorithm !== "phaselimiter" && algorithm !== "phaselimiter_pro") {
      throw new Error(`Unsupported mastering algorithm: ${String(algorithm)}`);
    }
  }
}
