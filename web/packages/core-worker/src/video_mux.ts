import type { MuxStillVideoPayload } from "@slowverb/shared";
import { readOutput } from "./ffmpeg_pipeline.js";
import { writeInterleavedF32Stereo } from "./worker_utils.js";
import type { WorkerFfmpegBridge } from "./worker_types.js";

export const BLACK_PNG_BASE64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==";

export function blackPngBytes(): Uint8Array {
  const binary = atob(BLACK_PNG_BASE64);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

export interface StillVideoParams {
  width: number;
  height: number;
  fps: number;
  crf: number;
  encoder: "libx264" | "mpeg4";
}

export function resolveStillVideoParams(p: {
  width: number;
  height: number;
  fps?: number;
  crf?: number;
  encoder?: "libx264" | "mpeg4";
}): StillVideoParams {
  const { width, height } = p;
  const fps = p.fps ?? 30;
  const crf = p.crf ?? 23;
  const encoder = p.encoder ?? "libx264";
  if (!Number.isInteger(width) || width < 16 || width > 4096 || width % 2 !== 0) {
    throw new RangeError(`width must be an even integer in [16, 4096], got ${String(width)}`);
  }
  if (!Number.isInteger(height) || height < 16 || height > 4096 || height % 2 !== 0) {
    throw new RangeError(`height must be an even integer in [16, 4096], got ${String(height)}`);
  }
  if (width * height > 3840 * 2160) {
    throw new RangeError(`width*height area ${width * height} exceeds maximum ${3840 * 2160}`);
  }
  if (!Number.isInteger(fps) || fps < 1 || fps > 60) {
    throw new RangeError(`fps must be an integer in [1, 60], got ${String(fps)}`);
  }
  if (!Number.isInteger(crf) || crf < 0 || crf > 51) {
    throw new RangeError(`crf must be an integer in [0, 51], got ${String(crf)}`);
  }
  if (encoder !== "libx264" && encoder !== "mpeg4") {
    throw new RangeError(`encoder must be "libx264" or "mpeg4", got ${String(encoder)}`);
  }
  return { width, height, fps, crf, encoder };
}

export function buildBedArgs(still: string, bed: string, p: StillVideoParams): string[] {
  const args: string[] = [
    "-loop",
    "1",
    "-framerate",
    `${p.fps}`,
    "-i",
    still,
    "-t",
    "2",
    "-vf",
    `scale=${p.width}:${p.height}:force_original_aspect_ratio=increase,crop=${p.width}:${p.height},setsar=1`,
    "-c:v",
    p.encoder,
  ];
  if (p.encoder === "libx264") {
    args.push("-preset", "ultrafast", "-tune", "stillimage", "-crf", `${p.crf}`);
  } else {
    args.push("-q:v", "3");
  }
  args.push("-g", `${p.fps}`, "-pix_fmt", "yuv420p", "-r", `${p.fps}`, "-an", "-y", bed);
  return args;
}

export function buildMuxArgs(bed: string, audio: string, sampleRate: number, out: string): string[] {
  return [
    "-stream_loop",
    "-1",
    "-i",
    bed,
    "-f",
    "f32le",
    "-ac",
    "2",
    "-ar",
    `${sampleRate}`,
    "-i",
    audio,
    "-map",
    "0:v:0",
    "-map",
    "1:a:0",
    "-c:v",
    "copy",
    "-c:a",
    "aac",
    "-b:a",
    "192k",
    "-shortest",
    "-movflags",
    "+faststart",
    "-y",
    out,
  ];
}

export async function muxStillVideo(
  ffmpeg: WorkerFfmpegBridge,
  payload: MuxStillVideoPayload,
  jobId: string,
  cleanupFiles: (...paths: string[]) => void
): Promise<ArrayBuffer> {
  const p = resolveStillVideoParams(payload);
  if (payload.left.length !== payload.right.length || payload.left.length === 0) {
    throw new RangeError("left and right must have equal non-zero length");
  }
  if (!Number.isFinite(payload.sampleRate) || payload.sampleRate <= 0) {
    throw new RangeError(`sampleRate must be finite and > 0, got ${String(payload.sampleRate)}`);
  }
  const still = `${jobId}-still.img`;
  const bed = `${jobId}-bed.mp4`;
  const audio = `${jobId}-audio.f32`;
  const out = `${jobId}-video.mp4`;
  try {
    ffmpeg.FS.writeFile(
      still,
      payload.still && payload.still.length > 0 ? payload.still : blackPngBytes()
    );
    writeInterleavedF32Stereo(ffmpeg.FS, audio, payload.left, payload.right);
    (ffmpeg as { reset?: () => void }).reset?.();
    const r1 = ffmpeg.exec(...buildBedArgs(still, bed, p));
    if (r1 !== 0) throw new Error(`video bed encode failed (exit ${r1})`);
    (ffmpeg as { reset?: () => void }).reset?.();
    const r2 = ffmpeg.exec(...buildMuxArgs(bed, audio, payload.sampleRate, out));
    if (r2 !== 0) throw new Error(`video mux failed (exit ${r2})`);
    return readOutput(ffmpeg, out);
  } finally {
    cleanupFiles(still, bed, audio, out);
  }
}
