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

import 'package:slowverb/domain/entities/batch_render_progress.dart';
import 'package:slowverb/domain/entities/effect_preset.dart';
import 'package:slowverb/domain/entities/batch_job.dart';

/// Abstract interface for audio processing operations
///
/// All audio processing (preview and render) goes through this interface.
/// This allows swapping implementations (FFmpeg, native DSP, etc.)
/// without changing the rest of the app.
abstract class AudioEngine {
  /// Initialize the audio engine
  Future<void> initialize();

  /// Dispose of resources
  Future<void> dispose();

  /// Start preview playback with the given effects applied
  ///
  /// Returns the path to the processed preview file.
  Future<String> startPreview({
    required String sourcePath,
    required Map<String, double> params,
  });

  /// Stop preview playback
  Future<void> stopPreview();

  /// Render the full track with effects to the output path
  ///
  /// Returns a stream of progress updates (0.0 to 1.0).
  Stream<double> render({
    required String sourcePath,
    required Map<String, double> params,
    required String outputPath,
    required String format,
    int? bitrateKbps,
  });

  /// Cancel an ongoing render operation
  Future<void> cancelRender();

  /// Check if FFmpeg is available on this platform
  Future<bool> isAvailable();

  /// Render multiple files with the same or individual presets
  ///
  /// Returns a stream of BatchRenderProgress updates.
  /// [concurrency] controls parallel processing (desktop can use > 1, web should use 1)
  Stream<BatchRenderProgress> renderBatch({
    required List<BatchInputFile> files,
    required EffectPreset defaultPreset,
    required ExportOptions options,
    int concurrency = 1,
  });

  /// Cancel the entire batch operation
  Future<void> cancelBatch();

  /// Pause batch processing (if supported)
  Future<void> pauseBatch();

  /// Resume paused batch
  Future<void> resumeBatch();
}

/// Input file for batch processing
class BatchInputFile {
  final String fileId;
  final String sourcePath;
  final String fileName;
  final EffectPreset? presetOverride; // null = use batch default

  const BatchInputFile({
    required this.fileId,
    required this.sourcePath,
    required this.fileName,
    this.presetOverride,
  });
}

/// Result of a render operation
class RenderResult {
  final bool success;
  final String? outputPath;
  final String? errorMessage;
  final Duration? duration;

  const RenderResult({
    required this.success,
    this.outputPath,
    this.errorMessage,
    this.duration,
  });
}
