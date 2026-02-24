part of 'wasm_audio_engine.dart';

Future<AudioMetadata> loadSourceImpl(
  WasmAudioEngine engine, {
  required String fileId,
  required String filename,
  required Uint8List bytes,
}) async {
  engine._ensureInitialized();

  final payload = BridgeInterop.toJsObject({
    'source': {'fileId': fileId, 'filename': filename, 'data': bytes.toJS},
  });

  final response = await BridgeInterop.loadAndProbe(payload);
  final payloadObj = response.getProperty<JSObject>('payload'.toJS);
  engine._loadedFiles[fileId] = bytes;
  final durationMs = payloadObj
      .getProperty<JSNumber?>('durationMs'.toJS)
      ?.toDartInt;

  return AudioMetadata(
    fileId: engine._getProperty<String>(payloadObj, 'fileId'),
    filename: filename,
    duration: engine._durationFromMs(durationMs),
    sampleRate: engine._getProperty<int>(payloadObj, 'sampleRate'),
    channels: engine._getProperty<int>(payloadObj, 'channels'),
    format: engine._getProperty<String>(payloadObj, 'format'),
  );
}

Future<({Float32List left, Float32List right, int sampleRate})>
decodeToFloatPcmImpl(WasmAudioEngine engine, String fileId) async {
  engine._ensureInitialized();
  final payload = BridgeInterop.toJsObject({
    'source': {'fileId': fileId, 'data': engine._requireFileBytes(fileId).toJS},
  });

  final response = await BridgeInterop.decodeToFloatPCM(payload);
  final type = engine._getProperty<String>(response, 'type');
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

Future<Uint8List> encodeFromFloatPcmImpl(
  WasmAudioEngine engine, {
  required Float32List left,
  required Float32List right,
  required int sampleRate,
  required String format,
  int? bitrateKbps,
}) async {
  engine._ensureInitialized();
  final payloadData = <String, Object?>{
    'left': left.toJS,
    'right': right.toJS,
    'sampleRate': sampleRate,
    'format': format,
    'bitrateKbps': bitrateKbps,
  };
  payloadData.removeWhere((_, value) => value == null);
  final payload = BridgeInterop.toJsObject(payloadData);

  final response = await BridgeInterop.encodeFromFloatPCM(payload);
  final type = engine._getProperty<String>(response, 'type');
  if (type != 'encode-pcm-ok') {
    throw StateError('Encode PCM failed: $type');
  }

  final payloadObj = response.getProperty<JSObject>('payload'.toJS);
  final buffer = payloadObj.getProperty<JSObject>('buffer'.toJS);
  return BridgeInterop.bufferToUint8List(buffer);
}

Future<Float32List> getWaveformImpl(
  WasmAudioEngine engine,
  String fileId, {
  int targetSamples = 1000,
}) async {
  engine._ensureInitialized();

  final payload = BridgeInterop.toJsObject({
    'source': {'fileId': fileId, 'data': engine._requireFileBytes(fileId).toJS},
    'points': targetSamples,
  });

  final response = await BridgeInterop.waveform(payload);
  final type = engine._getProperty<String>(response, 'type');
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

Future<Uri> renderPreviewImpl(
  WasmAudioEngine engine, {
  required String fileId,
  required EffectConfig config,
  Duration? startAt,
  Duration? duration,
}) async {
  engine._ensureInitialized();

  if (engine._currentPreviewUrl != null) {
    web.URL.revokeObjectURL(engine._currentPreviewUrl!);
    engine._activeBlobUrls.remove(engine._currentPreviewUrl);
    engine._currentPreviewUrl = null;
  }

  final jobId = 'preview-${DateTime.now().millisecondsSinceEpoch}';
  engine._currentPreviewJobId = jobId;

  try {
    final payload = BridgeInterop.toJsObject({
      'source': {
        'fileId': fileId,
        'data': engine._requireFileBytes(fileId).toJS,
      },
      'dspSpec': engine._toDspSpec(config),
      'startSec': (startAt?.inMilliseconds ?? 0) / 1000.0,
      'durationSec': duration != null ? duration.inMilliseconds / 1000.0 : null,
      'jobId': jobId,
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

    engine._currentPreviewUrl = url;
    engine._activeBlobUrls.add(url);
    return Uri.parse(url);
  } finally {
    engine._currentPreviewJobId = null;
  }
}

Future<RenderJobId> startRenderImpl(
  WasmAudioEngine engine, {
  required String fileId,
  required EffectConfig config,
  required ExportOptions options,
}) async {
  engine._ensureInitialized();

  final jobId = RenderJobId('job-${DateTime.now().millisecondsSinceEpoch}');
  engine._progressControllers[jobId.value] =
      StreamController<RenderProgress>.broadcast();
  engine._progressControllers[jobId.value]!.add(
    RenderProgress(jobId: jobId, progress: 0.0, stage: 'processing'),
  );

  unawaited(
    engine._performRender(
      jobId: jobId,
      fileId: fileId,
      config: config,
      options: options,
      controller: engine._progressControllers[jobId.value]!,
    ),
  );

  return jobId;
}

Future<void> performRenderImpl(
  WasmAudioEngine engine, {
  required RenderJobId jobId,
  required String fileId,
  required EffectConfig config,
  required ExportOptions options,
  required StreamController<RenderProgress> controller,
}) async {
  try {
    final payload = BridgeInterop.toJsObject({
      'source': {
        'fileId': fileId,
        'data': engine._requireFileBytes(fileId).toJS,
      },
      'dspSpec': engine._toDspSpec(config),
      'format': options.format,
      'bitrateKbps': options.bitrateKbps ?? 192,
      'jobId': jobId.value,
    });

    final response = await BridgeInterop.renderFull(payload);
    final payloadObj = response.getProperty<JSObject>('payload'.toJS);
    final buffer = payloadObj.getProperty<JSObject>('outputBuffer'.toJS);
    final bytes = BridgeInterop.bufferToUint8List(buffer);

    engine._renderResults[jobId.value] = RenderResult(
      success: true,
      outputBytes: bytes,
    );
    controller.add(
      RenderProgress(jobId: jobId, progress: 1.0, stage: 'complete'),
    );
  } catch (error) {
    final message = error.toString();
    engine._renderResults[jobId.value] = RenderResult(
      success: false,
      errorMessage: message,
    );
    controller.addError(Exception(message));
  } finally {
    await controller.close();
    engine._progressControllers.remove(jobId.value);
  }
}

Stream<RenderProgress> watchProgressImpl(
  WasmAudioEngine engine,
  RenderJobId jobId,
) {
  if (!engine._progressControllers.containsKey(jobId.value)) {
    throw StateError('No render job found with ID: $jobId');
  }
  return engine._progressControllers[jobId.value]!.stream;
}

Future<RenderResult> getResultImpl(
  WasmAudioEngine engine,
  RenderJobId jobId,
) async {
  final result = engine._renderResults.remove(jobId.value);
  final controller = engine._progressControllers.remove(jobId.value);
  await controller?.close();

  if (result != null) {
    return result;
  }

  return const RenderResult(
    success: false,
    errorMessage: 'No render result available for this job.',
  );
}

Future<void> cancelRenderImpl(WasmAudioEngine engine, RenderJobId jobId) async {
  await BridgeInterop.cancel(jobId.value);
  final controller = engine._progressControllers.remove(jobId.value);
  await controller?.close();
  engine._renderResults.remove(jobId.value);
}

void triggerDownloadImpl(
  WasmAudioEngine engine,
  Uint8List bytes,
  String fileName,
  String format,
) {
  final mimeType = engine._mimeTypeForFormat(format);
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = '${engine._removeExtension(fileName)}_slowverb.$format'
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

String mimeTypeForFormatImpl(String format) {
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

String removeExtensionImpl(String fileName) {
  final lastDot = fileName.lastIndexOf('.');
  return lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
}

Duration? estimateTimeRemainingImpl(
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

Future<void> runParallelBatchImpl(
  WasmAudioEngine engine,
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
  final int concurrency = files.length < maxConcurrency
      ? files.length
      : maxConcurrency;
  int nextIndex = 0;
  final activeJobs = <int, Future<void>>{};

  Future<void> processFile(int index) async {
    final file = files[index];
    final preset = file.presetOverride ?? defaultPreset;

    try {
      await engine.loadSource(
        fileId: file.fileId,
        filename: file.fileName,
        bytes: file.bytes,
      );

      final config = EffectConfig.fromParams(preset.id, preset.parameters);
      final jobId = await engine.startRender(
        fileId: file.fileId,
        config: config,
        options: options,
      );

      await for (final progress in engine.watchProgress(jobId)) {
        if (engine._batchCancelled) {
          await engine.cancelRender(jobId);
          break;
        }

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
                files.length,
            estimatedTimeRemaining: engine._estimateTimeRemaining(
              startTime,
              completedCount,
              files.length,
            ),
            completedFileNames: completedFileNames,
            errors: errors,
          ),
        );
      }

      if (engine._batchCancelled) return;

      final result = await engine.getResult(jobId);
      if (result.success && result.outputBytes != null) {
        final outputFileName =
            '${engine._removeExtension(file.fileName)}_slowverb.${options.format}';
        if (engine._batchResultCallback != null) {
          engine._batchResultCallback!(outputFileName, result.outputBytes!);
        } else {
          engine._triggerDownload(
            result.outputBytes!,
            file.fileName,
            options.format,
          );
        }
        completedCount++;
        completedFileNames.add(file.fileName);
      } else {
        failedCount++;
        errors[file.fileName] = result.errorMessage ?? 'Unknown error';
      }

      await engine.cleanup(fileId: file.fileId);
    } catch (e) {
      debugPrint('[Batch] Error processing ${file.fileName}: $e');
      failedCount++;
      errors[file.fileName] = e.toString();
      try {
        await engine.cleanup(fileId: file.fileId);
      } catch (error) {
        debugPrint('Engine cleanup failed for ${file.fileName}: $error');
      }
    }
  }

  while (nextIndex < files.length || activeJobs.isNotEmpty) {
    if (engine._batchCancelled) break;

    while (engine._batchPaused && !engine._batchCancelled) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    while (nextIndex < files.length && activeJobs.length < concurrency) {
      final index = nextIndex++;
      final job = processFile(index);
      activeJobs[index] = job;
      // ignore: unawaited_future
      job.whenComplete(() => activeJobs.remove(index));
    }

    if (activeJobs.isEmpty) break;
    await Future.any(activeJobs.values);
  }

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

Map<String, Object?> toDspSpecImpl(EffectConfig config) {
  final spec = <String, Object?>{
    'specVersion': '1.0.0',
    'tempo': config.tempo,
    'pitch': config.pitchSemitones,
    'eqWarmth': config.eqWarmth,
    'normalize': false,
  };

  final quality = <String, Object?>{};
  if (config.hqTimeStretch > 0.5) {
    quality['timeStretch'] = 'soundtouch';
  }
  if (config.hqReverb > 0.5 && config.reverbAmount > 0.0) {
    quality['reverb'] = 'tone';
  }
  if (quality.isNotEmpty) {
    spec['quality'] = quality;
  }

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
      if (config.masteringMode != null) 'mode': config.masteringMode!.round(),
    };
  } else {
    spec['mastering'] = <String, Object?>{'enabled': false};
  }

  if (config.reverbAmount > 0.0) {
    final mix = config.reverbMix ?? 0.6;
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

void installProgressHandlerImpl(WasmAudioEngine engine) {
  if (engine._progressHandlerInstalled) return;
  engine._progressHandlerInstalled = true;

  BridgeInterop.setProgressHandler(
    ((JSObject event) {
      final jobId = engine._getProperty<String>(event, 'jobId');
      final value =
          event.getProperty<JSNumber?>('value'.toJS)?.toDartDouble ?? 0.0;
      final stage =
          event.getProperty<JSString?>('stage'.toJS)?.toDart ?? 'processing';

      if (jobId == engine._currentPreviewJobId &&
          engine._previewProgressCallback != null) {
        engine._previewProgressCallback!(value, stage);
      }

      if (engine._progressControllers[jobId] != null &&
          !engine._progressControllers[jobId]!.isClosed) {
        engine._progressControllers[jobId]!.add(
          RenderProgress(
            jobId: RenderJobId(jobId),
            progress: value,
            stage: stage,
          ),
        );
      }
    }).toJS,
  );
}

void installLogHandlerImpl(WasmAudioEngine engine) {
  if (engine._logHandlerInstalled) return;
  engine._logHandlerInstalled = true;

  BridgeInterop.setLogHandler(
    ((JSObject event) {
      final level = engine._getProperty<String>(event, 'level');
      final message = engine._getProperty<String>(event, 'message');
      if (level == 'warn' && message.startsWith('mastering-warning:')) {
        final warning = message.substring('mastering-warning:'.length).trim();
        engine._warningCallback?.call(warning);
      }
      debugPrint('[WasmAudioEngine][$level] $message');
    }).toJS,
  );
}

T getPropertyImpl<T>(JSObject object, String property) {
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
      final value = object.getProperty<JSNumber?>(property.toJS)?.toDartDouble;
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
    final value = object.getProperty<JSAny?>(property.toJS);
    if (value == null) {
      throw StateError('Expected value for "$property" but got null');
    }
    // ignore: invalid_runtime_check_with_js_interop_types
    return value as T;
  } catch (e) {
    throw StateError('Failed to get property "$property" from JS object: $e');
  }
}
