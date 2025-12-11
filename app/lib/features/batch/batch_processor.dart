import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
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

    // Resolve app-private working dir (always inside app storage to avoid SAF issues)
    final appDocsDir = await getApplicationDocumentsDirectory();
    final workDir = Directory(path.join(appDocsDir.path, '.work'));
    if (!workDir.existsSync()) {
      workDir.createSync(recursive: true);
    }

    // Ensure output directory exists
    var effectiveDestination = destinationFolder;
    try {
      final outDir = Directory(effectiveDestination);
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }
    } catch (_) {
      // Fallback to app storage if external path is not writeable (Android SAF)
      effectiveDestination = appDocsDir.path;
      final outDir = Directory(effectiveDestination);
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }
      print(
        '[Batch] Destination not writable, using app storage: $effectiveDestination',
      );
    }

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

        // Copy source into app-owned working dir to ensure readable path
        final sourceFile = File(item.filePath!);
        final safeSourcePath = await _copyToWorkDir(
          sourceFile,
          workDir.path,
          item.fileName,
        );

        // Build output path
        final baseName = path.basenameWithoutExtension(safeSourcePath);
        final effectiveFormat = Platform.isAndroid
            ? 'wav'
            : job.exportOptions.format;
        final effectiveBitrate = Platform.isAndroid
            ? null
            : job.exportOptions.bitrateKbps;
        final extension = effectiveFormat;
        final outputPath = path.join(
          effectiveDestination,
          '${baseName}_${preset.id}.$extension',
        );

        print('[Batch] Processing ${item.fileName} -> $outputPath');

        // Process using FFmpegAudioEngine with actual effects
        await _processWithEffects(
          sourcePath: safeSourcePath,
          outputPath: outputPath,
          preset: preset,
          format: effectiveFormat,
          bitrateKbps: effectiveBitrate,
        );

        // Verify output exists
        final outFile = File(outputPath);
        if (!outFile.existsSync()) {
          throw Exception('Output file missing after render');
        }

        // Mark as complete
        state = state!.updateItem(
          item.fileId,
          item.copyWith(
            status: RenderJobStatus.success,
            progress: 1.0,
            outputPath: outputPath,
          ),
        );

        print('[Batch] Success ${item.fileName}');
      } catch (e) {
        // Mark as failed
        state = state!.updateItem(
          item.fileId,
          item.copyWith(
            status: RenderJobStatus.failed,
            errorMessage: e.toString(),
          ),
        );
        print('[Batch] Failed ${item.fileName}: $e');
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

    print(
      '[Batch] Done. success=${state!.completedCount} failed=${state!.failedCount}',
    );
  }

  /// Copy source file into a local working directory (especially for Android SAF paths)
  Future<String> _copyToWorkDir(
    File source,
    String workDir,
    String originalName,
  ) async {
    final ext = path.extension(originalName);
    final base = path.basenameWithoutExtension(originalName);
    final safeBase = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = path.join(workDir, '$safeBase$ext');

    try {
      await source.copy(dest);
      return dest;
    } catch (e) {
      // Fallback: try reading bytes then writing
      final bytes = await source.readAsBytes();
      final destFile = File(dest);
      await destFile.writeAsBytes(bytes, flush: true);
      return dest;
    }
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
