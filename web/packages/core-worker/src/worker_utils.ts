import type { ExportFormat, RenderPayload } from "@slowverb/shared";

export function clampNumber(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

export function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

export function clampInt(value: number, min: number, max: number): number {
  const rounded = Math.round(value);
  if (rounded < min) return min;
  if (rounded > max) return max;
  return rounded;
}

export function resolveTimeStretchParams(payload: RenderPayload): { tempo: number; pitchSemitones: number } {
  const spec = payload.dspSpec;
  const tempo = typeof spec?.tempo === "number" ? spec.tempo : 1.0;
  const pitchSemitones = typeof spec?.pitch === "number" ? spec.pitch : 0.0;
  return {
    tempo: clampNumber(tempo, 0.5, 2.0),
    pitchSemitones: clampNumber(pitchSemitones, -12.0, 12.0),
  };
}

export function buildDecodePlan(
  payload: RenderPayload,
  outputFile: string,
  sampleRate: number,
  isPreview: boolean
): string[] {
  const args: string[] = [];
  addTrimArgs(args, payload, isPreview);
  args.push("-i", payload.fileId);
  if (payload.filterGraph && payload.filterGraph !== "anull") {
    args.push("-af", payload.filterGraph);
  }
  args.push("-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", outputFile);
  return args;
}

export function buildRawDecodePlan(
  payload: RenderPayload,
  outputFile: string,
  sampleRate: number,
  isPreview: boolean
): string[] {
  const args: string[] = [];
  addTrimArgs(args, payload, isPreview);
  args.push("-i", payload.fileId);
  args.push("-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", outputFile);
  return args;
}

export function buildPcmFilterPlan(
  inputFile: string,
  outputFile: string,
  filterGraph: string,
  sampleRate: number
): string[] {
  const args: string[] = [];
  args.push("-f", "f32le", "-ac", "2", "-ar", `${sampleRate}`, "-i", inputFile);
  if (filterGraph !== "anull") {
    args.push("-af", filterGraph);
  }
  args.push("-ac", "2", "-ar", `${sampleRate}`, "-f", "f32le", "-y", outputFile);
  return args;
}

export function buildEncodePlan(
  inputFile: string,
  outputFile: string,
  payload: RenderPayload,
  sampleRate: number
): string[] {
  const args: string[] = [];
  args.push("-f", "f32le", "-ac", "2", "-ar", `${sampleRate}`, "-i", inputFile);
  addCodecArgs(args, payload.format, payload.bitrateKbps);
  args.push("-y", outputFile);
  return args;
}

export function addTrimArgs(args: string[], payload: RenderPayload, isPreview: boolean): void {
  if (!isPreview) return;
  const start = payload.startSec ?? 0;
  args.push("-ss", `${start}`);
  if (payload.durationSec != null) {
    args.push("-t", `${payload.durationSec}`);
  }
}

export function addInputArgs(args: string[], payload: RenderPayload): void {
  args.push("-i", payload.fileId);
  if (payload.filterGraph && payload.filterGraph !== "anull") {
    args.push("-af", payload.filterGraph);
  }
}

export function addCodecArgs(args: string[], format: ExportFormat, bitrateKbps?: number): void {
  switch (format) {
    case "mp3":
      args.push("-c:a", "libmp3lame");
      if (bitrateKbps) args.push("-b:a", `${bitrateKbps}k`);
      return;
    case "wav":
      args.push("-c:a", "pcm_s16le");
      return;
    case "flac":
      args.push("-c:a", "flac");
      return;
    case "aac":
      args.push("-c:a", "aac");
      if (bitrateKbps) args.push("-b:a", `${bitrateKbps}k`);
      return;
    default:
      throw new Error(`Unsupported export format: ${String(format)}`);
  }
}

export function buildOutputName(fileId: string, jobId: string, format: string, isPreview: boolean): string {
  const suffix = isPreview ? "preview" : "full";
  return `${fileId}-${jobId || "job"}-${suffix}.${format}`;
}

export function readAndSplitF32Stereo(fs: { readFile(path: string): unknown }, path: string): {
  left: Float32Array;
  right: Float32Array;
} {
  const bytes = fs.readFile(path);
  if (!(bytes instanceof Uint8Array)) throw new Error("Expected binary PCM output from FFmpeg");

  const pcm = bytes.slice().buffer;
  const interleaved = new Float32Array(pcm);
  if (interleaved.length % 2 !== 0) throw new Error("Invalid stereo PCM length");

  const frames = interleaved.length / 2;
  const left = new Float32Array(frames);
  const right = new Float32Array(frames);
  for (let i = 0; i < frames; i++) {
    left[i] = interleaved[i * 2];
    right[i] = interleaved[i * 2 + 1];
  }

  return { left, right };
}

export function writeInterleavedF32Stereo(
  fs: { writeFile(path: string, data: Uint8Array): void },
  path: string,
  left: Float32Array,
  right: Float32Array
): void {
  if (left.length !== right.length) throw new Error("Channel length mismatch");

  const frames = left.length;
  const interleaved = new Float32Array(frames * 2);
  for (let i = 0; i < frames; i++) {
    interleaved[i * 2] = left[i];
    interleaved[i * 2 + 1] = right[i];
  }
  fs.writeFile(path, new Uint8Array(interleaved.buffer));
}

export function readInterleavedF32(fs: { readFile(path: string): unknown }, path: string): Float32Array {
  const bytes = fs.readFile(path);
  if (!(bytes instanceof Uint8Array)) throw new Error("Expected binary PCM output from FFmpeg");
  const pcm = bytes.slice().buffer;
  const interleaved = new Float32Array(pcm);
  if (interleaved.length % 2 !== 0) throw new Error("Invalid stereo PCM length");
  return interleaved;
}

export function writeInterleavedF32(
  fs: { writeFile(path: string, data: Uint8Array): void },
  path: string,
  interleaved: Float32Array
): void {
  const bytes = new Uint8Array(interleaved.buffer, interleaved.byteOffset, interleaved.byteLength);
  fs.writeFile(path, bytes);
}

export function parseProbeLogs(lines: readonly string[]): {
  durationMs: number | null;
  sampleRate?: number;
  channels?: number;
  format?: string;
} {
  const duration = findDurationMs(lines);
  const format = findInputFormat(lines);
  const audio = findAudioStream(lines);
  return {
    durationMs: duration,
    format,
    sampleRate: audio?.sampleRate,
    channels: audio?.channels,
  };
}

function findDurationMs(lines: readonly string[]): number | null {
  for (const line of lines) {
    const match = /Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/.exec(line);
    if (!match) continue;
    const hours = Number(match[1]);
    const minutes = Number(match[2]);
    const seconds = Number(match[3]);
    if (!Number.isFinite(hours) || !Number.isFinite(minutes) || !Number.isFinite(seconds)) continue;
    return Math.round((hours * 3600 + minutes * 60 + seconds) * 1000);
  }
  return null;
}

function findInputFormat(lines: readonly string[]): string | undefined {
  for (const line of lines) {
    const match = /Input\s+#\d+,\s*([^,]+),\s*from\s*/.exec(line);
    if (match) return match[1].trim();
  }
  return undefined;
}

function findAudioStream(lines: readonly string[]): { sampleRate?: number; channels?: number } | undefined {
  for (const line of lines) {
    if (!line.includes("Audio:")) continue;
    const sampleRate = parseSampleRate(line);
    const channels = parseChannels(line);
    if (sampleRate || channels) return { sampleRate, channels };
  }
  return undefined;
}

function parseSampleRate(line: string): number | undefined {
  const match = /(\d{4,6})\s*Hz/.exec(line);
  if (!match) return undefined;
  const value = Number(match[1]);
  return Number.isFinite(value) ? value : undefined;
}

function parseChannels(line: string): number | undefined {
  if (line.includes(" mono")) return 1;
  if (line.includes(" stereo")) return 2;
  const surround = /\b([57])\.(1)\b/.exec(line);
  if (surround) {
    const base = Number(surround[1]);
    return base + 1;
  }
  return undefined;
}

export function chooseWaveformSampleRate(points: number, durationSec?: number): number {
  const samplesPerPoint = 64;
  if (!durationSec || durationSec <= 0) return 2000;
  const desired = Math.ceil((points * samplesPerPoint) / durationSec);
  return clampInt(desired, 500, 8000);
}

export function computePeaks(samples: Float32Array, points: number): Float32Array {
  const peaks = new Float32Array(points);
  if (samples.length === 0) return peaks;
  const window = Math.max(1, Math.floor(samples.length / points));

  for (let i = 0; i < points; i += 1) {
    const start = i * window;
    const end = i === points - 1 ? samples.length : Math.min(samples.length, start + window);
    let max = 0;
    for (let j = start; j < end; j += 1) {
      const value = Math.abs(samples[j]);
      if (value > max) max = value;
    }
    peaks[i] = max;
  }
  return peaks;
}

export function normalizeInPlace(values: Float32Array): void {
  let max = 0;
  for (let i = 0; i < values.length; i += 1) {
    if (values[i] > max) max = values[i];
  }
  if (max <= 0) return;
  for (let i = 0; i < values.length; i += 1) {
    values[i] = values[i] / max;
  }
}
