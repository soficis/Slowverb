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
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:slowverb_web/domain/entities/batch_render_progress.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/engine/engine_js_interop.dart';
import 'package:slowverb_web/engine/filter_chain_builder.dart';

/// Web implementation of AudioEngine using FFmpeg WASM
///
/// Communicates with audio_worker.js Web Worker for all audio processing.
/// Keeps UI thread responsive during heavy rendering operations.
class WasmAudioEngine implements AudioEngine {
  final FilterChainBuilder _filterBuilder = FilterChainBuilder();
  final Map<String, StreamController<RenderProgress>> _progressControllers = {};
  final Map<String, RenderResult> _renderResults = {};

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
    SlowverbEngine.setLogHandler(
      _allowInterop((String message) {
        print('[Audio Worker] $message');
      }),
    );

    // Send init message
    SlowverbEngine.postMessage(
      'init',
      null,
      _allowInterop((dynamic response) {
        final type = _getProperty(response, 'type') as String;
        if (type == 'init-ok') {
          _isInitialized = true;
          completer.complete();
        } else if (type == 'error') {
          final error = _getProperty(
            _getProperty(response, 'payload'),
            'error',
          );
          completer.completeError(Exception(error));
        }
      }),
    );

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

    // First, load the file
    final loadPayload = JsInterop.dartMapToJsObject({
      'fileId': fileId,
      'filename': filename,
      'bytes': bytes,
    });

    SlowverbEngine.postMessage(
      'load-source',
      loadPayload,
      _allowInterop((dynamic response) async {
        final type = _getProperty(response, 'type') as String;

        if (type == 'load-ok') {
          // Now probe for metadata
          final probePayload = JsInterop.dartMapToJsObject({'fileId': fileId});

          SlowverbEngine.postMessage(
            'probe',
            probePayload,
            _allowInterop((dynamic probeResponse) {
              final probeType = _getProperty(probeResponse, 'type') as String;

              if (probeType == 'probe-ok') {
                final payload = _getProperty(probeResponse, 'payload');
                final metadata = AudioMetadata(
                  fileId: _getProperty(payload, 'fileId') as String,
                  filename: filename,
                  duration: Duration(
                    milliseconds: _getProperty(payload, 'duration') as int,
                  ),
                  sampleRate: _getProperty(payload, 'sampleRate') as int,
                  channels: _getProperty(payload, 'channels') as int,
                  format: _getProperty(payload, 'format') as String,
                );
                completer.complete(metadata);
              } else if (probeType == 'error') {
                final error = _getProperty(
                  _getProperty(probeResponse, 'payload'),
                  'error',
                );
                completer.completeError(Exception(error));
              }
            }),
          );
        } else if (type == 'error') {
          final error = _getProperty(
            _getProperty(response, 'payload'),
            'error',
          );
          completer.completeError(Exception(error));
        }
      }),
    );

