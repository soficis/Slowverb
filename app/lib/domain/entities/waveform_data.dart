import 'dart:convert';

/// Represents analyzed waveform/amplitude data for an audio file.
/// Used to drive visualization synced to playback position.
class WaveformData {
  /// Normalized amplitude samples (0.0 to 1.0).
  /// Typically 100-1000 samples representing the entire audio duration.
  final List<double> samples;

  /// Duration of the audio in milliseconds.
  final int durationMs;

  /// Number of samples per second used during analysis.
  final int samplesPerSecond;

  const WaveformData({
    required this.samples,
    required this.durationMs,
    this.samplesPerSecond = 100,
  });

  /// Creates empty waveform data.
  factory WaveformData.empty() {
    return const WaveformData(samples: [], durationMs: 0);
  }

  /// Gets the amplitude at a specific playback position.
  /// Returns 0.0 if position is out of bounds.
  double getSampleAtPosition(Duration position) {
    if (samples.isEmpty || durationMs <= 0) return 0.0;

    final positionMs = position.inMilliseconds.clamp(0, durationMs);
    final progress = positionMs / durationMs;
    final index = (progress * (samples.length - 1)).floor();

    return samples[index.clamp(0, samples.length - 1)];
  }

  /// Gets a spectrum-like slice of bands centered around the current position.
  /// Returns [bandCount] bands of averaged amplitude data.
  ///
  /// This creates a "fake spectrum" by sampling nearby amplitudes,
  /// which works well for visualization purposes.
  List<double> getSpectrumSlice(Duration position, {int bandCount = 32}) {
    if (samples.isEmpty || durationMs <= 0) {
      return List.filled(bandCount, 0.0);
    }

    final positionMs = position.inMilliseconds.clamp(0, durationMs);
    final progress = positionMs / durationMs;
    final centerIndex = (progress * (samples.length - 1)).floor();

    final bands = <double>[];
    final windowSize = (samples.length / bandCount).ceil();

    for (var i = 0; i < bandCount; i++) {
      // Sample from around the current position with some spread
      final offset = (i - bandCount ~/ 2) * 2;
      final sampleIndex = (centerIndex + offset).clamp(0, samples.length - 1);

      // Average a small window for smoother visualization
      var sum = 0.0;
      var count = 0;
      for (var j = -2; j <= 2; j++) {
        final idx = (sampleIndex + j).clamp(0, samples.length - 1);
        sum += samples[idx];
        count++;
      }

      // Add some variation based on band index (lower bands = more bass-like)
      final bassBias = 1.0 - (i / bandCount) * 0.3;
      bands.add((sum / count) * bassBias);
    }

    return bands;
  }

  /// Gets the overall level (average amplitude) around the current position.
  double getLevelAtPosition(Duration position, {int windowSize = 10}) {
    if (samples.isEmpty || durationMs <= 0) return 0.0;

    final positionMs = position.inMilliseconds.clamp(0, durationMs);
    final progress = positionMs / durationMs;
    final centerIndex = (progress * (samples.length - 1)).floor();

    var sum = 0.0;
    var count = 0;

    for (var i = -windowSize; i <= windowSize; i++) {
      final idx = (centerIndex + i).clamp(0, samples.length - 1);
      sum += samples[idx];
      count++;
    }

    return sum / count;
  }

  /// Serializes to JSON for caching.
  Map<String, dynamic> toJson() {
    return {
      'samples': samples,
      'durationMs': durationMs,
      'samplesPerSecond': samplesPerSecond,
    };
  }

  /// Deserializes from JSON cache.
  factory WaveformData.fromJson(Map<String, dynamic> json) {
    return WaveformData(
      samples: (json['samples'] as List).cast<double>(),
      durationMs: json['durationMs'] as int,
      samplesPerSecond: json['samplesPerSecond'] as int? ?? 100,
    );
  }

  /// Serializes to compact JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Deserializes from JSON string.
  factory WaveformData.fromJsonString(String jsonString) {
    return WaveformData.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  bool get isEmpty => samples.isEmpty;
  bool get isNotEmpty => samples.isNotEmpty;
}
