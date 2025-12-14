/*
 * Copyright (C) 2025 Slowverb
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:typed_data';

import 'package:slowverb_web/domain/entities/batch_render_progress.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';

/// Abstract interface for audio processing operations
///
/// All audio processing (preview and render) goes through this interface.
/// This allows swapping implementations (WASM backend, mock for tests, etc.)
/// without changing the rest of the app.
abstract class AudioEngine {
  /// Initialize the audio engine (loads WASM, creates worker, etc.)
  Future<void> initialize();

  /// Dispose of resources and cleanup
  Future<void> dispose();

  /// Check if the engine is ready to process audio
  bool get isReady;

  /// Evaluate memory impact before loading a source file.
  Future<MemoryPreflightResult> checkMemoryPreflight(int fileSizeBytes);

  /// Load an audio file into the engine
  ///
  /// Returns metadata about the loaded audio file.
  Future<AudioMetadata> loadSource({
    required String fileId,
    required String filename,
    required Uint8List bytes,
  });

  /// Generate waveform data for visualization
  ///
  /// Returns normalized amplitude values for rendering waveform.
  Future<Float32List> getWaveform(String fileId, {int targetSamples = 1000});

  /// Render a preview segment with effects applied
  ///
  /// Returns a URI (blob URL) to the processed audio preview.
  /// Preview is typically a 30-second segment for quick feedback.
  Future<Uri> renderPreview({
    required String fileId,
    required EffectConfig config,
    Duration? startAt,
    Duration? duration,
  });

  /// Start a full render job with progress tracking
  ///
  /// Returns a job ID for tracking progress via [watchProgress].
  Future<RenderJobId> startRender({
    required String fileId,
    required EffectConfig config,
    required ExportOptions options,
  });

  /// Watch progress of an ongoing render job
  ///
  /// Emits progress updates from 0.0 to 1.0.
  Stream<RenderProgress> watchProgress(RenderJobId jobId);

  /// Get the final result of a completed render job
  Future<RenderResult> getResult(RenderJobId jobId);

  /// Cancel an ongoing render operation
  Future<void> cancelRender(RenderJobId jobId);

  /// Free memory for a loaded source file
  Future<void> cleanup({String? fileId});

  /// Render multiple files with batch processing
  ///
  /// For web, this ALWAYS uses sequential processing (concurrency = 1)
  /// to avoid browser memory issues. Files are processed one at a time.
  Stream<BatchRenderProgress> renderBatch({
    required List<BatchInputFile> files,
    required EffectPreset defaultPreset,
    required ExportOptions options,
  });

  /// Cancel the entire batch operation
  Future<void> cancelBatch();

  /// Pause the batch operation (can be resumed later)
  Future<void> pauseBatch();

  /// Resume a paused batch operation
  Future<void> resumeBatch();
}

/// Metadata extracted from an audio file
class AudioMetadata {
  final String fileId;
  final String filename;
  final Duration? duration; // null = unknown/process entire file
  final int sampleRate;
  final int channels;
  final String format; // 'mp3', 'wav', 'flac', etc.

  const AudioMetadata({
    required this.fileId,
    required this.filename,
    required this.duration,
    required this.sampleRate,
    required this.channels,
    required this.format,
  });

  /// Returns true if the source format is lossless.
  /// FLAC export should only be recommended for lossless sources.
  bool get isLossless {
    const losslessFormats = ['wav', 'flac', 'aiff', 'alac', 'pcm', 'aif'];
    return losslessFormats.contains(format.toLowerCase());
  }
}

/// Effect configuration for audio processing
class EffectConfig {
  final String presetId;
  final double tempo; // 0.5 - 1.5
  final double pitchSemitones; // -12 to +12
  final double reverbAmount; // 0.0 - 1.0
  final double echoAmount; // 0.0 - 1.0
  final double eqWarmth; // 0.0 - 1.0
  final double? preDelayMs; // 0 - 200
  final double? hfDamping; // 0.0 - 1.0
  final double? roomScale; // 0.0 - 1.0
  final double? stereoWidth; // 0.0 - 1.0

  const EffectConfig({
    required this.presetId,
    required this.tempo,
    required this.pitchSemitones,
    required this.reverbAmount,
    this.echoAmount = 0.0,
    this.eqWarmth = 0.0,
    this.preDelayMs,
    this.hfDamping,
    this.roomScale,
    this.stereoWidth,
  });

  /// Create configuration from parameter map
  factory EffectConfig.fromParams(String presetId, Map<String, double> params) {
    return EffectConfig(
      presetId: presetId,
      tempo: params['tempo'] ?? 1.0,
      pitchSemitones: params['pitch'] ?? 0.0,
      reverbAmount: params['reverbAmount'] ?? 0.0,
      echoAmount: params['echoAmount'] ?? 0.0,
      eqWarmth: params['eqWarmth'] ?? 0.0,
      preDelayMs: params['preDelayMs'],
      hfDamping: params['hfDamping'],
      roomScale: params['roomScale'],
      stereoWidth: params['stereoWidth'],
    );
  }
}

/// Export options for final render
class ExportOptions {
  final String format; // 'mp3', 'wav', 'flac'
  final int? bitrateKbps; // For MP3: 128, 192, 320
  final int? compressionLevel; // For FLAC: 0-8

  const ExportOptions({
    required this.format,
    this.bitrateKbps,
    this.compressionLevel,
  });

  /// MP3 export at 320kbps
  static const mp3High = ExportOptions(format: 'mp3', bitrateKbps: 320);

  /// MP3 export at 192kbps
  static const mp3Standard = ExportOptions(format: 'mp3', bitrateKbps: 192);

  /// WAV export (lossless)
  static const wav = ExportOptions(format: 'wav');

  /// FLAC export (lossless, compressed)
  static const flac = ExportOptions(format: 'flac', compressionLevel: 8);
}

/// Render job identifier
class RenderJobId {
  final String value;

  const RenderJobId(this.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderJobId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Progress update from a render job
class RenderProgress {
  final RenderJobId jobId;
  final double progress; // 0.0 - 1.0
  final String stage; // 'decoding', 'filtering', 'encoding'

  const RenderProgress({
    required this.jobId,
    required this.progress,
    required this.stage,
  });
}

/// Final result of a render operation
class RenderResult {
  final bool success;
  final Uint8List? outputBytes;
  final String? errorMessage;
  final Duration? renderDuration;

  const RenderResult({
    required this.success,
    this.outputBytes,
    this.errorMessage,
    this.renderDuration,
  });
}

/// Input file for batch processing
class BatchInputFile {
  final String fileId;
  final String fileName;
  final Uint8List bytes;
  final EffectPreset? presetOverride; // null = use batch default

  const BatchInputFile({
    required this.fileId,
    required this.fileName,
    required this.bytes,
    this.presetOverride,
  });
}

class MemoryPreflightResult {
  final bool isBlocked;
  final bool isWarning;
  final String? message;

  const MemoryPreflightResult._({
    required this.isBlocked,
    required this.isWarning,
    this.message,
  });

  const MemoryPreflightResult.ok()
    : this._(isBlocked: false, isWarning: false, message: null);

  const MemoryPreflightResult.warning(String message)
    : this._(isBlocked: false, isWarning: true, message: message);

  const MemoryPreflightResult.blocked(String message)
    : this._(isBlocked: true, isWarning: false, message: message);
}
