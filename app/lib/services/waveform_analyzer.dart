import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:slowverb/domain/entities/waveform_data.dart';

/// Service for analyzing audio files to extract waveform amplitude data.
/// Uses FFmpeg's volumedetect and astats filters for accurate analysis.
class WaveformAnalyzer {
  final String? ffmpegPath;

  WaveformAnalyzer({this.ffmpegPath});

  /// Analyzes an audio file and returns waveform data.
  ///
  /// The analysis extracts amplitude samples at regular intervals,
  /// creating a representation of the audio's volume over time.
  ///
  /// Results are cached to `<sourcePath>.waveform.json` for instant reload.
  Future<WaveformData> analyze(String sourcePath) async {
    // Check for cached waveform first
    final cacheFile = File('$sourcePath.waveform.json');
    if (await cacheFile.exists()) {
      try {
        final cached = await cacheFile.readAsString();
        return WaveformData.fromJsonString(cached);
      } catch (_) {
        // Cache corrupted, re-analyze
      }
    }

    // Find FFmpeg
    final ffmpeg = await _findFFmpeg();
    if (ffmpeg == null) {
      // Return empty waveform if FFmpeg not available
      return WaveformData.empty();
    }

    // Get audio duration first
    final durationMs = await _getAudioDuration(ffmpeg, sourcePath);
    if (durationMs <= 0) {
      return WaveformData.empty();
    }

    // Analyze audio using FFmpeg's ebur128 filter for accurate loudness
    // We'll sample roughly 100 points per second for smooth visualization
    final samples = await _extractAmplitudeSamples(
      ffmpeg,
      sourcePath,
      durationMs,
    );

    final waveformData = WaveformData(
      samples: samples,
      durationMs: durationMs,
      samplesPerSecond: 100,
    );

    // Cache the result
    try {
      await cacheFile.writeAsString(waveformData.toJsonString());
    } catch (_) {
      // Non-critical if caching fails
    }

    return waveformData;
  }

  /// Clears the waveform cache for a specific file.
  Future<void> clearCache(String sourcePath) async {
    final cacheFile = File('$sourcePath.waveform.json');
    if (await cacheFile.exists()) {
      await cacheFile.delete();
    }
  }

  Future<String?> _findFFmpeg() async {
    if (ffmpegPath != null && await File(ffmpegPath!).exists()) {
      return ffmpegPath;
    }

    // Check common locations
    final candidates = ['ffmpeg', 'ffmpeg.exe'];

    for (final candidate in candidates) {
      try {
        final result = await Process.run(
          Platform.isWindows ? 'where' : 'which',
          [candidate.replaceAll('.exe', '')],
        );
        if (result.exitCode == 0) {
          return candidate.replaceAll('.exe', '');
        }
      } catch (_) {}
    }

    // Check bundled location
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final bundled = '$exeDir/ffmpeg.exe';
    if (await File(bundled).exists()) {
      return bundled;
    }

    return null;
  }

  Future<int> _getAudioDuration(String ffmpeg, String sourcePath) async {
    try {
      final result = await Process.run(ffmpeg, [
        '-i',
        sourcePath,
        '-f',
        'null',
        '-',
      ], stderrEncoding: utf8);

      // Parse duration from stderr
      final stderr = result.stderr as String;
      final durationMatch = RegExp(
        r'Duration: (\d+):(\d+):(\d+)\.(\d+)',
      ).firstMatch(stderr);

      if (durationMatch != null) {
        final hours = int.parse(durationMatch.group(1)!);
        final minutes = int.parse(durationMatch.group(2)!);
        final seconds = int.parse(durationMatch.group(3)!);
        final centiseconds = int.parse(durationMatch.group(4)!);

        return (hours * 3600000) +
            (minutes * 60000) +
            (seconds * 1000) +
            (centiseconds * 10);
      }
    } catch (_) {}

    return 0;
  }

