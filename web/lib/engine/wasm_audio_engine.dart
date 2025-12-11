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

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:slowverb_web/domain/entities/batch_render_progress.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/streaming_source.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/engine/engine_js_interop.dart';
import 'package:slowverb_web/engine/filter_chain_builder.dart';
import 'package:slowverb_web/engine/streaming_audio_engine.dart';
import 'package:web/web.dart' as web;

/// Web implementation of AudioEngine using FFmpeg WASM
///
/// Communicates with audio_worker.js Web Worker for all audio processing.
/// Keeps UI thread responsive during heavy rendering operations.
class WasmAudioEngine implements AudioEngine {
  final FilterChainBuilder _filterBuilder = FilterChainBuilder();
  final Map<String, StreamController<RenderProgress>> _progressControllers = {};
  final Map<String, RenderResult> _renderResults = {};
  StreamingAudioEngine? _streamingEngine;

  bool _isInitialized = false;

  @override
  bool get isReady => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    final completer = Completer<void>();

    // Initialize worker
    SlowverbEngine.initWorker();

    // Set up log handler
    SlowverbEngine.setLogHandler((String message) {
      print('[Audio Worker] $message');
    });

    // Send init message
    SlowverbEngine.postMessage('init', null, (JSObject response) {
      final type = _getProperty<String>(response, 'type');
      if (type == 'init-ok') {
        _isInitialized = true;
        completer.complete();
      } else if (type == 'error') {
        final payload = response.getProperty<JSObject?>('payload'.toJS);
        final error = payload?.getProperty<JSString?>('error'.toJS)?.toDart;
        completer.completeError(Exception(error));
      }
    });

