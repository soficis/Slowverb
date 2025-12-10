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

import 'dart:convert';
import 'dart:io';

/// Information about an audio file's codec
class CodecInfo {
  final String codecName;
  final String format;
  final int? sampleRate;
  final int? bitDepth;
  final bool isLossless;

  const CodecInfo({
    required this.codecName,
    required this.format,
    this.sampleRate,
    this.bitDepth,
    required this.isLossless,
  });

  @override
  String toString() =>
      'CodecInfo(codec: $codecName, format: $format, sampleRate: $sampleRate, lossless: $isLossless)';
}

/// Service to detect audio codec information from files
///
/// Uses FFprobe (bundled with FFmpeg) to extract codec metadata
class CodecDetector {
  /// List of lossless audio codecs
  static const losslessCodecs = {
    'pcm_s16le',
    'pcm_s24le',
    'pcm_s32le',
    'pcm_f32le',
    'pcm_f64le',
    'pcm_u8',
    'flac',
    'alac',
    'ape',
    'wavpack',
    'tta',
    'aiff',
    'wav',
  };

  final String? ffprobePath;

  CodecDetector({this.ffprobePath});

  /// Get codec information from an audio file
  ///
  /// Returns null if the file cannot be analyzed or FFprobe is not available
  Future<CodecInfo?> getCodecInfo(String filePath) async {
    // Find FFprobe executable
    final ffprobe = await _findFFprobe();
    if (ffprobe == null) {
      return null;
    }

    try {
      // Run ffprobe to get codec information as JSON
      final result = await Process.run(ffprobe, [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        '-select_streams',
        'a:0', // First audio stream
        filePath,
      ]);

      if (result.exitCode != 0) {
        return null;
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final streams = json['streams'] as List?;
      final format = json['format'] as Map<String, dynamic>?;

      if (streams == null || streams.isEmpty) {
        return null;
      }

      final audioStream = streams.first as Map<String, dynamic>;
      final codecName = audioStream['codec_name'] as String? ?? 'unknown';
      final formatName = format?['format_name'] as String? ?? 'unknown';
      final sampleRateStr = audioStream['sample_rate'] as String?;
      final bitsPerSampleStr = audioStream['bits_per_sample'] as String?;

      final sampleRate = sampleRateStr != null
          ? int.tryParse(sampleRateStr)
          : null;
      final bitDepth = bitsPerSampleStr != null
          ? int.tryParse(bitsPerSampleStr)
          : null;

      // Determine if codec is lossless
      final isLossless = _isCodecLossless(codecName, formatName);

      return CodecInfo(
        codecName: codecName,
        format: formatName,
        sampleRate: sampleRate,
        bitDepth: bitDepth,
        isLossless: isLossless,
      );
    } catch (e) {
      // Failed to analyze file
      return null;
    }
  }

  /// Quick check if a source file is lossless
  ///
  /// Returns false if unable to determine
  Future<bool> isSourceLossless(String filePath) async {
    final info = await getCodecInfo(filePath);
    return info?.isLossless ?? false;
  }

  /// Determine if a codec/format combination is lossless
  bool _isCodecLossless(String codecName, String formatName) {
    // Check codec name
    if (losslessCodecs.contains(codecName.toLowerCase())) {
      return true;
    }

    // Check format name (e.g., "wav", "aiff")
    final formats = formatName.toLowerCase().split(',');
    for (final format in formats) {
      if (losslessCodecs.contains(format.trim())) {
        return true;
      }
    }

    return false;
  }

  /// Find FFprobe executable
  ///
  /// Checks:
  /// 1. Provided path
  /// 2. System PATH
  /// 3. Common FFmpeg installation locations
  Future<String?> _findFFprobe() async {
    // 1. Use provided path
    if (ffprobePath != null && await File(ffprobePath!).exists()) {
      return ffprobePath;
    }

    // 2. Check system PATH
    final which = Platform.isWindows ? 'where' : 'which';
    final ffprobeCommand = Platform.isWindows ? 'ffprobe.exe' : 'ffprobe';

    try {
      final result = await Process.run(which, [ffprobeCommand]);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).split('\n').first.trim();
        if (path.isNotEmpty) {
          return path;
        }
      }
    } catch (_) {}

    // 3. Check common locations (where FFmpeg might be bundled)
    //    In Slowverb, FFmpeg is typically bundled with the app
    //    This would be in the same directory as ffmpeg executable
    //    For now, return null as we'll rely on PATH or provided path

    return null;
  }
}
