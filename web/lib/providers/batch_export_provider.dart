import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/domain/entities/batch_render_progress.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';
import 'package:slowverb_web/services/logger_service.dart';
import 'package:uuid/uuid.dart';

/// Status of batch export operation
enum BatchExportStatus { idle, running, paused, completed, error }

/// File queued for batch processing with metadata
class BatchQueuedFile {
  final String fileId;
  final String fileName;
  final Uint8List bytes;
  final AudioMetadata metadata;

  const BatchQueuedFile({
    required this.fileId,
    required this.fileName,
    required this.bytes,
    required this.metadata,
  });

  /// Returns true if this file's source format is lossless
  bool get isLossless => metadata.isLossless;
}

/// State for batch export operations
class BatchExportState {
  final List<BatchQueuedFile> queuedFiles;
  final String selectedFormat;
  final int mp3Bitrate;
  final int aacBitrate;
  final int flacCompressionLevel;
  final EffectPreset selectedPreset;
  final BatchExportStatus status;
  final BatchRenderProgress? progress;
  final String? errorMessage;

  const BatchExportState({
    this.queuedFiles = const [],
    this.selectedFormat = 'mp3',
    this.mp3Bitrate = 320,
    this.aacBitrate = 256,
    this.flacCompressionLevel = 8,
    required this.selectedPreset,
    this.status = BatchExportStatus.idle,
    this.progress,
    this.errorMessage,
  });

  /// True if ALL queued files have lossless source format
  bool get allFilesLossless {
    if (queuedFiles.isEmpty) return false;
    return queuedFiles.every((file) => file.isLossless);
  }

  /// True if FLAC export option should be enabled
  bool get isFlacEnabled => allFilesLossless && queuedFiles.isNotEmpty;

  /// True if batch can be started
  bool get canStart =>
      queuedFiles.isNotEmpty && status == BatchExportStatus.idle;

  /// File count helper
  int get fileCount => queuedFiles.length;

