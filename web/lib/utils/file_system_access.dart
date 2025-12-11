import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:web/web.dart' as web;

/// Best-effort wrapper around the File System Access API.
class FileSystemAccess {
  static bool get isSupported =>
      web.window.hasProperty('showOpenFilePicker'.toJS).toDart;

  /// Prompt the user to pick an audio file using the File System Access API.
  /// Falls back by returning null if unsupported or on any error.
  static Future<AudioFileData?> pickAudioFile() async {
    if (!isSupported) return null;

    try {
      final pickerOptions = {
        'types': [
          {
            'description': 'Audio Files',
            'accept': {
              'audio/*': ['.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg'],
            },
          },
        ],
        'multiple': false,
      }.jsify();

      final resultPromise = web.window.callMethod<JSPromise<JSArray>>(
        'showOpenFilePicker'.toJS,
        pickerOptions,
      );
      final result = await resultPromise.toDart;
      if (result.toDart.isEmpty) return null;

      final handle = result.toDart.first as JSObject;
      final filePromise = handle.callMethod<JSPromise<JSObject>>(
        'getFile'.toJS,
      );
      final file = await filePromise.toDart;

      final arrayBufferPromise = file.callMethod<JSPromise<JSArrayBuffer>>(
        'arrayBuffer'.toJS,
      );
      final arrayBuffer = await arrayBufferPromise.toDart;

      final bytes = arrayBuffer.toDart.asUint8List();
      final name =
          file.getProperty<JSString?>('name'.toJS)?.toDart ?? 'audio.file';

      return AudioFileData(
        filename: name,
        bytes: Uint8List.fromList(bytes),
        fileHandle: handle,
      );
    } catch (_) {
      return null;
    }
  }

  /// Read bytes from a previously stored handle.
  static Future<AudioFileData?> loadFromHandle(Object handle) async {
    try {
      final jsHandle = handle as JSObject;
      final filePromise = jsHandle.callMethod<JSPromise<JSObject>>(
        'getFile'.toJS,
      );
      final file = await filePromise.toDart;

      final arrayBufferPromise = file.callMethod<JSPromise<JSArrayBuffer>>(
        'arrayBuffer'.toJS,
      );
      final arrayBuffer = await arrayBufferPromise.toDart;

      final bytes = arrayBuffer.toDart.asUint8List();
      final name = file.getProperty<JSString?>('name'.toJS)?.toDart ?? 'audio';

      return AudioFileData(
        filename: name,
        bytes: Uint8List.fromList(bytes),
        fileHandle: handle,
      );
    } catch (_) {
      return null;
    }
  }
}
