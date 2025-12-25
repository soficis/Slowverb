import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PhaseLimiterConfig {
  final double targetLufs;
  final double bassPreservation;
  final int mode;

  const PhaseLimiterConfig({
    this.targetLufs = -14.0,
    this.bassPreservation = 0.5,
    this.mode = 3, // Default to Standard Level 3 (Level 5 Pro is opt-in)
  });
}

class PhaseLimiterException implements Exception {
  final String message;
  final int? errorCode;

  PhaseLimiterException(this.message, [this.errorCode]);

  @override
  String toString() => 'PhaseLimiterException: $message (code: $errorCode)';
}

class PhaseLimiterService {
  static const maxMobileDurationSeconds = 300;

  web.Worker? _worker;
  final StreamController<double> _progressController =
      StreamController.broadcast();

  Stream<double> get progressStream => _progressController.stream;

  Future<void> initialize() async {
    if (_worker != null) return;

    // Add cache buster to ensure the latest worker script is loaded
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _worker = web.Worker('/js/phase_limiter_pro_worker.js?v=$timestamp'.toJS);

    _worker?.onerror = ((web.ErrorEvent event) {
      // ignore: avoid_print
      print('[PhaseLimiterService] Worker error: ${event.message}');
    }).toJS;
  }

  Future<({Float32List left, Float32List right})> process({
    required Float32List leftChannel,
    required Float32List rightChannel,
    required int sampleRate,
    PhaseLimiterConfig config = const PhaseLimiterConfig(),
  }) async {
    final worker = _worker;
    if (worker == null) {
      throw PhaseLimiterException('Worker not initialized');
    }

    if (leftChannel.length != rightChannel.length) {
      throw PhaseLimiterException('Channel length mismatch');
    }

    _validateDuration(leftChannel.length, sampleRate);

    final completer = Completer<({Float32List left, Float32List right})>();

    late final JSFunction handler;
    handler = ((web.MessageEvent event) {
      final dataAny = event.data;
      if (dataAny == null) return;
      // ignore: invalid_runtime_check_with_js_interop_types
      final data = dataAny as JSObject;

      final type = data.getProperty<JSString?>('type'.toJS)?.toDart;
      switch (type) {
        case 'progress':
          final percent =
              data.getProperty<JSNumber?>('percent'.toJS)?.toDartDouble ?? 0.0;
          _progressController.add(percent);
          return;

        case 'complete':
          final left = data.getProperty<JSFloat32Array?>('leftChannel'.toJS);
          final right = data.getProperty<JSFloat32Array?>('rightChannel'.toJS);
          if (left == null || right == null) {
            completer.completeError(
              PhaseLimiterException('Invalid completion payload'),
            );
            worker.removeEventListener('message', handler);
            return;
          }

          completer.complete((left: left.toDart, right: right.toDart));
          worker.removeEventListener('message', handler);
          return;

        case 'error':
          final message =
              data.getProperty<JSString?>('error'.toJS)?.toDart ??
              'PhaseLimiter worker error';
          completer.completeError(PhaseLimiterException(message));
          worker.removeEventListener('message', handler);
          return;
      }
    }).toJS;

    worker.addEventListener('message', handler);

    final leftJs = leftChannel.toJS;
    final rightJs = rightChannel.toJS;
    final leftBuffer = (leftJs as JSObject).getProperty<JSArrayBuffer>(
      'buffer'.toJS,
    );
    final rightBuffer = (rightJs as JSObject).getProperty<JSArrayBuffer>(
      'buffer'.toJS,
    );

    final message =
        <String, Object?>{
              'leftChannel': leftJs,
              'rightChannel': rightJs,
              'sampleRate': sampleRate,
              'config': <String, Object?>{
                'targetLufs': config.targetLufs,
                'bassPreservation': config.bassPreservation,
                'mode': config.mode,
              },
            }.jsify()
            as JSObject;

    try {
      worker.postMessage(message, [leftBuffer, rightBuffer].toJS);
    } catch (e) {
      worker.removeEventListener('message', handler);
      throw PhaseLimiterException('postMessage failed: $e');
    }

    return completer.future;
  }

  void dispose() {
    _worker?.terminate();
    _worker = null;
    _progressController.close();
  }

  void _validateDuration(int sampleCount, int sampleRate) {
    final durationSeconds = sampleCount / sampleRate;
    final userAgent = web.window.navigator.userAgent;
    final isMobile = userAgent.contains('Mobile');
    if (isMobile && durationSeconds > maxMobileDurationSeconds) {
      throw PhaseLimiterException(
        'File too long for mobile mastering (max ${maxMobileDurationSeconds}s)',
      );
    }
  }
}
