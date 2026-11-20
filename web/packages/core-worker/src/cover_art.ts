import { readOutput } from "./ffmpeg_pipeline.js";
import type { WorkerFfmpegBridge } from "./worker_types.js";

export const COVER_MAX_PX = 600;
// PNG, not mjpeg: the mjpeg encoder in the browser ffmpeg-core.wasm traps
// ("memory access out of bounds") even though the Node build used by vitest works.
export type CoverFormat = "mp3" | "flac";
// Shrink to fit COVER_MAX_PX, never enlarge: upscaled PNG art only bloats the file.
export const COVER_SCALE_FILTER = `scale='min(${COVER_MAX_PX},iw)':'min(${COVER_MAX_PX},ih)':force_original_aspect_ratio=decrease`;

export function supportsCoverArt(format: string): format is CoverFormat {
  return format === "mp3" || format === "flac";
}

export function buildExtractCoverArgs(input: string, out: string): string[] {
  return [
    "-hide_banner",
    "-i",
    input,
    "-map",
    "0:v:0",
    "-frames:v",
    "1",
    "-an",
    "-vf",
    COVER_SCALE_FILTER,
    "-c:v",
    "png",
    "-f",
    "image2",
    "-update",
    "1",
    "-y",
    out,
  ];
}

export function buildAttachCoverArgs(
  audio: string,
  cover: string,
  out: string,
  format: CoverFormat
): string[] {
  const args: string[] = [
    "-hide_banner",
    "-i",
    audio,
    "-i",
    cover,
    "-map",
    "0:a:0",
    "-map",
    "1:v:0",
    "-c:a",
    "copy",
    "-c:v",
    "png",
    "-vf",
    COVER_SCALE_FILTER,
    "-disposition:v:0",
    "attached_pic",
  ];
  if (format === "mp3") {
    args.push(
      "-id3v2_version",
      "3",
      "-metadata:s:v",
      "title=Album cover",
      "-metadata:s:v",
      "comment=Cover (front)"
    );
  }
  args.push("-f", format, "-y", out);
  return args;
}

export function extractCoverArt(
  ffmpeg: WorkerFfmpegBridge,
  fileId: string,
  cleanupFiles: (...p: string[]) => void
): ArrayBuffer | null {
  const out = `${fileId}-cover.png`;
  try {
    (ffmpeg as { reset?: () => void }).reset?.();
    const rc = ffmpeg.exec(...buildExtractCoverArgs(fileId, out));
    if (rc !== 0) return null;
    try {
      const info = ffmpeg.FS.analyzePath(out);
      if (!info?.exists) return null;
    } catch {
      // fall through to read attempt
    }
    const buf = readOutput(ffmpeg, out);
    if (buf.byteLength === 0) return null;
    return buf;
  } catch {
    return null;
  } finally {
    try {
      cleanupFiles(out);
    } catch {
      // ignore cleanup errors; a missing cover is normal
    }
  }
}

export function attachCoverArt(
  ffmpeg: WorkerFfmpegBridge,
  audio: ArrayBuffer,
  cover: ArrayBuffer,
  format: CoverFormat,
  jobId: string,
  cleanupFiles: (...p: string[]) => void
): ArrayBuffer {
  const inAudio = `${jobId}-cover-in.${format}`;
  const img = `${jobId}-cover.img`;
  const out = `${jobId}-cover-out.${format}`;
  try {
    ffmpeg.FS.writeFile(inAudio, new Uint8Array(audio));
    ffmpeg.FS.writeFile(img, new Uint8Array(cover));
    (ffmpeg as { reset?: () => void }).reset?.();
    const rc = ffmpeg.exec(...buildAttachCoverArgs(inAudio, img, out, format));
    if (rc !== 0) return audio;
    const buf = readOutput(ffmpeg, out);
    if (buf.byteLength === 0) return audio;
    return buf;
  } catch {
    return audio;
  } finally {
    try {
      cleanupFiles(inAudio, img, out);
    } catch {
      // ignore cleanup errors; cover art must never fail an export
    }
  }
}
