import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/domain/entities/mastering_settings.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';
import 'package:slowverb_web/services/logger_service.dart';
import 'package:slowverb_web/services/phase_limiter_service.dart';
import 'package:slowverb_web/services/worker_pool_service.dart';
import 'package:slowverb_web/services/zip_export_service.dart';
import 'package:uuid/uuid.dart';

/// State for mastering operations
class MasteringState {
  final List<MasteringQueueFile> queuedFiles;
  final MasteringSettings settings;
  final String selectedFormat;
  final int mp3Bitrate;
  final int aacBitrate;
  final int flacCompressionLevel;
  final bool zipExportEnabled;
  final MasteringStatus status;
  final MasteringProgress? progress;
  final String? errorMessage;
  final List<Uint8List> completedResults;
  final Uint8List? zipResult;

  const MasteringState({
    this.queuedFiles = const [],
    this.settings = const MasteringSettings(),
    this.selectedFormat = 'mp3',
    this.mp3Bitrate = 320,
    this.aacBitrate = 256,
    this.flacCompressionLevel = 8,
    this.zipExportEnabled = false,
    this.status = MasteringStatus.idle,
    this.progress,
    this.errorMessage,
    this.completedResults = const [],
    this.zipResult,
  });

  /// True if single file mode
  bool get isSingleFile => queuedFiles.length == 1;

  /// True if batch mode
  bool get isBatchMode => queuedFiles.length > 1;

  /// True if all files are lossless
  bool get allFilesLossless {
    if (queuedFiles.isEmpty) return false;
    return queuedFiles.every((f) => f.isLossless);
  }

  /// True if FLAC export should be enabled
  bool get isFlacEnabled => allFilesLossless && queuedFiles.isNotEmpty;

  /// True if mastering can start
  bool get canStart => queuedFiles.isNotEmpty && status == MasteringStatus.idle;

  /// True if ZIP option should be shown
  bool get showZipOption => isBatchMode;

  int get fileCount => queuedFiles.length;

  MasteringState copyWith({
    List<MasteringQueueFile>? queuedFiles,
    MasteringSettings? settings,
    String? selectedFormat,
    int? mp3Bitrate,
    int? aacBitrate,
    int? flacCompressionLevel,
    bool? zipExportEnabled,
    MasteringStatus? status,
    MasteringProgress? progress,
    bool clearProgress = false,
    String? errorMessage,
    bool clearError = false,
    List<Uint8List>? completedResults,
    Uint8List? zipResult,
    bool clearZip = false,
  }) {
    return MasteringState(
      queuedFiles: queuedFiles ?? this.queuedFiles,
      settings: settings ?? this.settings,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      mp3Bitrate: mp3Bitrate ?? this.mp3Bitrate,
      aacBitrate: aacBitrate ?? this.aacBitrate,
      flacCompressionLevel: flacCompressionLevel ?? this.flacCompressionLevel,
      zipExportEnabled: zipExportEnabled ?? this.zipExportEnabled,
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      completedResults: completedResults ?? this.completedResults,
      zipResult: clearZip ? null : (zipResult ?? this.zipResult),
    );
  }
}

/// Mastering state notifier
///
/// Supports parallel batch processing when multiple files are queued.
/// Uses [WorkerPoolService] for concurrent processing (up to 3 files).
class MasteringNotifier extends StateNotifier<MasteringState> {
  final Ref _ref;
  final PhaseLimiterService _phaseLimiter = PhaseLimiterService();
  final ZipExportService _zipService = ZipExportService();
  final WorkerPoolService _workerPool = WorkerPoolService();
  static const _log = SlowverbLogger('Mastering');
  bool _isCancelled = false;

  MasteringNotifier(this._ref) : super(const MasteringState());

  /// Import a single file
  Future<void> importFile(String fileName, Uint8List bytes) async {
    await addFiles([(fileName: fileName, bytes: bytes)]);
  }

