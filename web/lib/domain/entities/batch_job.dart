import 'dart:typed_data';
import 'package:slowverb_web/domain/entities/effect_preset.dart';

/// Status of a batch processing job
enum BatchJobStatus {
  pending,
  running,
  paused,
  completed,
  partialComplete,
  failed,
  cancelled,
}

/// Status of individual render job
enum RenderJobStatus { queued, running, success, failed, cancelled }

/// Represents a single file within a batch job
class BatchJobItem {
  final String fileId;
  final String fileName;
  final EffectPreset? presetOverride;
  final RenderJobStatus status;
  final double progress;
  final String? errorMessage;
  final Uint8List? resultBytes;

  const BatchJobItem({
    required this.fileId,
    required this.fileName,
    this.presetOverride,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    this.resultBytes,
  });

  BatchJobItem copyWith({
    String? fileId,
    String? fileName,
    EffectPreset? presetOverride,
    bool clearPresetOverride = false,
    RenderJobStatus? status,
    double? progress,
    String? errorMessage,
    bool clearError = false,
    Uint8List? resultBytes,
  }) {
    return BatchJobItem(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      presetOverride: clearPresetOverride
          ? null
          : (presetOverride ?? this.presetOverride),
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resultBytes: resultBytes ?? this.resultBytes,
    );
  }
}

/// Export options for batch processing
class ExportOptions {
  final String format;
  final int? bitrateKbps;
  final int? sampleRate;

  const ExportOptions({
    required this.format,
    this.bitrateKbps,
    this.sampleRate,
  });

  ExportOptions copyWith({
    String? format,
    int? bitrateKbps,
    bool clearBitrate = false,
    int? sampleRate,
    bool clearSampleRate = false,
  }) {
    return ExportOptions(
      format: format ?? this.format,
      bitrateKbps: clearBitrate ? null : (bitrateKbps ?? this.bitrateKbps),
      sampleRate: clearSampleRate ? null : (sampleRate ?? this.sampleRate),
    );
  }
}

/// Represents a batch audio processing job
class BatchJob {
  final String id;
  final List<BatchJobItem> items;
  final EffectPreset defaultPreset;
  final ExportOptions exportOptions;
  final BatchJobStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int maxConcurrency;

  const BatchJob({
    required this.id,
    required this.items,
    required this.defaultPreset,
    required this.exportOptions,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.maxConcurrency = 1,
  });

  int get completedCount =>
      items.where((item) => item.status == RenderJobStatus.success).length;

  int get failedCount =>
      items.where((item) => item.status == RenderJobStatus.failed).length;

  int get runningCount =>
      items.where((item) => item.status == RenderJobStatus.running).length;

  int get queuedCount =>
      items.where((item) => item.status == RenderJobStatus.queued).length;

  double get overallProgress {
    if (items.isEmpty) return 0.0;
    final totalProgress = items.fold<double>(
      0.0,
      (sum, item) => sum + item.progress,
    );
    return totalProgress / items.length;
  }

  int get totalCount => items.length;

  bool get hasStarted => startedAt != null;

  bool get isFinished =>
      status == BatchJobStatus.completed ||
      status == BatchJobStatus.partialComplete ||
      status == BatchJobStatus.failed ||
      status == BatchJobStatus.cancelled;

  Duration? get estimatedTimeRemaining {
    if (!hasStarted || completedCount == 0) return null;

    final elapsed = DateTime.now().difference(startedAt!);
    final avgTimePerFile = elapsed.inSeconds / completedCount;
    final remainingFiles = totalCount - completedCount;

    return Duration(seconds: (avgTimePerFile * remainingFiles).round());
  }

  BatchJob copyWith({
    String? id,
    List<BatchJobItem>? items,
    EffectPreset? defaultPreset,
    ExportOptions? exportOptions,
    BatchJobStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? maxConcurrency,
  }) {
    return BatchJob(
      id: id ?? this.id,
      items: items ?? this.items,
      defaultPreset: defaultPreset ?? this.defaultPreset,
      exportOptions: exportOptions ?? this.exportOptions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
    );
  }

  BatchJob updateItem(String fileId, BatchJobItem updatedItem) {
    final newItems = items.map((item) {
      return item.fileId == fileId ? updatedItem : item;
    }).toList();

    return copyWith(items: newItems);
  }

  BatchJob removeItem(String fileId) {
    if (hasStarted) {
      throw StateError('Cannot remove items from a started batch');
    }

    final newItems = items.where((item) => item.fileId != fileId).toList();
    return copyWith(items: newItems);
  }

  BatchJob addItem(BatchJobItem item) {
    if (hasStarted) {
      throw StateError('Cannot add items to a started batch');
    }

    final newItems = [...items, item];
    return copyWith(items: newItems);
  }
}
