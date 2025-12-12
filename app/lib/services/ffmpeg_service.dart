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
  // Windows: GyanD builds
  static const _windowsDownloadUrl =
      'https://github.com/GyanD/codexffmpeg/releases/download/7.1/ffmpeg-7.1-essentials_build.zip';

  // macOS: evermeet.cx builds (trusted source for macOS FFmpeg)
  static const _macosFFmpegUrl =
      'https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip';
  static const _macosFFprobeUrl =
      'https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip';

  String? _ffmpegPath;
  String? _ffmpegDir;
  bool _isInitialized = false;
  double _downloadProgress = 0.0;

  /// Get current download progress (0.0 to 1.0)
  double get downloadProgress => _downloadProgress;

  /// Check if FFmpeg is ready to use
  bool get isReady => _isInitialized && _ffmpegPath != null;

  /// Get the absolute path to ffmpeg executable
  String? get executablePath => _ffmpegPath;

  /// Get the directory containing FFmpeg (for yt-dlp --ffmpeg-location)
  String? get executableDir => _ffmpegDir;

  /// Initialize FFmpeg - download if necessary
  Future<void> initialize({Function(double)? onProgress}) async {
    if (_isInitialized) return;

    try {
      // Get app support directory
      final appDir = await getApplicationSupportDirectory();
      final ffmpegDir = Directory(path.join(appDir.path, 'ffmpeg'));

      if (Platform.isWindows) {
        await _initializeWindows(ffmpegDir, onProgress);
      } else if (Platform.isMacOS) {
        await _initializeMacOS(ffmpegDir, onProgress);
      } else if (Platform.isLinux) {
        // On Linux, expect FFmpeg from system package manager
        await _initializeFromPath(onProgress);
      }
    } catch (e) {
      print('FFmpegService: Initialization error: $e');
      // Don't throw - fall back to system FFmpeg if available
      await _initializeFromPath(onProgress);
    }
  }

  /// Initialize FFmpeg on Windows (download zip with full package)
  Future<void> _initializeWindows(
    Directory ffmpegDir,
    Function(double)? onProgress,
  ) async {
    final ffmpegExe = File(
      path.join(
        ffmpegDir.path,
        'ffmpeg-7.1-essentials_build',
        'bin',
        'ffmpeg.exe',
      ),
    );

    if (await ffmpegExe.exists()) {
      _ffmpegPath = ffmpegExe.path;
      _ffmpegDir = path.dirname(ffmpegExe.path);
      _isInitialized = true;
      onProgress?.call(1.0);
      return;
    }

    // Download and extract FFmpeg for Windows
    await _downloadAndExtractZip(_windowsDownloadUrl, ffmpegDir, onProgress);

    if (await ffmpegExe.exists()) {
      _ffmpegPath = ffmpegExe.path;
      _ffmpegDir = path.dirname(ffmpegExe.path);
      _isInitialized = true;
    } else {
      throw Exception('FFmpeg extraction failed - executable not found');
    }
  }

  /// Initialize FFmpeg on macOS (download individual binaries)
  Future<void> _initializeMacOS(
    Directory ffmpegDir,
    Function(double)? onProgress,
  ) async {
    final binDir = Directory(path.join(ffmpegDir.path, 'bin'));
    final ffmpegExe = File(path.join(binDir.path, 'ffmpeg'));
    final ffprobeExe = File(path.join(binDir.path, 'ffprobe'));

    // Check if both exist
    if (await ffmpegExe.exists() && await ffprobeExe.exists()) {
      _ffmpegPath = ffmpegExe.path;
      _ffmpegDir = binDir.path;
      _isInitialized = true;
      onProgress?.call(1.0);
      print('FFmpegService: Using existing FFmpeg at ${ffmpegExe.path}');
      return;
    }

    // Create bin directory
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    print('FFmpegService: Downloading FFmpeg for macOS...');

    // Download FFmpeg
    onProgress?.call(0.1);
    await _downloadAndExtractMacOSBinary(_macosFFmpegUrl, binDir, 'ffmpeg');
    onProgress?.call(0.5);

    // Download FFprobe
    print('FFmpegService: Downloading FFprobe for macOS...');
    await _downloadAndExtractMacOSBinary(_macosFFprobeUrl, binDir, 'ffprobe');
    onProgress?.call(0.9);

    // Verify
    if (await ffmpegExe.exists()) {
      _ffmpegPath = ffmpegExe.path;
      _ffmpegDir = binDir.path;
      _isInitialized = true;
      onProgress?.call(1.0);
      print('FFmpegService: FFmpeg installed at ${ffmpegExe.path}');
    } else {
      throw Exception('FFmpeg download failed - executable not found');
    }
  }

  /// Download and extract a macOS binary from evermeet.cx zip
  Future<void> _downloadAndExtractMacOSBinary(
    String url,
    Directory targetDir,
    String binaryName,
  ) async {
    final zipPath = path.join(targetDir.path, '$binaryName.zip');
    final zipFile = File(zipPath);

    try {
      // Download
      print('FFmpegService: Downloading from $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      print('FFmpegService: Downloaded ${response.bodyBytes.length} bytes');
      await zipFile.writeAsBytes(response.bodyBytes);

      // Extract
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.isFile && file.name == binaryName) {
          final outFile = File(path.join(targetDir.path, binaryName));
          await outFile.writeAsBytes(file.content as List<int>);

          // Make executable
          await Process.run('chmod', ['+x', outFile.path]);

          // Remove quarantine attribute
          await Process.run('xattr', [
            '-d',
            'com.apple.quarantine',
            outFile.path,
          ]);

          print('FFmpegService: Extracted $binaryName');
          break;
        }
      }
    } finally {
      // Clean up zip file
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    }
  }

  /// Initialize from system PATH (fallback for Linux or if download fails)
  Future<void> _initializeFromPath(Function(double)? onProgress) async {
    try {
      final which = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(which, ['ffmpeg']);
      if (result.exitCode == 0) {
        final ffmpegPath = (result.stdout as String).split('\n').first.trim();
        if (ffmpegPath.isNotEmpty) {
          _ffmpegPath = ffmpegPath;
          _ffmpegDir = path.dirname(ffmpegPath);
          _isInitialized = true;
          onProgress?.call(1.0);
          print('FFmpegService: Using system FFmpeg at $ffmpegPath');
          return;
        }
      }
    } catch (_) {}

    // Not found in PATH
    print('FFmpegService: FFmpeg not found in PATH');
    onProgress?.call(1.0);
  }

  /// Download and extract Windows FFmpeg zip
  Future<void> _downloadAndExtractZip(
    String url,
    Directory targetDir,
    Function(double)? onProgress,
  ) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final zipPath = path.join(targetDir.path, 'ffmpeg.zip');
    final zipFile = File(zipPath);

    try {
      // Download
      onProgress?.call(0.0);
      final request = http.Request('GET', Uri.parse(url));
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
          _downloadProgress = downloadedBytes / contentLength * 0.8;
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
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    }
  }
}
