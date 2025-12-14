import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('SlowverbBridge')
external SlowverbBridgeJS get slowverbBridgeJS;

extension type SlowverbBridgeJS._(JSObject _) implements JSObject {
  external JSPromise<JSObject> loadAndProbe(JSObject source);
  external JSPromise<JSObject> renderPreview(JSObject payload);
  external JSPromise<JSObject> renderFull(JSObject payload);
  external JSPromise<JSObject> waveform(JSObject payload);
  external JSPromise<JSObject> cancel(JSString jobId);
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

  static void setProgressHandler(JSFunction? handler) {
    slowverbBridgeJS.setProgressHandler(handler);
  }

  static void setLogHandler(JSFunction? handler) {
    slowverbBridgeJS.setLogHandler(handler);
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
}

extension _JsPromiseIgnore<T> on Future<T> {
  Future<void> ignore() => then((_) {});
}
