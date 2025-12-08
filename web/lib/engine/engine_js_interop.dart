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

@JS()
library engine_js_interop;

import 'dart:js_util' as js_util;
import 'package:js/js.dart';

/// JavaScript interop for engine_wrapper.js
@JS('SlowverbEngine')
class SlowverbEngine {
  external static void initWorker();
  external static String postMessage(
    String type,
    dynamic payload,
    Function callback,
  );
  external static void setLogHandler(Function callback);
  external static void terminateWorker();
}

/// Helper class for creating JS objects from Dart maps
class JsInterop {
  static dynamic dartMapToJsObject(Map<String, dynamic> dartMap) {
    final jsObject = js_util.newObject();
    dartMap.forEach((key, value) {
      js_util.setProperty(jsObject, key, _convertValue(value));
    });
    return jsObject;
  }

  static dynamic _convertValue(dynamic value) {
    if (value is Map) {
      return dartMapToJsObject(value.cast<String, dynamic>());
    } else if (value is List) {
      return js_util.jsify(value);
    }
    return value;
  }

  static Map<String, dynamic> jsObjectToDartMap(dynamic jsObject) {
    final map = <String, dynamic>{};
    final keys = js_util.callMethod<List<dynamic>>(
      js_util.getProperty(jsObject, 'Object'),
      'keys',
      [jsObject],
    );

    for (final key in keys) {
      final value = js_util.getProperty(jsObject, key as String);
      map[key] = _convertFromJs(value);
    }

    return map;
  }

  static dynamic _convertFromJs(dynamic value) {
    if (js_util.hasProperty(value, 'constructor')) {
      final constructor = js_util.getProperty(value, 'constructor');
      final name = js_util.getProperty(constructor, 'name') as String;

      if (name == 'Object') {
        return jsObjectToDartMap(value);
      } else if (name == 'Array') {
        return js_util.dartify(value);
      }
    }
    return value;
  }
}
