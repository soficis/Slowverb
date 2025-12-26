import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:slowverb_web/domain/entities/batch_render_progress.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/engine/engine_js_interop.dart';
import 'package:web/web.dart' as web;

/// Web implementation of AudioEngine using FFmpeg WASM
///
/// Communicates with audio_worker.js Web Worker for all audio processing.
/// Keeps UI thread responsive during heavy rendering operations.
class WasmAudioEngine implements AudioEngine {
  final Map<String, StreamController<RenderProgress>> _progressControllers = {};
  final Map<String, RenderResult> _renderResults = {};
  final Map<String, Uint8List> _loadedFiles = {};

  // Blob URL lifecycle management to prevent memory leaks
  final Set<String> _activeBlobUrls = {};
  String? _currentPreviewUrl;

  bool _isInitialized = false;
  bool _progressHandlerInstalled = false;
  bool _logHandlerInstalled = false;

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
  }) async {
    _ensureInitialized();

    final payload = BridgeInterop.toJsObject({
      'source': {'fileId': fileId, 'filename': filename, 'data': bytes.toJS},
    });

    final response = await BridgeInterop.loadAndProbe(payload);
    final payloadObj = response.getProperty<JSObject>('payload'.toJS);
    _loadedFiles[fileId] = bytes;
    final durationMs = payloadObj
        .getProperty<JSNumber?>('durationMs'.toJS)
        ?.toDartInt;

    return AudioMetadata(
      fileId: _getProperty<String>(payloadObj, 'fileId'),
      filename: filename,
      duration: _durationFromMs(durationMs),
      sampleRate: _getProperty<int>(payloadObj, 'sampleRate'),
      channels: _getProperty<int>(payloadObj, 'channels'),
      format: _getProperty<String>(payloadObj, 'format'),
    );
  }

  @override
  Future<({Float32List left, Float32List right, int sampleRate})>
  decodeToFloatPCM(String fileId) async {
    _ensureInitialized();
    final payload = BridgeInterop.toJsObject({
      'source': {'fileId': fileId, 'data': _requireFileBytes(fileId).toJS},
    });

    final response = await BridgeInterop.decodeToFloatPCM(payload);
    final type = _getProperty<String>(response, 'type');
    if (type != 'decode-pcm-ok') {
      throw StateError('Decode PCM failed: $type');
    }

    final payloadObj = response.getProperty<JSObject>('payload'.toJS);
    final left = payloadObj.getProperty<JSFloat32Array>('left'.toJS).toDart;
    final right = payloadObj.getProperty<JSFloat32Array>('right'.toJS).toDart;
    final sampleRate = payloadObj
        .getProperty<JSNumber>('sampleRate'.toJS)
        .toDartInt;

    return (left: left, right: right, sampleRate: sampleRate);
  }

  @override
  Future<Uint8List> encodeFromFloatPCM({
    required Float32List left,
    required Float32List right,
    required int sampleRate,
    required String format,
    int? bitrateKbps,
  }) async {
    _ensureInitialized();
    final payload = BridgeInterop.toJsObject({
      'left': left.toJS,
      'right': right.toJS,
      'sampleRate': sampleRate,
      'format': format,
      if (bitrateKbps != null) 'bitrateKbps': bitrateKbps,
    });

    final response = await BridgeInterop.encodeFromFloatPCM(payload);
    final type = _getProperty<String>(response, 'type');
    if (type != 'encode-pcm-ok') {
      throw StateError('Encode PCM failed: $type');
    }

    final payloadObj = response.getProperty<JSObject>('payload'.toJS);
    final buffer = payloadObj.getProperty<JSObject>('buffer'.toJS);
    return BridgeInterop.bufferToUint8List(buffer);
  }

  @override
  Future<Float32List> getWaveform(
    String fileId, {
    int targetSamples = 1000,
  }) async {
    _ensureInitialized();

    final payload = BridgeInterop.toJsObject({
      'source': {'fileId': fileId, 'data': _requireFileBytes(fileId).toJS},
      'points': targetSamples,
    });

    final response = await BridgeInterop.waveform(payload);
    final type = _getProperty<String>(response, 'type');
    if (type != 'waveform-ok') {
      throw StateError('Waveform failed: $type');
    }

    final payloadObj = response.getProperty<JSObject>('payload'.toJS);
    final samples = payloadObj.getProperty<JSObject>('samples'.toJS);

    if (samples.isA<JSFloat32Array>()) {
      return (samples as JSFloat32Array).toDart;
    }
    return Float32List(0);
  }

  @override
  Future<Uri> renderPreview({
    required String fileId,
    required EffectConfig config,
    Duration? startAt,
    Duration? duration,
  }) async {
    _ensureInitialized();

    // Revoke previous preview URL to prevent memory leak
    if (_currentPreviewUrl != null) {
      web.URL.revokeObjectURL(_currentPreviewUrl!);
      _activeBlobUrls.remove(_currentPreviewUrl);
      _currentPreviewUrl = null;
    }

    final payload = BridgeInterop.toJsObject({
      'source': {'fileId': fileId, 'data': _requireFileBytes(fileId).toJS},
      'dspSpec': _toDspSpec(config),
      'startSec': (startAt?.inMilliseconds ?? 0) / 1000.0,
      'durationSec': duration != null ? duration.inMilliseconds / 1000.0 : null,
    });

    final response = await BridgeInterop.renderPreview(payload);
    final buffer = response
        .getProperty<JSObject>('payload'.toJS)
        .getProperty<JSObject>('buffer'.toJS);
    final bytes = BridgeInterop.bufferToUint8List(buffer);

    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'audio/mp3'),
    );
    final url = web.URL.createObjectURL(blob);

    // Track blob URL for cleanup
    _currentPreviewUrl = url;
    _activeBlobUrls.add(url);

    return Uri.parse(url);
  }

  @override
  Future<RenderJobId> startRender({
    required String fileId,
    required EffectConfig config,
    required ExportOptions options,
  }) async {
    _ensureInitialized();

    final jobId = RenderJobId('job-${DateTime.now().millisecondsSinceEpoch}');

    // Create progress stream controller
    final controller = StreamController<RenderProgress>.broadcast();
    _progressControllers[jobId.value] = controller;

    controller.add(
      RenderProgress(jobId: jobId, progress: 0.0, stage: 'processing'),
    );

    // Start the render asynchronously - DO NOT await here!
    // This allows the caller to subscribe to progress updates before render completes.
    unawaited(
      _performRender(
        jobId: jobId,
        fileId: fileId,
        config: config,
        options: options,
        controller: controller,
      ),
    );

    return jobId;
  }

  /// Internal method that performs the actual render.
  /// Called asynchronously from startRender so the jobId can be returned immediately.
  Future<void> _performRender({
    required RenderJobId jobId,
    required String fileId,
    required EffectConfig config,
    required ExportOptions options,
    required StreamController<RenderProgress> controller,
  }) async {
    try {
      final payload = BridgeInterop.toJsObject({
        'source': {'fileId': fileId, 'data': _requireFileBytes(fileId).toJS},
        'dspSpec': _toDspSpec(config),
        'format': options.format,
        'bitrateKbps': options.bitrateKbps ?? 192,
        'jobId': jobId.value,
      });

      final response = await BridgeInterop.renderFull(payload);
      final payloadObj = response.getProperty<JSObject>('payload'.toJS);
      final buffer = payloadObj.getProperty<JSObject>('outputBuffer'.toJS);
      final bytes = BridgeInterop.bufferToUint8List(buffer);

      _renderResults[jobId.value] = RenderResult(
        success: true,
        outputBytes: bytes,
      );

      controller.add(
        RenderProgress(jobId: jobId, progress: 1.0, stage: 'complete'),
      );
    } catch (e) {
      final message = e.toString();
      _renderResults[jobId.value] = RenderResult(
        success: false,
        errorMessage: message,
      );
      controller.addError(Exception(message));
    } finally {
      controller.close();
      _progressControllers.remove(jobId.value);
    }
  }

  @override
  Stream<RenderProgress> watchProgress(RenderJobId jobId) {
    final controller = _progressControllers[jobId.value];
    if (controller == null) {
      throw StateError('No render job found with ID: $jobId');
    }
    return controller.stream;
  }

  @override
  Future<RenderResult> getResult(RenderJobId jobId) async {
    final result = _renderResults.remove(jobId.value);
    final controller = _progressControllers.remove(jobId.value);
    await controller?.close();

    if (result != null) {
      return result;
    }

    return const RenderResult(
      success: false,
      errorMessage: 'No render result available for this job.',
    );
  }

  @override
  Future<void> cancelRender(RenderJobId jobId) async {
    await BridgeInterop.cancel(jobId.value);
    final controller = _progressControllers.remove(jobId.value);
    await controller?.close();
    _renderResults.remove(jobId.value);
  }

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
      } catch (_) {
        // Best-effort cleanup - ignore errors
      }
    }
    _activeBlobUrls.clear();
    _currentPreviewUrl = null;

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

  @override
  Stream<BatchRenderProgress> renderBatch({
    required List<BatchInputFile> files,
    required EffectPreset defaultPreset,
    required ExportOptions options,
  }) {
    final controller = StreamController<BatchRenderProgress>.broadcast();

    // Reset status flags
    _batchCancelled = false;
    _batchPaused = false;

    // Start processing in the background
    _runParallelBatch(files, defaultPreset, options, controller);

    return controller.stream;
  }

  Future<void> _runParallelBatch(
    List<BatchInputFile> files,
    EffectPreset defaultPreset,
    ExportOptions options,
    StreamController<BatchRenderProgress> controller,
  ) async {
    final startTime = DateTime.now();
    int completedCount = 0;
    int failedCount = 0;
    final List<String> completedFileNames = [];
    final Map<String, String> errors = {};

    controller.add(BatchRenderProgress.initial(files.length));

    const int maxConcurrency = 3;
    final int concurrency =
        files.length < maxConcurrency ? files.length : maxConcurrency;
    int nextIndex = 0;
    final activeJobs = <int, Future<void>>{};

    Future<void> processFile(int index) async {
      final file = files[index];
      final preset = file.presetOverride ?? defaultPreset;

      try {
        await loadSource(
          fileId: file.fileId,
          filename: file.fileName,
          bytes: file.bytes,
        );

        final config = EffectConfig.fromParams(preset.id, preset.parameters);
        final jobId = await startRender(
          fileId: file.fileId,
          config: config,
          options: options,
        );

        await for (final progress in watchProgress(jobId)) {
          if (_batchCancelled) {
            await cancelRender(jobId);
            break;
          }

          // Report progress for this specific file
          controller.add(
            BatchRenderProgress(
              totalFiles: files.length,
              completedFiles: completedCount,
              failedFiles: failedCount,
              currentFileIndex: index,
              currentFileName: file.fileName,
              currentFileProgress: progress.progress,
              overallProgress:
                  (completedCount + (progress.progress / concurrency)) /
                  files.length, // Rough estimate
              estimatedTimeRemaining: _estimateTimeRemaining(
                startTime,
                completedCount,
                files.length,
              ),
              completedFileNames: completedFileNames,
              errors: errors,
            ),
          );
        }

        if (_batchCancelled) return;

        final result = await getResult(jobId);
        if (result.success && result.outputBytes != null) {
          _triggerDownload(result.outputBytes!, file.fileName, options.format);
          completedCount++;
          completedFileNames.add(file.fileName);
        } else {
          failedCount++;
          errors[file.fileName] = result.errorMessage ?? 'Unknown error';
        }

        await cleanup(fileId: file.fileId);
      } catch (e) {
        debugPrint('[Batch] Error processing ${file.fileName}: $e');
        failedCount++;
        errors[file.fileName] = e.toString();
        try {
          await cleanup(fileId: file.fileId);
        } catch (_) {}
      }
    }

    while (nextIndex < files.length || activeJobs.isNotEmpty) {
      if (_batchCancelled) break;

      // Handle pausing
      while (_batchPaused && !_batchCancelled) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Start new tasks if we have capacity
      while (nextIndex < files.length && activeJobs.length < concurrency) {
        final index = nextIndex++;
        final job = processFile(index);
        activeJobs[index] = job;
        // ignore: unawaited_future
        job.whenComplete(() => activeJobs.remove(index));
      }

      if (activeJobs.isEmpty) break;

      // Wait for at least one job to finish before checking again
      await Future.any(activeJobs.values);
    }

    // Finished
    controller.add(
      BatchRenderProgress.completed(
        totalFiles: files.length,
        completedFiles: completedCount,
        failedFiles: failedCount,
        completedFileNames: completedFileNames,
        errors: errors,
      ),
    );

    await controller.close();
  }

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

  /// Trigger download of rendered file
  void _triggerDownload(Uint8List bytes, String fileName, String format) {
    // Create blob
    final mimeType = _mimeTypeForFormat(format);
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);

    // Create download link and trigger
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = '${_removeExtension(fileName)}_slowverb.$format'
      ..style.display = 'none';

    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    // Cleanup blob URL
    web.URL.revokeObjectURL(url);
  }

  /// Get MIME type for format
  String _mimeTypeForFormat(String format) {
    switch (format.toLowerCase()) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      case 'aac':
        return 'audio/aac';
      default:
        return 'application/octet-stream';
    }
  }

  /// Remove file extension
  String _removeExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    return lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
  }

  /// Estimate time remaining
  Duration? _estimateTimeRemaining(
    DateTime startTime,
    int completedCount,
    int totalCount,
  ) {
    if (completedCount == 0) return null;

    final elapsed = DateTime.now().difference(startTime);
    final avgTimePerFile = elapsed.inSeconds / completedCount;
    final remainingFiles = totalCount - completedCount;

    return Duration(seconds: (avgTimePerFile * remainingFiles).round());
  }

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

  Map<String, Object?> _toDspSpec(EffectConfig config) {
    final spec = <String, Object?>{
      'specVersion': '1.0.0',
      'tempo': config.tempo,
      'pitch': config.pitchSemitones,
      'eqWarmth': config.eqWarmth,
      'normalize': false,
    };

    if (config.masteringEnabled > 0.5) {
      String algorithm = 'simple';
      if (config.masteringAlgorithm > 1.5) {
        algorithm = 'phaselimiter_pro';
      } else if (config.masteringAlgorithm > 0.5) {
        algorithm = 'phaselimiter';
      }
      spec['mastering'] = <String, Object?>{
        'enabled': true,
        'algorithm': algorithm,
        if (config.masteringTargetLufs != null)
          'targetLufs': config.masteringTargetLufs,
        if (config.masteringBassPreservation != null)
          'bassPreservation': config.masteringBassPreservation,
        if (config.masteringMode != null)
          'mode': config.masteringMode!.round(),
      };
    }

    if (config.reverbAmount > 0.0) {
      final mix = config.reverbMix ?? 0.88;
      spec['reverb'] = <String, Object?>{
        'decay': config.reverbAmount,
        'preDelayMs': (config.preDelayMs ?? 60).round(),
        'roomScale': config.roomScale ?? 0.7,
        'mix': mix,
      };
    }

    if (config.echoAmount > 0.0) {
      spec['echo'] = <String, Object?>{
        'delayMs': (500 * config.echoAmount).round(),
        'feedback': (config.echoAmount * 0.6).clamp(0.0, 0.9),
      };
    }

    final hfDamping = config.hfDamping;
    if (hfDamping != null) {
      spec['hfDamping'] = hfDamping;
    }

    final stereoWidth = config.stereoWidth;
    if (stereoWidth != null) {
      spec['stereoWidth'] = stereoWidth;
    }

    return spec;
  }

  void _installProgressHandler() {
    if (_progressHandlerInstalled) return;
    _progressHandlerInstalled = true;

    BridgeInterop.setProgressHandler(
      ((JSObject event) {
        final jobId = _getProperty<String>(event, 'jobId');
        final value =
            event.getProperty<JSNumber?>('value'.toJS)?.toDartDouble ?? 0.0;
        final stage =
            event.getProperty<JSString?>('stage'.toJS)?.toDart ?? 'processing';
        final controller = _progressControllers[jobId];
        if (controller == null || controller.isClosed) return;
        controller.add(
          RenderProgress(
            jobId: RenderJobId(jobId),
            progress: value,
            stage: stage,
          ),
        );
      }).toJS,
    );
  }

  void _installLogHandler() {
    if (_logHandlerInstalled) return;
    _logHandlerInstalled = true;

    BridgeInterop.setLogHandler(
      ((JSObject event) {
        final level = _getProperty<String>(event, 'level');
        final message = _getProperty<String>(event, 'message');
        // Surface worker logs to the browser console for easier debugging.
        // ignore: avoid_print
        print('[WasmAudioEngine][$level] $message');
      }).toJS,
    );
  }

  // JS interop helpers
  T _getProperty<T>(JSObject object, String property) {
    try {
      if (T == String) {
        final value = object.getProperty<JSString?>(property.toJS)?.toDart;
        if (value == null) {
          throw StateError('Expected String for "$property" but got null');
        }
        return value as T;
      }
      if (T == int) {
        final value = object.getProperty<JSNumber?>(property.toJS)?.toDartInt;
        if (value == null) {
          throw StateError('Expected int for "$property" but got null');
        }
        return value as T;
      }
      if (T == double) {
        final value = object
            .getProperty<JSNumber?>(property.toJS)
            ?.toDartDouble;
        if (value == null) {
          throw StateError('Expected double for "$property" but got null');
        }
        return value as T;
      }
      if (T == bool) {
        final value = object.getProperty<JSBoolean?>(property.toJS)?.toDart;
        if (value == null) {
          throw StateError('Expected bool for "$property" but got null');
        }
        return value as T;
      }
      // ignore: invalid_runtime_check_with_js_interop_types
      final value = object.getProperty<JSAny?>(property.toJS);
      if (value == null) {
        throw StateError('Expected value for "$property" but got null');
      }
      return value as T;
    } catch (e) {
      throw StateError('Failed to get property "$property" from JS object: $e');
    }
  }
}