  BatchExportState copyWith({
    List<BatchQueuedFile>? queuedFiles,
    String? selectedFormat,
    int? mp3Bitrate,
    int? aacBitrate,
    int? flacCompressionLevel,
    EffectPreset? selectedPreset,
    BatchExportStatus? status,
    BatchRenderProgress? progress,
    bool clearProgress = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BatchExportState(
      queuedFiles: queuedFiles ?? this.queuedFiles,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      mp3Bitrate: mp3Bitrate ?? this.mp3Bitrate,
      aacBitrate: aacBitrate ?? this.aacBitrate,
      flacCompressionLevel: flacCompressionLevel ?? this.flacCompressionLevel,
      selectedPreset: selectedPreset ?? this.selectedPreset,
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Batch export state notifier
class BatchExportNotifier extends StateNotifier<BatchExportState> {
  final Ref _ref;
  StreamSubscription<BatchRenderProgress>? _batchSubscription;
  static const _log = SlowverbLogger('BatchExport');

  BatchExportNotifier(this._ref)
    : super(BatchExportState(selectedPreset: Presets.slowedReverb));

  /// Add files to the batch queue (probes each file for metadata)
  Future<void> addFiles(
    List<({String fileName, Uint8List bytes})> files,
  ) async {
    if (state.status != BatchExportStatus.idle) {
      throw StateError('Cannot add files while batch is running');
    }

    final engine = _ref.read(audioEngineProvider);
    final newFiles = <BatchQueuedFile>[];

    for (final file in files) {
      final fileId = 'batch-${const Uuid().v4()}';

      try {
        // Probe file to get metadata
        final metadata = await engine.loadSource(
          fileId: fileId,
          filename: file.fileName,
          bytes: file.bytes,
        );

        newFiles.add(
          BatchQueuedFile(
            fileId: fileId,
            fileName: file.fileName,
            bytes: file.bytes,
            metadata: metadata,
          ),
        );
      } catch (e) {
        _log.warning('Failed to load ${file.fileName}', e);
      }
    }

    // Enforce 50 file limit
    final combined = [...state.queuedFiles, ...newFiles];
    if (combined.length > 50) {
      state = state.copyWith(
        errorMessage:
            'Maximum 50 files allowed. Only added first ${50 - state.queuedFiles.length} files.',
      );
      state = state.copyWith(queuedFiles: combined.take(50).toList());
    } else {
      state = state.copyWith(queuedFiles: combined, clearError: true);
    }

    // If selecting FLAC and new files break lossless requirement, switch to MP3
    if (state.selectedFormat == 'flac' && !state.isFlacEnabled) {
      state = state.copyWith(selectedFormat: 'mp3');
    }
  }

  /// Remove a file from the queue
  void removeFile(String fileId) {
    if (state.status != BatchExportStatus.idle) {
      throw StateError('Cannot remove files while batch is running');
    }

    final newFiles = state.queuedFiles
        .where((f) => f.fileId != fileId)
        .toList();
    state = state.copyWith(queuedFiles: newFiles);

    // If FLAC is now eligible after removal, keep current format
    // If FLAC was selected but now not eligible, switch to MP3
    if (state.selectedFormat == 'flac' && !state.isFlacEnabled) {
      state = state.copyWith(selectedFormat: 'mp3');
    }
  }

  /// Clear all files from queue
  void clearQueue() {
    if (state.status != BatchExportStatus.idle) {
      throw StateError('Cannot clear queue while batch is running');
    }

    state = state.copyWith(
      queuedFiles: [],
      clearProgress: true,
      clearError: true,
    );
  }

  /// Update export format
  void setFormat(String format) {
    // Prevent selecting FLAC if not all files are lossless
    if (format == 'flac' && !state.isFlacEnabled) {
      return;
    }
    state = state.copyWith(selectedFormat: format);
  }

  /// Update MP3 bitrate
  void setMp3Bitrate(int bitrate) {
    state = state.copyWith(mp3Bitrate: bitrate);
  }

  /// Update AAC bitrate
  void setAacBitrate(int bitrate) {
    state = state.copyWith(aacBitrate: bitrate);
  }

  /// Update FLAC compression level
  void setFlacCompressionLevel(int level) {
    state = state.copyWith(flacCompressionLevel: level);
  }

  /// Update selected preset
  void setPreset(EffectPreset preset) {
    state = state.copyWith(selectedPreset: preset);
  }

  /// Start batch processing
  Future<void> startBatch() async {
    if (!state.canStart) {
      throw StateError('Cannot start batch: no files or already running');
    }

    state = state.copyWith(status: BatchExportStatus.running, clearError: true);

    final engine = _ref.read(audioEngineProvider);

    // Build export options
    final options = _buildExportOptions();

    // Convert queued files to BatchInputFile format
    final batchFiles = state.queuedFiles
        .map(
          (f) => BatchInputFile(
            fileId: f.fileId,
            fileName: f.fileName,
            bytes: f.bytes,
          ),
        )
        .toList();

    try {
      final stream = engine.renderBatch(
        files: batchFiles,
        defaultPreset: state.selectedPreset,
        options: options,
      );

      _batchSubscription = stream.listen(
        (progress) {
          state = state.copyWith(progress: progress);

          if (progress.isFinished) {
            state = state.copyWith(status: BatchExportStatus.completed);
          }
        },
        onError: (error) {
          state = state.copyWith(
            status: BatchExportStatus.error,
            errorMessage: 'Batch failed: $error',
          );
        },
        onDone: () {
          if (state.status == BatchExportStatus.running) {
            state = state.copyWith(status: BatchExportStatus.completed);
          }
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: BatchExportStatus.error,
        errorMessage: 'Failed to start batch: $e',
      );
    }
  }

  /// Pause batch processing
  Future<void> pauseBatch() async {
    if (state.status != BatchExportStatus.running) return;

    final engine = _ref.read(audioEngineProvider);
    await engine.pauseBatch();
    state = state.copyWith(status: BatchExportStatus.paused);
  }

  /// Resume batch processing
  Future<void> resumeBatch() async {
    if (state.status != BatchExportStatus.paused) return;

    final engine = _ref.read(audioEngineProvider);
    await engine.resumeBatch();
    state = state.copyWith(status: BatchExportStatus.running);
  }

  /// Cancel batch processing
  Future<void> cancelBatch() async {
    await _batchSubscription?.cancel();
    _batchSubscription = null;

    final engine = _ref.read(audioEngineProvider);
    await engine.cancelBatch();

    state = state.copyWith(status: BatchExportStatus.idle);
  }

  /// Reset to initial state
  void reset() {
    _batchSubscription?.cancel();
    _batchSubscription = null;

    state = BatchExportState(selectedPreset: state.selectedPreset);
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  ExportOptions _buildExportOptions() {
    switch (state.selectedFormat) {
      case 'mp3':
        return ExportOptions(format: 'mp3', bitrateKbps: state.mp3Bitrate);
      case 'aac':
        return ExportOptions(format: 'aac', bitrateKbps: state.aacBitrate);
      case 'flac':
        return ExportOptions(
          format: 'flac',
          compressionLevel: state.flacCompressionLevel,
        );
      case 'wav':
      default:
        return const ExportOptions(format: 'wav');
    }
  }

  @override
  void dispose() {
    _batchSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for batch export state
final batchExportProvider =
    StateNotifierProvider<BatchExportNotifier, BatchExportState>((ref) {
      return BatchExportNotifier(ref);
    });
