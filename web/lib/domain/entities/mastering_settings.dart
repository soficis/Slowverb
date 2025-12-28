import 'dart:typed_data';

import 'package:slowverb_web/domain/repositories/audio_engine.dart';

/// Status of overall mastering operation
enum MasteringStatus {
  idle,
  analyzing,
  mastering,
  encoding,
  zipping,
  completed,
  error,
}

/// Status of individual file in queue
enum FileProcessStatus { pending, processing, completed, failed }

/// Mastering algorithm parameters
class MasteringSettings {
  final double targetLufs;
  final double bassPreservation;
  final int mode;

  const MasteringSettings({
    this.targetLufs = -14.0,
    this.bassPreservation = 0.5,
    this.mode = 3, // Level 3 (Standard) - Level 5 available as opt-in
  });

  MasteringSettings copyWith({
    double? targetLufs,
    double? bassPreservation,
    int? mode,
  }) {
    return MasteringSettings(
      targetLufs: targetLufs ?? this.targetLufs,
      bassPreservation: bassPreservation ?? this.bassPreservation,
      mode: mode ?? this.mode,
    );
  }

  /// Clamp values to valid ranges
  static MasteringSettings validated({
    required double targetLufs,
    required double bassPreservation,
    int mode = 3, // Level 3 (Standard) - Level 5 available as opt-in
  }) {
    return MasteringSettings(
      targetLufs: targetLufs.clamp(-24.0, -6.0),
      bassPreservation: bassPreservation.clamp(0.0, 1.0),
      mode: mode,
    );
  }
}

/// File queued for mastering with metadata
class MasteringQueueFile {
  final String fileId;
  final String fileName;
  final Uint8List bytes;
  final AudioMetadata metadata;
  final FileProcessStatus status;
  final String? outputFileName;
  final Uint8List? resultBytes;

  const MasteringQueueFile({
    required this.fileId,
    required this.fileName,
    required this.bytes,
    required this.metadata,
    this.status = FileProcessStatus.pending,
    this.outputFileName,
    this.resultBytes,
  });

  /// True if source format is lossless
  bool get isLossless => metadata.isLossless;

  MasteringQueueFile copyWith({
    FileProcessStatus? status,
    String? outputFileName,
    Uint8List? resultBytes,
    bool clearResult = false,
  }) {
    return MasteringQueueFile(
      fileId: fileId,
      fileName: fileName,
      bytes: bytes,
      metadata: metadata,
      status: status ?? this.status,
      outputFileName: outputFileName ?? this.outputFileName,
      resultBytes: clearResult ? null : (resultBytes ?? this.resultBytes),
    );
  }
}

/// Progress tracking for mastering operation
class MasteringProgress {
  final int currentFileIndex;
  final int totalFiles;
  final String currentFileName;
  final double percent;
  final String stage;
  final Duration? estimatedTimeRemaining;

  const MasteringProgress({
    required this.currentFileIndex,
    required this.totalFiles,
    required this.currentFileName,
    required this.percent,
    required this.stage,
    this.estimatedTimeRemaining,
  });

  bool get isFinished => currentFileIndex >= totalFiles;

  double get overallProgress {
    if (totalFiles == 0) return 0.0;
    return ((currentFileIndex - 1) + percent) / totalFiles;
  }

  MasteringProgress copyWith({
    int? currentFileIndex,
    int? totalFiles,
    String? currentFileName,
    double? percent,
    String? stage,
    Duration? estimatedTimeRemaining,
    bool clearEstimate = false,
  }) {
    return MasteringProgress(
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      totalFiles: totalFiles ?? this.totalFiles,
      currentFileName: currentFileName ?? this.currentFileName,
      percent: percent ?? this.percent,
      stage: stage ?? this.stage,
      estimatedTimeRemaining: clearEstimate
          ? null
          : (estimatedTimeRemaining ?? this.estimatedTimeRemaining),
    );
  }

  factory MasteringProgress.initial(int totalFiles) {
    return MasteringProgress(
      currentFileIndex: 0,
      totalFiles: totalFiles,
      currentFileName: '',
      percent: 0.0,
      stage: 'Preparing',
    );
  }
}