    return completer.future;
  }

  @override
  Future<Float32List> getWaveform(
    String fileId, {
    int targetSamples = 1000,
  }) async {
    _ensureInitialized();

    final completer = Completer<Float32List>();

    final payload = JsInterop.dartMapToJsObject({
      'fileId': fileId,
      'targetSamples': targetSamples,
    });

    SlowverbEngine.postMessage(
      'waveform',
      payload,
      _allowInterop((dynamic response) {
        final type = _getProperty(response, 'type') as String;

        if (type == 'waveform-ok') {
          final waveformData = _getProperty(response, 'payload');
          // Convert JS Float32Array to Dart Float32List
          final float32List = Float32List.fromList(
            List<double>.from(waveformData as List),
          );
          completer.complete(float32List);
        } else if (type == 'error') {
          final error = _getProperty(
            _getProperty(response, 'payload'),
            'error',
          );
          completer.completeError(Exception(error));
        }
      }),
    );

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
    final filterChain = _filterBuilder.buildFilterChain(config);

    final payload = JsInterop.dartMapToJsObject({
      'fileId': fileId,
      'filterChain': filterChain,
      'startAt': startAt?.inSeconds ?? 0,
    });

    SlowverbEngine.postMessage(
      'render-preview',
      payload,
      _allowInterop((dynamic response) {
        final type = _getProperty(response, 'type') as String;

        if (type == 'render-preview-ok') {
          final outputBuffer = _getProperty(
            _getProperty(response, 'payload'),
            'outputBuffer',
          );
          final uint8List = _jsBufferToUint8List(outputBuffer);

          // Create blob URL
          final blob = html.Blob([uint8List], 'audio/mp3');
          final url = html.Url.createObjectUrlFromBlob(blob);

          completer.complete(Uri.parse(url));
        } else if (type == 'error') {
          final error = _getProperty(
            _getProperty(response, 'payload'),
            'error',
          );
          completer.completeError(Exception(error));
        }
      }),
    );

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

    final payload = JsInterop.dartMapToJsObject({
      'fileId': fileId,
      'filterChain': filterChain,
      'format': options.format,
      'bitrateKbps': options.bitrateKbps,
      'compressionLevel': options.compressionLevel,
    });

    SlowverbEngine.postMessage(
      'render-full',
      payload,
      _allowInterop((dynamic response) {
        final type = _getProperty(response, 'type') as String;

        if (type == 'render-progress') {
          final payload = _getProperty(response, 'payload');
          final progress = RenderProgress(
            jobId: jobId,
            progress: _getProperty(payload, 'progress') as double,
            stage: _getProperty(payload, 'stage') as String,
          );
          controller.add(progress);
        } else if (type == 'render-full-ok') {
          final payload = _getProperty(response, 'payload');
          final outputBuffer = _getProperty(payload, 'outputBuffer');
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
          final error = _getProperty(
            _getProperty(response, 'payload'),
            'error',
          );
          _renderResults[jobId.value] = RenderResult(
            success: false,
            errorMessage: error?.toString(),
          );

          controller.addError(Exception(error));
          controller.close();
          _progressControllers.remove(jobId.value);
        }
      }),
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

    SlowverbEngine.postMessage(
      'cancel',
      payload,
      _allowInterop((dynamic response) {
        // Cleanup controller
        final controller = _progressControllers.remove(jobId.value);
        controller?.close();

        _renderResults.remove(jobId.value);
      }),
    );
  }

  @override
  Future<void> cleanup({String? fileId}) async {
    final payload = JsInterop.dartMapToJsObject({
      if (fileId != null) 'fileId': fileId,
    });

    SlowverbEngine.postMessage(
      'cleanup',
      payload,
      _allowInterop((dynamic response) {
        // Cleanup complete
      }),
    );
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

  /// Trigger download of rendered file
  void _triggerDownload(Uint8List bytes, String fileName, String format) {
    // Create blob
    final mimeType = _mimeTypeForFormat(format);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Create download link and trigger
    final anchor = html.AnchorElement()
      ..href = url
      ..download = '${_removeExtension(fileName)}_slowverb.$format'
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    // Cleanup blob URL
    html.Url.revokeObjectUrl(url);
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
  dynamic _allowInterop(Function callback) {
    return js_util.allowInterop(callback);
  }

  dynamic _getProperty(dynamic object, String property) {
    return js_util.getProperty(object, property);
  }
}

/// JS interop helpers for typed arrays
Uint8List _jsBufferToUint8List(dynamic jsBuffer) {
  if (jsBuffer is ByteBuffer) {
    return Uint8List.view(jsBuffer);
  }

  if (jsBuffer is List) {
    return Uint8List.fromList(List<int>.from(jsBuffer));
  }

  // Fallback: try to read `buffer` property if a TypedArray was passed through
  final bufferProp = js_util.getProperty(jsBuffer, 'buffer');
  if (bufferProp is ByteBuffer) {
    return Uint8List.view(bufferProp);
  }

  throw ArgumentError(
    'Unsupported buffer type from worker: ${jsBuffer.runtimeType}',
  );
}
