import 'dart:typed_data';

import 'package:slowverb_web/domain/entities/visualizer_preset.dart';

/// Offline analysis of a rendered preview. Frame f covers the window starting at
/// f / fps seconds into the preview.
class AudioAnalysisTrack {
  static const int bandCount = 64;
  static const int stride = 68;

  AudioAnalysisTrack({
    required this.sampleRate,
    required this.fps,
    required this.frameCount,
    required this.data,
  }) {
    if (sampleRate <= 0) {
      throw ArgumentError('sampleRate must be > 0');
    }
    if (!fps.isFinite || fps <= 0) {
      throw ArgumentError('fps must be finite and > 0');
    }
    if (frameCount < 0) {
      throw ArgumentError('frameCount must be >= 0');
    }
    if (data.length != frameCount * stride) {
      throw ArgumentError(
        'data.length (${data.length}) must equal frameCount * stride '
        '(${frameCount * stride})',
      );
    }
  }

  final int sampleRate;
  final double fps;
  final int frameCount;
  final Float32List data;

  bool get isEmpty => frameCount == 0;

  Duration get duration =>
      Duration(microseconds: (frameCount / fps * 1e6).round());

  /// index = floor(position.inMicroseconds * fps / 1e6), clamped to [0, frameCount - 1].
  /// For an empty track returns -1.
  int frameIndexAt(Duration position) {
    if (frameCount == 0) {
      return -1;
    }
    final index = (position.inMicroseconds * fps / 1e6).floor();
    if (index < 0) {
      return 0;
    }
    if (index >= frameCount) {
      return frameCount - 1;
    }
    return index;
  }

  /// Frame at [position]. spectrum is Float32List.sublistView(data, base, base + 64)
  /// (a view, no copy); rms/bass/mid/treble read data[base + 64..67]; time = position.
  /// Empty track: AudioAnalysisFrame with spectrum const [], all values 0.0, time = position.
  AudioAnalysisFrame frameAt(Duration position) {
    if (frameCount == 0) {
      return AudioAnalysisFrame(
        spectrum: const [],
        rms: 0.0,
        bass: 0.0,
        mid: 0.0,
        treble: 0.0,
        time: position,
      );
    }
    final index = frameIndexAt(position);
    final base = index * stride;
    final spectrum = Float32List.sublistView(data, base, base + bandCount);
    return AudioAnalysisFrame(
      spectrum: spectrum,
      rms: data[base + 64],
      bass: data[base + 65],
      mid: data[base + 66],
      treble: data[base + 67],
      time: position,
    );
  }
}