    return completer.future;
  }

  @override
  Future<AudioMetadata> loadSource({
    required String fileId,
    required String filename,
    required Uint8List bytes,
  }) async {
    _ensureInitialized();

    final completer = Completer<AudioMetadata>();

    // Verify data before sending
    print(
      '[Dart] calling loadSource - fileId: $fileId, filename: $filename, bytes: ${bytes.length}',
    );

    // Use the command-specific wrapper that passes params individually
    SlowverbEngine.loadSource(fileId, filename, bytes, (
      JSObject response,
    ) async {
      final type = _getProperty<String>(response, 'type');

      if (type == 'load-ok') {
        // Now probe for metadata
        SlowverbEngine.probe(fileId, (JSObject probeResponse) {
          final probeType = _getProperty<String>(probeResponse, 'type');

          if (probeType == 'probe-ok') {
            final payload = probeResponse.getProperty<JSObject?>(
              'payload'.toJS,
            )!;
            final durationMs = _getProperty<int?>(payload, 'duration');
            final metadata = AudioMetadata(
              fileId: _getProperty<String>(payload, 'fileId'),
              filename: filename,
              duration: durationMs != null
                  ? Duration(milliseconds: durationMs)
                  : null, // null = process entire file
              sampleRate: _getProperty<int>(payload, 'sampleRate'),
              channels: _getProperty<int>(payload, 'channels'),
              format: _getProperty<String>(payload, 'format'),
            );
            completer.complete(metadata);
          } else if (probeType == 'error') {
            final errorPayload = probeResponse.getProperty<JSObject?>(
              'payload'.toJS,
            );
            final error = errorPayload
                ?.getProperty<JSString?>('error'.toJS)
                ?.toDart;
            completer.completeError(Exception(error));
          }
        });
      } else if (type == 'error') {
        final payload = response.getProperty<JSObject?>('payload'.toJS);
        final error = payload?.getProperty<JSString?>('error'.toJS)?.toDart;
        completer.completeError(Exception(error));
      }
    });

    return completer.future;
  }

  @override
  Future<Float32List> getWaveform(
    String fileId, {
    int targetSamples = 1000,
  }) async {
    _ensureInitialized();

    final completer = Completer<Float32List>();
    // Call getWaveform using direct interop
    SlowverbEngine.getWaveform(fileId, (JSObject response) {
      final type = _getProperty<String>(response, 'type');

      if (type == 'waveform-ok') {
        final payload = response.getProperty<JSObject>('payload'.toJS);
        // Expect 'samples' which is a Float32Array
        final samples = payload.getProperty<JSObject>('samples'.toJS);

        // Convert JS typed array to Dart list
        // Note: Typed arrays are JSUint8Array etc, but JSAny for Float32Array?
        // Let's assume toDart works if we cast correctly or use helper.
        // Actually JSArray<JSNumber> logic is safer if we don't know the exact typed array type wrapping.
        // But engine_wrapper returns Float32Array.
        // dart:js_interop maps Float32Array to JSFloat32Array.
        // We can use toDart on it.

        if (samples.isA<JSFloat32Array>()) {
          completer.complete((samples as JSFloat32Array).toDart);
        } else {
          // Fallback or empty
          completer.complete(Float32List(0));
        }
      } else if (type == 'error') {
        final payload = response.getProperty<JSObject?>('payload'.toJS);
        final error = payload?.getProperty<JSString?>('error'.toJS)?.toDart;
        completer.completeError(Exception(error));
      }
    });

    return completer.future;
  }

  @override
  Future<Uri> renderPreview({
    required String fileId,
    required EffectConfig config,
    Duration? startAt,
    Duration? duration,
  }) async {
    _ensureInitialized();
    final completer = Completer<Uri>();

    // Build filter chain string
    final filterChain = _filterBuilder.buildFilterChain(config);

    // Build config object for preview
    // When duration is null, the entire file will be processed
    final durationSec = duration != null
        ? duration.inMilliseconds / 1000.0
        : null;
    print(
      '[WasmAudioEngine] renderPreview - duration: $duration, durationSec: $durationSec',
    );

    final configObj = JsInterop.dartMapToJsObject({
      'filterChain': filterChain,
      'startSec': (startAt?.inMilliseconds ?? 0) / 1000.0,
      'durationSec': durationSec,
    });

    SlowverbEngine.renderPreview(fileId, configObj, (JSObject response) {
      final type = _getProperty<String>(response, 'type');
      if (type == 'render-preview-ok') {
        final payload = response.getProperty<JSObject>('payload'.toJS);
        final buffer = payload.getProperty<JSArrayBuffer>('buffer'.toJS);
        final bytes = buffer.toDart.asUint8List();

        final blob = web.Blob(
          [bytes.toJS].toJS,
          web.BlobPropertyBag(type: 'audio/mp3'),
        );
        final url = web.URL.createObjectURL(blob);
        completer.complete(Uri.parse(url));
      } else {
        final payload = response.getProperty<JSObject?>('payload'.toJS);
        final error = payload?.getProperty<JSString?>('error'.toJS)?.toDart;
        completer.completeError(Exception(error ?? 'Unknown render error'));
      }
    });

    return completer.future;
  }

  @override
  Future<RenderJobId> startRender({
    required String fileId,
    required EffectConfig config,
    required ExportOptions options,
  }) async {
    _ensureInitialized();

    final jobId = RenderJobId('job-${DateTime.now().millisecondsSinceEpoch}');
    final filterChain = _filterBuilder.buildFilterChain(config);

    // Create progress stream controller
    final controller = StreamController<RenderProgress>.broadcast();
    _progressControllers[jobId.value] = controller;

    // progress updates not supported in direct call yet, simulating start
    controller.add(
      RenderProgress(jobId: jobId, progress: 0.1, stage: 'processing'),
    );

    SlowverbEngine.renderFull(
      fileId,
      filterChain,
      options.format,
      options.bitrateKbps ?? 192, // Default to 192 if null
      (JSObject response) {
        final type = _getProperty<String>(response, 'type');

        if (type == 'render-full-ok') {
          final payloadObj = response.getProperty<JSObject?>('payload'.toJS)!;
          final outputBuffer = payloadObj.getProperty<JSAny?>(
            'outputBuffer'.toJS,
          );
          final bytes = _jsBufferToUint8List(outputBuffer);

          _renderResults[jobId.value] = RenderResult(
            success: true,
            outputBytes: bytes,
          );

          // Final progress
          controller.add(
            RenderProgress(jobId: jobId, progress: 1.0, stage: 'complete'),
          );
          controller.close();
          _progressControllers.remove(jobId.value);
        } else if (type == 'error') {
          final errorPayload = response.getProperty<JSObject?>('payload'.toJS);
          final error = errorPayload
              ?.getProperty<JSString?>('error'.toJS)
              ?.toDart;
          _renderResults[jobId.value] = RenderResult(
            success: false,
            errorMessage: error,
          );

          controller.addError(Exception(error));
          controller.close();
          _progressControllers.remove(jobId.value);
        }
      },
    );

    return jobId;
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
    final payload = JsInterop.dartMapToJsObject({'jobId': jobId.value});

    SlowverbEngine.postMessage('cancel', payload, (JSObject response) {
      // Cleanup controller
      final controller = _progressControllers.remove(jobId.value);
      controller?.close();

      _renderResults.remove(jobId.value);
    });
  }

  @override
  Future<void> cleanup({String? fileId}) async {
    final payload = JsInterop.dartMapToJsObject({
      if (fileId != null) 'fileId': fileId,
    });

    SlowverbEngine.postMessage('cleanup', payload, (JSObject response) {
      // Cleanup complete
    });
  }

  @override
  Future<void> dispose() async {
    SlowverbEngine.terminateWorker();
    _isInitialized = false;

    // Close all progress controllers
    for (final controller in _progressControllers.values) {
      await controller.close();
    }
    _progressControllers.clear();
    _renderResults.clear();

    await _streamingEngine?.dispose();
    _streamingEngine = null;
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
  }) async* {
    _ensureInitialized();

    // Enforce batch size limit for web (50 files max)
    if (files.length > 50) {
      throw ArgumentError(
        'Batch size limit exceeded. Maximum 50 files allowed on web.',
      );
    }

    if (files.isEmpty) {
      yield BatchRenderProgress.completed(
        totalFiles: 0,
        completedFiles: 0,
        failedFiles: 0,
        completedFileNames: [],
        errors: {},
      );
      return;
    }

    _batchCancelled = false;
    _batchPaused = false;

    // Track progress
    int completedCount = 0;
    int failedCount = 0;
    final completedFileNames = <String>[];
    final errors = <String, String>{};
    final startTime = DateTime.now();

    // Yield initial progress
    yield BatchRenderProgress.initial(files.length);

    // Process files sequentially (concurrency = 1 for web)
    for (int index = 0; index < files.length; index++) {
      // Check for cancellation
      if (_batchCancelled) break;

      // Wait while paused
      while (_batchPaused && !_batchCancelled) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_batchCancelled) break;

      final file = files[index];
      final preset = file.presetOverride ?? defaultPreset;

      try {
        // Load the file
        await loadSource(
          fileId: file.fileId,
          filename: file.fileName,
          bytes: file.bytes,
        );

        // Create effect config from preset
        final config = EffectConfig.fromParams(preset.id, preset.parameters);

        // Start render
        final jobId = await startRender(
          fileId: file.fileId,
          config: config,
          options: options,
        );

        // Watch progress and yield updates
        await for (final progress in watchProgress(jobId)) {
          if (_batchCancelled) {
            await cancelRender(jobId);
            break;
          }

          // Yield batch progress
          yield BatchRenderProgress(
            totalFiles: files.length,
            completedFiles: completedCount,
            failedFiles: failedCount,
            currentFileIndex: index,
            currentFileName: file.fileName,
            currentFileProgress: progress.progress,
            overallProgress:
                (completedCount + progress.progress) / files.length,
            estimatedTimeRemaining: _estimateTimeRemaining(
              startTime,
              completedCount,
              files.length,
            ),
            completedFileNames: completedFileNames,
            errors: errors,
          );
        }

        if (_batchCancelled) break;

        // Get result
        final result = await getResult(jobId);

        if (result.success && result.outputBytes != null) {
          // Auto-download to free memory (web platform requirement)
          _triggerDownload(result.outputBytes!, file.fileName, options.format);
          completedCount++;
          completedFileNames.add(file.fileName);
        } else {
          failedCount++;
          errors[file.fileName] = result.errorMessage ?? 'Unknown error';
        }

        // Cleanup to free memory
        await cleanup(fileId: file.fileId);
      } catch (e) {
        failedCount++;
        errors[file.fileName] = e.toString();
        // Continue with next file
      }
    }

    // Yield final progress
    yield BatchRenderProgress.completed(
      totalFiles: files.length,
      completedFiles: completedCount,
      failedFiles: failedCount,
      completedFileNames: completedFileNames,
      errors: errors,
    );
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

  // --- Streaming / live remix mode (not implemented yet) ---

  @override
  Future<StreamingCapability> attachStreamingSource(
    StreamingSource source,
  ) async {
    _streamingEngine ??= StreamingAudioEngine();
    return _streamingEngine!.attach(source);
  }

  @override
  Stream<AudioAnalysisFrame> getStreamingAnalysisStream() {
    return _streamingEngine?.analysisStream ?? const Stream.empty();
  }

  @override
  Future<void> playStreaming() async {
    await _streamingEngine?.play();
  }

  @override
  Future<void> pauseStreaming() async {
    await _streamingEngine?.pause();
  }

  @override
  Future<void> seekStreaming(Duration position) async {
    await _streamingEngine?.seek(position);
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

  // JS interop helpers
  T _getProperty<T>(JSObject object, String property) {
    if (T == String) {
      return object.getProperty<JSString?>(property.toJS)?.toDart as T;
    }
    if (T == int) {
      return object.getProperty<JSNumber?>(property.toJS)?.toDartInt as T;
    }
    if (T == double) {
      return object.getProperty<JSNumber?>(property.toJS)?.toDartDouble as T;
    }
    if (T == bool) {
      return object.getProperty<JSBoolean?>(property.toJS)?.toDart as T;
    }
    return object.getProperty<JSAny?>(property.toJS) as T;
  }
}

/// JS interop helpers for typed arrays
Uint8List _jsBufferToUint8List(JSAny? jsBuffer) {
  if (jsBuffer == null) {
    throw ArgumentError('Buffer is null');
  }

  // Try as ArrayBuffer
  if (jsBuffer.isA<JSArrayBuffer>()) {
    return (jsBuffer as JSArrayBuffer).toDart.asUint8List();
  }

  // Try as Uint8Array (TypedArray)
  if (jsBuffer.isA<JSUint8Array>()) {
    return (jsBuffer as JSUint8Array).toDart;
  }

  // Try to get buffer property from TypedArray
  if (jsBuffer.isA<JSObject>()) {
    final bufferProp = (jsBuffer as JSObject).getProperty<JSArrayBuffer?>(
      'buffer'.toJS,
    );
    if (bufferProp != null) {
      return bufferProp.toDart.asUint8List();
    }
  }

  throw ArgumentError('Unsupported buffer type from worker');
}
