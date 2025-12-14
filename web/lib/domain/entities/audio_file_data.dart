import 'dart:typed_data';

/// Data class for passing audio file information
class AudioFileData {
  final String filename;
  final Uint8List bytes;
  final Object? fileHandle; // File System Access API handle (if available)

  const AudioFileData({
    required this.filename,
    required this.bytes,
    this.fileHandle,
  });

  /// Get file extension
  String get extension {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Get file size in bytes
  int get sizeBytes => bytes.length;

  /// Get human-readable file size
  String get sizeFormatted {
    final kb = sizeBytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
