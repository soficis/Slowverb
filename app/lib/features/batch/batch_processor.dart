import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:slowverb/domain/entities/batch_job.dart';
import 'package:slowverb/domain/entities/effect_preset.dart';
import 'package:slowverb/domain/entities/render_job.dart';
import 'package:slowverb/audio_engine/ffmpeg_audio_engine.dart';

/// Batch processor that uses FFmpegAudioEngine for actual effect processing
class BatchProcessor extends StateNotifier<BatchJob?> {
  final Ref _ref;
  final FFmpegAudioEngine _audioEngine = FFmpegAudioEngine();

  BatchProcessor(this._ref) : super(null);

  /// Start processing a batch job with actual audio effects
  Future<void> startBatch(BatchJob job, String destinationFolder) async {
    // Initialize audio engine
    await _audioEngine.initialize();

    state = job.copyWith(
      status: BatchJobStatus.running,
      startedAt: DateTime.now(),
    );

    for (var i = 0; i < job.items.length; i++) {
      final item = job.items[i];

      // Skip if no source file
      if (item.filePath == null || !File(item.filePath!).existsSync()) {
        state = state!.updateItem(
          item.fileId,
          item.copyWith(
            status: RenderJobStatus.failed,
            errorMessage: 'Source file not found',
          ),
        );
        continue;
      }

      // Update item status to running
      state = state!.updateItem(
        item.fileId,
        item.copyWith(status: RenderJobStatus.running),
      );

      try {
        // Determine preset and parameters (use default or override)
        final preset = item.presetOverride ?? job.defaultPreset;

        // Build output path
        final sourceFile = File(item.filePath!);
        final baseName = path.basenameWithoutExtension(sourceFile.path);
        final extension = job.exportOptions.format;
        final outputPath = path.join(
          destinationFolder,
          '${baseName}_${preset.id}.$extension',
        );

        // Process using FFmpegAudioEngine with actual effects
        await _processWithEffects(
          sourcePath: item.filePath!,
          outputPath: outputPath,
          preset: preset,
          format: job.exportOptions.format,
          bitrateKbps: job.exportOptions.bitrateKbps,
        );

        // Mark as complete
        state = state!.updateItem(
          item.fileId,
          item.copyWith(
            status: RenderJobStatus.success,
            progress: 1.0,
            outputPath: outputPath,
          ),
        );
      } catch (e) {
        // Mark as failed
        state = state!.updateItem(
          item.fileId,
          item.copyWith(
            status: RenderJobStatus.failed,
            errorMessage: e.toString(),
          ),
        );
      }
    }

    // Update batch status based on results
    final hasFailures = state!.failedCount > 0;
    final hasSuccesses = state!.completedCount > 0;

    state = state!.copyWith(
      status: hasFailures && hasSuccesses
          ? BatchJobStatus.partialComplete
          : hasSuccesses
          ? BatchJobStatus.completed
          : BatchJobStatus.failed,
      completedAt: DateTime.now(),
    );
  }

  /// Process a file with actual audio effects using FFmpegAudioEngine
  Future<void> _processWithEffects({
    required String sourcePath,
    required String outputPath,
    required EffectPreset preset,
    required String format,
    int? bitrateKbps,
  }) async {
    // Use preset's built-in toParametersMap() method
    final params = preset.toParametersMap();

    // Use the audio engine to render with effects
    final progressStream = _audioEngine.render(
      sourcePath: sourcePath,
      params: params,
      outputPath: outputPath,
      format: format,
      bitrateKbps: bitrateKbps,
    );

    // Wait for render to complete
    await for (final progress in progressStream) {
      if (progress >= 1.0) break;
    }
  }

  void clearBatch() {
    state = null;
  }

  @override
  void dispose() {
    _audioEngine.dispose();
    super.dispose();
  }
}

final batchProcessorProvider = StateNotifierProvider<BatchProcessor, BatchJob?>(
  (ref) {
    return BatchProcessor(ref);
  },
);
