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

import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Service for managing FFmpeg binary on desktop platforms
class FFmpegService {
  static const _ffmpegVersion = '7.1';
  static const _downloadUrl =
      'https://github.com/GyanD/codexffmpeg/releases/download/7.1/ffmpeg-7.1-essentials_build.zip';

  String? _ffmpegPath;
  bool _isInitialized = false;
  double _downloadProgress = 0.0;

  /// Get current download progress (0.0 to 1.0)
  double get downloadProgress => _downloadProgress;

  /// Check if FFmpeg is ready to use
  bool get isReady => _isInitialized && _ffmpegPath != null;

  /// Get the absolute path to ffmpeg executable
  String? get executablePath => _ffmpegPath;

  /// Initialize FFmpeg - download if necessary
  Future<void> initialize({Function(double)? onProgress}) async {
    if (_isInitialized) return;

    try {
      // Get app support directory
      final appDir = await getApplicationSupportDirectory();
      final ffmpegDir = Directory(path.join(appDir.path, 'ffmpeg'));

      // Check if ffmpeg already exists
      final ffmpegExe = File(
        path.join(
          ffmpegDir.path,
          'ffmpeg-$_ffmpegVersion-essentials_build',
          'bin',
          Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg',
        ),
      );

      if (await ffmpegExe.exists()) {
        _ffmpegPath = ffmpegExe.path;
        _isInitialized = true;
        onProgress?.call(1.0);
        return;
      }

      // Download and extract FFmpeg
      await _downloadAndExtractFFmpeg(ffmpegDir, onProgress);

      // Verify extraction
      if (await ffmpegExe.exists()) {
        _ffmpegPath = ffmpegExe.path;
        _isInitialized = true;
      } else {
        throw Exception('FFmpeg extraction failed - executable not found');
      }
    } catch (e) {
      throw Exception('Failed to initialize FFmpeg: $e');
    }
  }

  Future<void> _downloadAndExtractFFmpeg(
    Directory targetDir,
    Function(double)? onProgress,
  ) async {
    // Create directory if it doesn't exist
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final zipPath = path.join(targetDir.path, 'ffmpeg.zip');
    final zipFile = File(zipPath);

    try {
      // Download
      onProgress?.call(0.0);
      final request = http.Request('GET', Uri.parse(_downloadUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;

      final sink = zipFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0) {
          _downloadProgress =
              downloadedBytes / contentLength * 0.8; // 80% for download
          onProgress?.call(_downloadProgress);
        }
      }
      await sink.close();

      // Extract
      onProgress?.call(0.85);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = path.join(targetDir.path, file.name);
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);

          // Make executable on Unix systems
          if (!Platform.isWindows && filename.endsWith('ffmpeg')) {
            await Process.run('chmod', ['+x', filename]);
          }
        }
      }

      onProgress?.call(1.0);
    } finally {
      // Clean up zip file
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    }
  }
}
