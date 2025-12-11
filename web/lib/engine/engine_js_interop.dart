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

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// JavaScript interop for engine_wrapper.js
extension type SlowverbEngineJS._(JSObject _) implements JSObject {
  external void initWorker();
  external JSString postMessage(
    JSString type,
    JSAny? payload,
    JSFunction callback,
  );
  external void terminateWorker();
  external void setLogHandler(JSFunction callback);

  // Command-specific methods using JSAny to avoid strict type/nullability issues during debug
  external JSString loadSource(
    JSAny fileId,
    JSAny filename,
    JSAny bytes,
    JSFunction callback,
  );
  external JSString renderFull(
    JSAny fileId,
    JSAny filterChain,
    JSAny format,
    JSAny bitrateKbps,
    JSFunction callback,
  );
  external JSString probe(JSAny fileId, JSFunction callback);
}

/// Helpers to create JS objects with guaranteed property access
class PayloadFactory {
  static JSObject createLoadPayload(
    String fileId,
    String filename,
    Uint8List bytes,
  ) {
    final obj = JSObject();
    obj.setProperty('fileId'.toJS, fileId.toJS);
    obj.setProperty('filename'.toJS, filename.toJS);
    obj.setProperty('bytes'.toJS, bytes.toJS);
    return obj;
  }

  static JSObject createRenderPayload(
    String fileId,
    String filterChain,
    String? format,
    int? bitrateKbps,
  ) {
    final obj = JSObject();
    obj.setProperty('fileId'.toJS, fileId.toJS);
    obj.setProperty('filterChain'.toJS, filterChain.toJS);
    obj.setProperty('format'.toJS, (format ?? 'mp3').toJS);
    obj.setProperty('bitrateKbps'.toJS, (bitrateKbps ?? 192).toJS);
    return obj;
  }
}

/// Access the global SlowverbEngine object
@JS('SlowverbEngine')
external SlowverbEngineJS get slowverbEngineJS;

/// Wrapper class for SlowverbEngine calls
class SlowverbEngine {
  static void initWorker() {
    slowverbEngineJS.initWorker();
  }

  static String postMessage(
    String type,
    JSObject? payload,
    void Function(JSObject response) callback,
  ) {
    return slowverbEngineJS
        .postMessage(type.toJS, payload, callback.toJS)
        .toDart;
  }

  static String loadSource(
    String fileId,
    String filename,
    Uint8List bytes,
    void Function(JSObject response) callback,
  ) {
    // using callMethod to avoid static interop issues
    return (slowverbEngineJS.callMethod(
              'loadSource'.toJS,
              fileId.toJS,
              filename.toJS,
              bytes.toJS,
              callback.toJS,
            )
            as JSString)
        .toDart;
  }

  static String renderFull(
    String fileId,
    String filterChain,
    String format,
    int bitrateKbps,
    void Function(JSObject response) callback,
  ) {
    return slowverbEngineJS
        .renderFull(
          fileId.toJS,
          filterChain.toJS,
          format.toJS,
          bitrateKbps.toJS,
          callback.toJS,
        )
        .toDart;
  }

  static String probe(
    String fileId,
    void Function(JSObject response) callback,
  ) {
    return (slowverbEngineJS.callMethod(
              'probe'.toJS,
              fileId.toJS,
              callback.toJS,
            )
            as JSString)
        .toDart;
  }

  static String renderPreview(
    String fileId,
    JSObject config,
    void Function(JSObject response) callback,
  ) {
    return (slowverbEngineJS.callMethod(
              'renderPreview'.toJS,
              fileId.toJS,
              config,
              callback.toJS,
            )
            as JSString)
        .toDart;
  }

  static String getWaveform(
    String fileId,
    void Function(JSObject response) callback,
  ) {
    return (slowverbEngineJS.callMethod(
              'getWaveform'.toJS,
              fileId.toJS,
              callback.toJS,
            )
            as JSString)
        .toDart;
  }

  static void setLogHandler(void Function(String message) callback) {
    slowverbEngineJS.setLogHandler(
      ((JSString message) => callback(message.toDart)).toJS,
    );
  }

  static void terminateWorker() {
    slowverbEngineJS.terminateWorker();
  }
}

/// Helper class for creating JS objects from Dart maps
class JsInterop {
  /// Convert a Dart Map to a plain JavaScript object
  /// Uses jsify() to ensure properties are accessible in JS
  static JSObject dartMapToJsObject(Map<String, dynamic> dartMap) {
    // Use jsify() which properly creates a plain JS object
    // This ensures properties are enumerable and accessible
    return dartMap.jsify() as JSObject;
  }

  static Map<String, dynamic> jsObjectToDartMap(JSObject jsObject) {
    final map = <String, dynamic>{};
    final keysFunction = globalContext.getProperty('Object'.toJS) as JSObject;
    final keys = keysFunction.callMethod('keys'.toJS, jsObject) as JSArray;

    for (int i = 0; i < keys.length; i++) {
      final key = (keys[i] as JSString).toDart;
      final value = jsObject.getProperty(key.toJS);
      map[key] = _convertFromJs(value);
    }

    return map;
  }

  static dynamic _convertFromJs(JSAny? value) {
    if (value == null) return null;
    if (value.isA<JSString>()) return (value as JSString).toDart;
    if (value.isA<JSNumber>()) return (value as JSNumber).toDartDouble;
    if (value.isA<JSBoolean>()) return (value as JSBoolean).toDart;
    if (value.isA<JSArray>()) return (value as JSArray).toDart;
    if (value.isA<JSObject>()) {
      // Check if it's a plain object
      final constructor = (value as JSObject).getProperty('constructor'.toJS);
      if (constructor != null && constructor.isA<JSObject>()) {
        final name = (constructor as JSObject).getProperty('name'.toJS);
        if (name != null &&
            name.isA<JSString>() &&
            (name as JSString).toDart == 'Object') {
          return jsObjectToDartMap(value as JSObject);
        }
      }
    }
    return value;
  }
}