  /// Add files to the mastering queue
  Future<void> addFiles(
    List<({String fileName, Uint8List bytes})> files,
  ) async {
    if (state.status != MasteringStatus.idle) {
      throw StateError('Cannot add files while mastering is running');
    }

    final engine = _ref.read(audioEngineProvider);
    final newFiles = <MasteringQueueFile>[];

    for (final file in files) {
      final fileId = 'master-${const Uuid().v4()}';

      try {
        final metadata = await engine.loadSource(
          fileId: fileId,
          filename: file.fileName,
          bytes: file.bytes,
        );

        newFiles.add(
          MasteringQueueFile(
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

    // If FLAC selected but sources not all lossless, switch to MP3
    if (state.selectedFormat == 'flac' && !state.isFlacEnabled) {
      state = state.copyWith(selectedFormat: 'mp3');
    }
  }

  /// Remove a file from the queue
  void removeFile(String fileId) {
    if (state.status != MasteringStatus.idle) {
      throw StateError('Cannot remove files while mastering is running');
    }

    final newFiles = state.queuedFiles
        .where((f) => f.fileId != fileId)
        .toList();
    state = state.copyWith(queuedFiles: newFiles);

    if (state.selectedFormat == 'flac' && !state.isFlacEnabled) {
      state = state.copyWith(selectedFormat: 'mp3');
    }
  }

  /// Clear all files from queue
  void clearQueue() {
    if (state.status != MasteringStatus.idle) {
      throw StateError('Cannot clear queue while mastering is running');
    }

    state = state.copyWith(
      queuedFiles: [],
      clearProgress: true,
      clearError: true,
      completedResults: [],
      clearZip: true,
    );
  }

  /// Update target LUFS (-24 to -6)
  void setTargetLufs(double value) {
    state = state.copyWith(
      settings: state.settings.copyWith(targetLufs: value.clamp(-24.0, -6.0)),
    );
  }

  /// Update bass preservation (0.0 to 1.0)
  void setBassPreservation(double value) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        bassPreservation: value.clamp(0.0, 1.0),
      ),
    );
  }

  /// Update export format
  void setFormat(String format) {
    if (format == 'flac' && !state.isFlacEnabled) return;
    state = state.copyWith(selectedFormat: format);
  }

  /// Update mastering mode (3=Standard, 5=Pro)
  void setMode(int mode) {
    state = state.copyWith(settings: state.settings.copyWith(mode: mode));
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

  /// Enable ZIP export for batch
  void enableZipExport() {
    state = state.copyWith(zipExportEnabled: true);
  }

  /// Disable ZIP export
  void disableZipExport() {
    state = state.copyWith(zipExportEnabled: false);
  }

  /// Start mastering all queued files
  ///
  /// NOTE: Full audio pipeline integration (decode → master → encode) requires
  /// adding decodeToFloatPCM and encodeFromFloatPCM methods to WasmAudioEngine.
  /// This implementation demonstrates state management and PhaseLimiter integration.
  Future<void> startMastering() async {
    if (!state.canStart) {
      throw StateError('Cannot start: no files or already running');
    }

    _isCancelled = false;
    final engine = _ref.read(audioEngineProvider);
    state = state.copyWith(
      status: MasteringStatus.analyzing,
      clearError: true,
      completedResults: [],
      clearZip: true,
    );

    try {
      await _phaseLimiter.initialize();

      final totalFiles = state.queuedFiles.length;
      final results = <Uint8List>[];

      for (var i = 0; i < totalFiles; i++) {
        if (_isCancelled) break;

        final file = state.queuedFiles[i];
        state = state.copyWith(
          progress: MasteringProgress(
            currentFileIndex: i + 1,
            totalFiles: totalFiles,
            currentFileName: file.fileName,
            percent: 0.0,
            stage: 'Decoding',
          ),
        );

        _updateFileStatus(file.fileId, FileProcessStatus.processing);

        // 1. Decode to PCM
        state = state.copyWith(status: MasteringStatus.analyzing);
        final decoded = await engine.decodeToFloatPCM(file.fileId);

        if (_isCancelled) break;

        // 2. Process with PhaseLimiter
        state = state.copyWith(
          status: MasteringStatus.mastering,
          progress: state.progress?.copyWith(stage: 'Mastering', percent: 0.3),
        );

        final mastered = await _phaseLimiter.process(
          leftChannel: decoded.left,
          rightChannel: decoded.right,
          sampleRate: decoded.sampleRate,
          config: PhaseLimiterConfig(
            targetLufs: state.settings.targetLufs,
            bassPreservation: state.settings.bassPreservation,
            mode: state.settings.mode,
          ),
        );

        if (_isCancelled) break;

        // 3. Encode back to original or chosen format
        state = state.copyWith(
          status: MasteringStatus.encoding,
          progress: state.progress?.copyWith(stage: 'Encoding', percent: 0.7),
        );

        final encoded = await engine.encodeFromFloatPCM(
          left: mastered.left,
          right: mastered.right,
          sampleRate: decoded.sampleRate,
          format: state.selectedFormat,
          bitrateKbps: state.selectedFormat == 'mp3'
              ? state.mp3Bitrate
              : (state.selectedFormat == 'aac' ? state.aacBitrate : null),
        );

        results.add(encoded);
        _updateFileStatus(file.fileId, FileProcessStatus.completed);
        state = state.copyWith(
          progress: state.progress?.copyWith(percent: 1.0),
          completedResults: List.from(results), // Create a new list for state
        );
      }

      if (!_isCancelled) {
        if (state.isBatchMode && state.zipExportEnabled) {
          state = state.copyWith(
            status: MasteringStatus.zipping,
            progress: state.progress?.copyWith(stage: 'Creating ZIP'),
          );

          final zipMap = <String, Uint8List>{};
          for (var i = 0; i < state.queuedFiles.length; i++) {
            final file = state.queuedFiles[i];
            if (i < results.length) {
              zipMap[file.fileName] = results[i];
            }
          }

          final zipBytes = await _zipService.createZip(zipMap);
          state = state.copyWith(zipResult: zipBytes);
        }
        state = state.copyWith(status: MasteringStatus.completed);
      }
    } catch (e) {
      state = state.copyWith(
        status: MasteringStatus.error,
        errorMessage: 'Mastering failed: $e',
      );
    }
  }

  /// Cancel mastering operation
  void cancelMastering() {
    _isCancelled = true;
    state = state.copyWith(status: MasteringStatus.idle, clearProgress: true);
  }

  /// Force stop all mastering operations by terminating the worker
  ///
  /// This is a hard reset that immediately kills the Web Worker,
  /// stopping any in-progress WASM operations. Use as a last resort.
  Future<void> forceStopAllMastering() async {
    _isCancelled = true;
    // Terminate the worker to immediately stop all processing
    _phaseLimiter.dispose();
    // Reset state
    state = state.copyWith(
      status: MasteringStatus.idle,
      clearProgress: true,
      clearError: true,
    );
    // Reinitialize for next use
    await _phaseLimiter.initialize();
  }

  /// Reset to initial state
  void reset() {
    _isCancelled = true;
    state = const MasteringState();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _updateFileStatus(String fileId, FileProcessStatus status) {
    final updatedFiles = state.queuedFiles.map((f) {
      if (f.fileId == fileId) {
        return f.copyWith(status: status);
      }
      return f;
    }).toList();
    state = state.copyWith(queuedFiles: updatedFiles);
  }

  @override
  void dispose() {
    _phaseLimiter.dispose();
    _workerPool.dispose();
    super.dispose();
  }
}

/// Provider for mastering state
final masteringProvider =
    StateNotifierProvider<MasteringNotifier, MasteringState>((ref) {
      return MasteringNotifier(ref);
    });