  Future<List<double>> _extractAmplitudeSamples(
    String ffmpeg,
    String sourcePath,
    int durationMs,
  ) async {
    try {
      // Use astats filter to get per-frame RMS levels
      // We'll process in small chunks to get granular data
      final result = await Process.run(ffmpeg, [
        '-i',
        sourcePath,
        '-af',
        'aresample=8000,astats=metadata=1:reset=1',
        '-f',
        'null',
        '-',
      ], stderrEncoding: utf8);

      final stderr = result.stderr as String;

      // Parse RMS levels from astats output
      final rmsPattern = RegExp(
        r'lavfi\.astats\.Overall\.RMS_level=(-?\d+\.?\d*)',
      );
      final matches = rmsPattern.allMatches(stderr);

      if (matches.isEmpty) {
        // Fallback: generate samples from basic volume analysis
        return _fallbackAmplitudeExtraction(ffmpeg, sourcePath, durationMs);
      }

      final samples = <double>[];
      for (final match in matches) {
        final rmsDb = double.tryParse(match.group(1)!) ?? -60.0;
        // Convert dB to linear (0.0 to 1.0)
        // -60dB = silence, 0dB = max
        final linear = pow(10, rmsDb / 20).clamp(0.0, 1.0).toDouble();
        samples.add(linear);
      }

      // Normalize samples to use full range
      if (samples.isNotEmpty) {
        final maxSample = samples.reduce(max);
        if (maxSample > 0) {
          for (var i = 0; i < samples.length; i++) {
            samples[i] = samples[i] / maxSample;
          }
        }
      }

      // Resample to consistent density (100 samples per second)
      final targetSamples = (durationMs / 10).round(); // 100 per second
      return _resample(samples, targetSamples);
    } catch (e) {
      return _fallbackAmplitudeExtraction(ffmpeg, sourcePath, durationMs);
    }
  }

  Future<List<double>> _fallbackAmplitudeExtraction(
    String ffmpeg,
    String sourcePath,
    int durationMs,
  ) async {
    // Simple fallback: use volumedetect to get overall stats
    // and generate a basic waveform based on that
    try {
      final result = await Process.run(ffmpeg, [
        '-i',
        sourcePath,
        '-af',
        'volumedetect',
        '-f',
        'null',
        '-',
      ], stderrEncoding: utf8);

      final stderr = result.stderr as String;

      // Get mean volume for fallback
      final meanMatch = RegExp(
        r'mean_volume: (-?\d+\.?\d*) dB',
      ).firstMatch(stderr);
      final maxMatch = RegExp(
        r'max_volume: (-?\d+\.?\d*) dB',
      ).firstMatch(stderr);

      final meanDb = double.tryParse(meanMatch?.group(1) ?? '-20') ?? -20.0;
      final maxDb = double.tryParse(maxMatch?.group(1) ?? '0') ?? 0.0;

      // Generate synthetic waveform based on overall volume
      final baseLevel = pow(10, meanDb / 20).clamp(0.0, 1.0).toDouble();
      final targetSamples = (durationMs / 10).round();

      final random = Random(sourcePath.hashCode);
      return List.generate(targetSamples, (i) {
        // Add variation but keep centered around mean
        final variation = (random.nextDouble() - 0.5) * 0.4;
        return (baseLevel + variation).clamp(0.0, 1.0);
      });
    } catch (_) {
      // Ultimate fallback: silent waveform
      return List.filled((durationMs / 10).round(), 0.0);
    }
  }

  List<double> _resample(List<double> source, int targetLength) {
    if (source.isEmpty) return List.filled(targetLength, 0.0);
    if (source.length == targetLength) return source;

    final result = <double>[];
    for (var i = 0; i < targetLength; i++) {
      final sourceIndex = (i / targetLength) * source.length;
      final lower = sourceIndex.floor().clamp(0, source.length - 1);
      final upper = sourceIndex.ceil().clamp(0, source.length - 1);
      final fraction = sourceIndex - lower;

      final value = source[lower] * (1 - fraction) + source[upper] * fraction;
      result.add(value);
    }

    return result;
  }
}
