import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:slowverb_web/domain/entities/batch_render_progress.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/engine/engine_js_interop.dart';
import 'package:web/web.dart' as web;
part 'wasm_audio_engine_impl.dart';

class WasmAudioEngine implements AudioEngine {
  final Map<String, StreamController<RenderProgress>> _progressControllers = {};
  final Map<String, RenderResult> _renderResults = {};
  final Map<String, Uint8List> _loadedFiles = {};

  final Set<String> _activeBlobUrls = {};
  String? _currentPreviewUrl;

  bool _isInitialized = false;
  bool _progressHandlerInstalled = false;
  bool _logHandlerInstalled = false;

  void Function(double progress, String stage)? _previewProgressCallback;
  void Function(String message)? _warningCallback;
  String? _currentPreviewJobId;

  void setPreviewProgressCallback(void Function(double, String)? callback) {
    _previewProgressCallback = callback;
  }

  void setWarningCallback(void Function(String)? callback) {
    _warningCallback = callback;
  }

  @override
  bool get isReady => _isInitialized;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
    _installProgressHandler();
    _installLogHandler();
  }

  @override
  Future<MemoryPreflightResult> checkMemoryPreflight(int fileSizeBytes) async {
    const warningThresholdMb = 100;
    const blockThresholdMb = 200;
    final sizeMb = fileSizeBytes / (1024 * 1024);

    if (sizeMb > blockThresholdMb) {
      return MemoryPreflightResult.blocked(
        'File too large (${sizeMb.toStringAsFixed(1)} MB). Maximum is $blockThresholdMb MB.',
      );
    }

    if (sizeMb > warningThresholdMb) {
      return MemoryPreflightResult.warning(
        'Large file (${sizeMb.toStringAsFixed(1)} MB) may cause slow performance or browser crashes.',
      );
    }

    return const MemoryPreflightResult.ok();
  }

  @override
  Future<AudioMetadata> loadSource({
    required String fileId,
    required String filename,
    required Uint8List bytes,
  }) => loadSourceImpl(this, fileId: fileId, filename: filename, bytes: bytes);

  @override
  Future<({Float32List left, Float32List right, int sampleRate})>
  decodeToFloatPCM(String fileId) => decodeToFloatPcmImpl(this, fileId);

  @override
  Future<Uint8List> encodeFromFloatPCM({
    required Float32List left,
    required Float32List right,
    required int sampleRate,
    required String format,
    int? bitrateKbps,
  }) => encodeFromFloatPcmImpl(
    this,
    left: left,
    right: right,
    sampleRate: sampleRate,
    format: format,
    bitrateKbps: bitrateKbps,
  );

  /// Resume the audio context to allow Tone.js reverb IR generation.
  ///
  /// This must be called after a user gesture (e.g., clicking play button)
  /// to comply with browser autoplay policies.
  @override
  Future<bool> resumeAudioContext() async {
    return BridgeInterop.resumeAudioContext();
  }

  @override
  Future<Float32List> getWaveform(String fileId, {int targetSamples = 1000}) =>
      getWaveformImpl(this, fileId, targetSamples: targetSamples);

  @override
  Future<Uri> renderPreview({
    required String fileId,
    required EffectConfig config,
    Duration? startAt,
    Duration? duration,
  }) => renderPreviewImpl(
    this,
    fileId: fileId,
    config: config,
    startAt: startAt,
    duration: duration,
  );

  @override
  Future<RenderJobId> startRender({
    required String fileId,
    required EffectConfig config,
    required ExportOptions options,
  }) => startRenderImpl(this, fileId: fileId, config: config, options: options);

  /// Internal method that performs the actual render.
  /// Called asynchronously from startRender so the jobId can be returned immediately.
  Future<void> _performRender({
    required RenderJobId jobId,
    required String fileId,
    required EffectConfig config,
    required ExportOptions options,
    required StreamController<RenderProgress> controller,
  }) => performRenderImpl(
    this,
    jobId: jobId,
    fileId: fileId,
    config: config,
    options: options,
    controller: controller,
  );

  @override
  Stream<RenderProgress> watchProgress(RenderJobId jobId) =>
      watchProgressImpl(this, jobId);

  @override
  Future<RenderResult> getResult(RenderJobId jobId) =>
      getResultImpl(this, jobId);

  @override
  Future<void> cancelRender(RenderJobId jobId) => cancelRenderImpl(this, jobId);

  @override
  Future<void> cleanup({String? fileId}) async {
    if (fileId != null) {
      _loadedFiles.remove(fileId);
    }
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    if (_progressHandlerInstalled) {
      BridgeInterop.setProgressHandler(null);
      _progressHandlerInstalled = false;
    }

    // Revoke all blob URLs to prevent memory leaks
    for (final url in _activeBlobUrls) {
      try {
        web.URL.revokeObjectURL(url);
      } catch (error) {
        debugPrint('Engine cleanup failed to revoke blob URL: $error');
      }
    }
    _activeBlobUrls.clear();
    _currentPreviewUrl = null;
    _warningCallback = null;

    // Close all progress controllers
    for (final controller in _progressControllers.values) {
      await controller.close();
    }
    _progressControllers.clear();
    _renderResults.clear();
    _loadedFiles.clear();
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('AudioEngine not initialized. Call initialize() first.');
    }
  }

  // Batch processing state
  bool _batchCancelled = false;
  bool _batchPaused = false;
  void Function(String fileName, Uint8List bytes)? _batchResultCallback;

  @override
  Stream<BatchRenderProgress> renderBatch({
    required List<BatchInputFile> files,
    required EffectPreset defaultPreset,
    required ExportOptions options,
    void Function(String fileName, Uint8List bytes)? onResultReady,
  }) {
    final controller = StreamController<BatchRenderProgress>.broadcast();

    // Reset status flags
    _batchCancelled = false;
    _batchPaused = false;
    _batchResultCallback = onResultReady;

    // Start processing in the background
    _runParallelBatch(files, defaultPreset, options, controller);

    return controller.stream;
  }

  Future<void> _runParallelBatch(
    List<BatchInputFile> files,
    EffectPreset defaultPreset,
    ExportOptions options,
    StreamController<BatchRenderProgress> controller,
  ) => runParallelBatchImpl(this, files, defaultPreset, options, controller);

  @override
  Future<void> cancelBatch() async {
    _batchCancelled = true;
  }

  @override
  Future<void> pauseBatch() async {
    _batchPaused = true;
  }

  @override
  Future<void> resumeBatch() async {
    _batchPaused = false;
  }

  void _triggerDownload(Uint8List bytes, String fileName, String format) =>
      triggerDownloadImpl(this, bytes, fileName, format);

  String _mimeTypeForFormat(String format) => mimeTypeForFormatImpl(format);

  String _removeExtension(String fileName) => removeExtensionImpl(fileName);

  Duration? _estimateTimeRemaining(
    DateTime startTime,
    int completedCount,
    int totalCount,
  ) => estimateTimeRemainingImpl(startTime, completedCount, totalCount);

  Uint8List _requireFileBytes(String fileId) {
    final bytes = _loadedFiles[fileId];
    if (bytes == null) {
      throw StateError(
        'File bytes missing for $fileId. Call loadSource first.',
      );
    }
    return bytes;
  }

  Duration? _durationFromMs(int? value) {
    if (value == null) return null;
    return Duration(milliseconds: value);
  }

  Map<String, Object?> _toDspSpec(EffectConfig config) => toDspSpecImpl(config);

  void _installProgressHandler() => installProgressHandlerImpl(this);

  void _installLogHandler() => installLogHandlerImpl(this);

  T _getProperty<T>(JSObject object, String property) =>
      getPropertyImpl<T>(object, property);
}
