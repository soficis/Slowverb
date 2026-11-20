import { readOutput } from "./ffmpeg_pipeline.js";
import type { WorkerFfmpegBridge } from "./worker_types.js";

export const COVER_MAX_PX = 600;
export type CoverFormat = "mp3" | "flac";

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
    `scale=${COVER_MAX_PX}:${COVER_MAX_PX}:force_original_aspect_ratio=decrease`,
    "-c:v",
    "mjpeg",
    "-q:v",
    "3",
    "-f",
    "image2",
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
    "mjpeg",
    "-q:v",
    "3",
    "-vf",
    `scale=${COVER_MAX_PX}:${COVER_MAX_PX}:force_original_aspect_ratio=decrease`,
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
  const out = `${fileId}-cover.jpg`;
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
