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

/// Aggregate progress model for batch rendering
///
/// Provides real-time updates during batch processing,
/// used to update UI with overall and per-file progress.
class BatchRenderProgress {
  final int totalFiles;
  final int completedFiles;
  final int failedFiles;
  final int currentFileIndex; // -1 if batch not started or finished
  final String? currentFileName;
  final double currentFileProgress; // 0.0 - 1.0
  final double overallProgress; // 0.0 - 1.0
  final Duration? estimatedTimeRemaining;
  final List<String> completedFileNames;
  final Map<String, String> errors; // fileName -> error message

  const BatchRenderProgress({
    required this.totalFiles,
    this.completedFiles = 0,
    this.failedFiles = 0,
    this.currentFileIndex = -1,
    this.currentFileName,
    this.currentFileProgress = 0.0,
    this.overallProgress = 0.0,
    this.estimatedTimeRemaining,
    this.completedFileNames = const [],
    this.errors = const {},
  });

  /// Whether the batch has started
  bool get hasStarted => currentFileIndex >= 0;

  /// Whether the batch is finished
  bool get isFinished => completedFiles + failedFiles >= totalFiles;

  /// Number of files remaining to process
  int get remainingFiles => totalFiles - completedFiles - failedFiles;

  /// Number of files successfully completed
  int get successCount => completedFiles;

  /// Overall success rate (0.0 - 1.0)
  double get successRate {
    final processed = completedFiles + failedFiles;
    if (processed == 0) return 0.0;
    return completedFiles / processed;
  }

  BatchRenderProgress copyWith({
    int? totalFiles,
    int? completedFiles,
    int? failedFiles,
    int? currentFileIndex,
    String? currentFileName,
    bool clearCurrentFileName = false,
    double? currentFileProgress,
    double? overallProgress,
    Duration? estimatedTimeRemaining,
    bool clearEstimate = false,
    List<String>? completedFileNames,
    Map<String, String>? errors,
  }) {
    return BatchRenderProgress(
      totalFiles: totalFiles ?? this.totalFiles,
      completedFiles: completedFiles ?? this.completedFiles,
      failedFiles: failedFiles ?? this.failedFiles,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      currentFileName: clearCurrentFileName
          ? null
          : (currentFileName ?? this.currentFileName),
      currentFileProgress: currentFileProgress ?? this.currentFileProgress,
      overallProgress: overallProgress ?? this.overallProgress,
      estimatedTimeRemaining: clearEstimate
          ? null
          : (estimatedTimeRemaining ?? this.estimatedTimeRemaining),
      completedFileNames: completedFileNames ?? this.completedFileNames,
      errors: errors ?? this.errors,
    );
  }

  /// Create initial progress for a batch
  factory BatchRenderProgress.initial(int totalFiles) {
    return BatchRenderProgress(
      totalFiles: totalFiles,
      completedFiles: 0,
      failedFiles: 0,
      currentFileIndex: -1,
      overallProgress: 0.0,
    );
  }

  /// Create completed progress
  factory BatchRenderProgress.completed({
    required int totalFiles,
    required int completedFiles,
    required int failedFiles,
    required List<String> completedFileNames,
    required Map<String, String> errors,
  }) {
    return BatchRenderProgress(
      totalFiles: totalFiles,
      completedFiles: completedFiles,
      failedFiles: failedFiles,
      currentFileIndex: -1,
      overallProgress: 1.0,
      completedFileNames: completedFileNames,
      errors: errors,
    );
  }
}
