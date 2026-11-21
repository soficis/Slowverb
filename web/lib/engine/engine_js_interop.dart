import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:slowverb_web/domain/entities/audio_analysis_track.dart';

@JS('SlowverbBridge')
external SlowverbBridgeJS? get _slowverbBridgeJSNullable;

/// Returns the SlowverbBridge JS object.
/// Throws a clear error if the bridge isn't loaded (e.g., blocked by ad blocker).
SlowverbBridgeJS get slowverbBridgeJS {
  final bridge = _slowverbBridgeJSNullable;
  if (bridge == null) {
    throw StateError(
      'SlowverbBridge not loaded. Check if browser extensions (ad blockers) '
      'are blocking JavaScript files. Try disabling extensions or whitelisting this site.',
    );
  }
  return bridge;
}

extension type SlowverbBridgeJS._(JSObject _) implements JSObject {
  external JSPromise<JSObject> loadAndProbe(JSObject source);
  external JSPromise<JSObject> renderPreview(JSObject payload);
  external JSPromise<JSObject> renderFull(JSObject payload);
  external JSPromise<JSObject> waveform(JSObject payload);
  external JSPromise<JSObject> cancel(JSString jobId);
  external JSPromise<JSObject> decodeToFloatPCM(JSObject source);
  external JSPromise<JSObject> encodeFromFloatPCM(JSObject payload);
  external JSPromise<JSObject> muxStillVideo(JSObject payload);
  external JSPromise<JSObject> resumeAudioContext();
  external void setProgressHandler(JSFunction? callback);
  external void setLogHandler(JSFunction? callback);
}

/// Helpers for moving data between Dart and the JS bridge.
class BridgeInterop {
  static Future<JSObject> loadAndProbe(JSObject payload) {
    return slowverbBridgeJS.loadAndProbe(payload).toDart;
  }

  static Future<JSObject> renderPreview(JSObject payload) {
    return slowverbBridgeJS.renderPreview(payload).toDart;
  }

  static Future<JSObject> renderFull(JSObject payload) {
    return slowverbBridgeJS.renderFull(payload).toDart;
  }

  static Future<JSObject> waveform(JSObject payload) {
    return slowverbBridgeJS.waveform(payload).toDart;
  }

  static Future<void> cancel(String jobId) {
    return slowverbBridgeJS.cancel(jobId.toJS).toDart.ignore();
  }

  static Future<JSObject> decodeToFloatPCM(JSObject payload) {
    return slowverbBridgeJS.decodeToFloatPCM(payload).toDart;
  }

  static Future<JSObject> encodeFromFloatPCM(JSObject payload) {
    return slowverbBridgeJS.encodeFromFloatPCM(payload).toDart;
  }

  static Future<JSObject> muxStillVideo(JSObject payload) {
    return slowverbBridgeJS.muxStillVideo(payload).toDart;
  }

  static void setProgressHandler(JSFunction? handler) {
    slowverbBridgeJS.setProgressHandler(handler);
  }

  static void setLogHandler(JSFunction? handler) {
    slowverbBridgeJS.setLogHandler(handler);
  }

  static Future<bool> resumeAudioContext() async {
    final result = await slowverbBridgeJS.resumeAudioContext().toDart;
    final type = result.getProperty<JSString?>('type'.toJS)?.toDart;
    return type == 'audio-context-ok';
  }

  static JSObject toJsObject(Map<String, Object?> map) {
    return map.jsify() as JSObject;
  }

  static Uint8List bufferToUint8List(JSObject buffer) {
    if (buffer.isA<JSArrayBuffer>()) {
      return (buffer as JSArrayBuffer).toDart.asUint8List();
    }
    if (buffer.isA<JSUint8Array>()) {
      return (buffer as JSUint8Array).toDart;
    }
    final objBuffer = buffer.getProperty<JSArrayBuffer?>('buffer'.toJS);
    if (objBuffer != null) {
      return objBuffer.toDart.asUint8List();
    }
    throw ArgumentError('Unsupported buffer type from bridge');
  }

  static AudioAnalysisTrack? analysisTrackFromJs(JSAny? value) {
    try {
      if (value == null) {
        return null;
      }
      if (!value.isA<JSObject>()) {
        return null;
      }
      final obj = value as JSObject;
      final sampleRateJs = obj.getProperty<JSNumber?>('sampleRate'.toJS);
      final fpsJs = obj.getProperty<JSNumber?>('fps'.toJS);
      final frameCountJs = obj.getProperty<JSNumber?>('frameCount'.toJS);
      final dataJs = obj.getProperty<JSAny?>('data'.toJS);
      if (sampleRateJs == null ||
          fpsJs == null ||
          frameCountJs == null ||
          dataJs == null) {
        return null;
      }
      if (!dataJs.isA<JSFloat32Array>()) {
        return null;
      }
      final sampleRate = sampleRateJs.toDartInt;
      final fps = fpsJs.toDartDouble;
      final frameCount = frameCountJs.toDartInt;
      final data = (dataJs as JSFloat32Array).toDart;
      try {
        return AudioAnalysisTrack(
          sampleRate: sampleRate,
          fps: fps,
          frameCount: frameCount,
          data: data,
        );
      } on ArgumentError {
        return null;
      }
    } catch (_) {
      return null;
    }
  }
}

extension _JsPromiseIgnore<T> on Future<T> {
  Future<void> ignore() => then((_) {});
}
