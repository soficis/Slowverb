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
import 'package:slowverb/domain/entities/effect_preset.dart';
import 'package:slowverb/domain/entities/history_entry.dart';
import 'package:slowverb/domain/entities/render_job.dart';

/// Status of a batch processing job
enum BatchJobStatus {
  pending, // Job created but not started
  running, // Currently processing
  paused, // Paused by user
  completed, // All files processed successfully
  partialComplete, // Some files succeeded, some failed
  failed, // Critical error stopped batch
  cancelled, // Cancelled by user
}

/// Represents a single file within a batch job
class BatchJobItem {
  final String fileId;
  final String fileName;
  final String? filePath; // Desktop only - source file path
  final EffectPreset? presetOverride; // null = use batch default
  final RenderJobStatus status;
  final double progress; // 0.0 - 1.0
  final String? errorMessage;
  final String? outputPath; // Desktop only - rendered output path
  final Uint8List? resultBytes; // Web only - rendered output bytes
  final String? historyEntryId; // Optional - links to source HistoryEntry

  const BatchJobItem({
    required this.fileId,
    required this.fileName,
    this.filePath,
    this.presetOverride,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    this.outputPath,
    this.resultBytes,
    this.historyEntryId,
  });

  BatchJobItem copyWith({
    String? fileId,
    String? fileName,
    String? filePath,
    EffectPreset? presetOverride,
    bool clearPresetOverride = false,
    RenderJobStatus? status,
    double? progress,
    String? errorMessage,
    bool clearError = false,
    String? outputPath,
    Uint8List? resultBytes,
    String? historyEntryId,
  }) {
    return BatchJobItem(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      presetOverride: clearPresetOverride
          ? null
          : (presetOverride ?? this.presetOverride),
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      outputPath: outputPath ?? this.outputPath,
      resultBytes: resultBytes ?? this.resultBytes,
      historyEntryId: historyEntryId ?? this.historyEntryId,
    );
  }
}

/// Export options for batch processing
class ExportOptions {
  final String format; // mp3, wav, aac, etc.
  final int? bitrateKbps; // For lossy formats
  final int? sampleRate; // Target sample rate

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
  final int maxConcurrency; // Desktop can use > 1, web should use 1

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

  /// Number of items completed successfully
  int get completedCount =>
      items.where((item) => item.status == RenderJobStatus.success).length;

  /// Number of items that failed
  int get failedCount =>
      items.where((item) => item.status == RenderJobStatus.failed).length;

  /// Number of items currently running
  int get runningCount =>
      items.where((item) => item.status == RenderJobStatus.running).length;

  /// Number of items queued
  int get queuedCount =>
      items.where((item) => item.status == RenderJobStatus.queued).length;

  /// Overall progress (0.0 - 1.0)
  double get overallProgress {
    if (items.isEmpty) return 0.0;
    final totalProgress = items.fold<double>(
      0.0,
      (sum, item) => sum + item.progress,
    );
    return totalProgress / items.length;
  }

  /// Total number of items in batch
  int get totalCount => items.length;

  /// Whether the batch has started processing
  bool get hasStarted => startedAt != null;

  /// Whether the batch is finished (completed, partially complete, failed, or cancelled)
  bool get isFinished =>
      status == BatchJobStatus.completed ||
      status == BatchJobStatus.partialComplete ||
      status == BatchJobStatus.failed ||
      status == BatchJobStatus.cancelled;

  /// Estimated time remaining (null if not enough data)
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

  /// Update a specific item in the batch
  BatchJob updateItem(String fileId, BatchJobItem updatedItem) {
    final newItems = items.map((item) {
      return item.fileId == fileId ? updatedItem : item;
    }).toList();

    return copyWith(items: newItems);
  }

  /// Remove an item from the batch (only if not started)
  BatchJob removeItem(String fileId) {
    if (hasStarted) {
      throw StateError('Cannot remove items from a started batch');
    }

    final newItems = items.where((item) => item.fileId != fileId).toList();
    return copyWith(items: newItems);
  }

  /// Add an item to the batch (only if not started)
  BatchJob addItem(BatchJobItem item) {
    if (hasStarted) {
      throw StateError('Cannot add items to a started batch');
    }

    final newItems = [...items, item];
    return copyWith(items: newItems);
  }

  /// Creates a batch job from history entries for re-export
  factory BatchJob.fromHistoryEntries({
    required List<HistoryEntry> entries,
    required ExportOptions exportOptions,
    required String destinationFolder,
    int maxConcurrency = 1,
  }) {
    final items = entries.map((entry) {
      return BatchJobItem(
        fileId: entry.id,
        fileName:
            entry.sourceFileName ??
            entry.sourcePath.split(RegExp(r'[/\\]')).last,
        filePath: entry.sourcePath,
        status: RenderJobStatus.queued,
        historyEntryId: entry.id,
      );
    }).toList();

    // Use the preset from the first entry as default
    // (individual items can override via presetOverride if needed)
    final defaultPresetId = entries.isNotEmpty
        ? entries.first.presetId
        : 'slowed_reverb';
    final defaultPreset = Presets.all.firstWhere(
      (p) => p.id == defaultPresetId,
      orElse: () => Presets.slowedReverb,
    );

    return BatchJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: items,
      defaultPreset: defaultPreset,
      exportOptions: exportOptions,
      status: BatchJobStatus.pending,
      createdAt: DateTime.now(),
      maxConcurrency: maxConcurrency,
    );
  }
}
