import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('JSZip')
extension type JSZip._(JSObject _) implements JSObject {
  external JSZip();

  /// Adds a file to the zip. [data] can be Uint8List (via toJS)
  external void file(String name, JSAny data);

  /// Generates the zip content asynchronously.
  /// options example: {'type': 'uint8array'}
  external JSPromise<JSAny> generateAsync(JSObject options);
}

/// Service for creating ZIP archives using JSZip
class ZipExportService {
  /// Create a ZIP archive from a map of filename -> bytes
  Future<Uint8List> createZip(Map<String, Uint8List> files) async {
    try {
      final zip = JSZip();

      files.forEach((name, bytes) {
        zip.file(name, bytes.toJS);
      });

      final options = {'type': 'uint8array'}.jsify() as JSObject;
      final result = await zip.generateAsync(options).toDart;

      return (result as JSUint8Array).toDart;
    } catch (e) {
      // ignore: avoid_print
      print('[ZipExportService] Error creating ZIP: $e');
      rethrow;
    }
  }
}
