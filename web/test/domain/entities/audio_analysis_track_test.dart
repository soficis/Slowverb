import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/domain/entities/audio_analysis_track.dart';

AudioAnalysisTrack buildTrack() {
  const fps = 10.0;
  const sampleRate = 44100;
  const frameCount = 5;
  final data = Float32List(frameCount * AudioAnalysisTrack.stride);
  for (var f = 0; f < frameCount; f++) {
    final value = (f + 1) / 10;
    for (var i = 0; i < AudioAnalysisTrack.stride; i++) {
      data[f * AudioAnalysisTrack.stride + i] = value;
    }
  }
  return AudioAnalysisTrack(
    sampleRate: sampleRate,
    fps: fps,
    frameCount: frameCount,
    data: data,
  );
}

void main() {
  group('AudioAnalysisTrack', () {
    test('a. negative position clamps to frame 0', () {
      final track = buildTrack();
      const position = Duration(milliseconds: -50);
      final frame = track.frameAt(position);
      expect(frame.rms, closeTo(0.1, 1e-6));
      expect(frame.time, position);
    });

    test('b. far future position clamps to last frame', () {
      final track = buildTrack();
      final frame = track.frameAt(const Duration(seconds: 10));
      expect(frame.rms, closeTo(0.5, 1e-6));
    });

    test('c. exact boundary maps to correct frames', () {
      final track = buildTrack();
      final at200 = track.frameAt(const Duration(milliseconds: 200));
      expect(at200.rms, closeTo(0.3, 1e-6));
      final at199 = track.frameAt(const Duration(milliseconds: 199));
      expect(at199.rms, closeTo(0.2, 1e-6));
    });

    test('d. spectrum length and values', () {
      final track = buildTrack();
      final frame = track.frameAt(const Duration(milliseconds: 150));
      expect(frame.spectrum.length, 64);
      for (final value in frame.spectrum) {
        expect(value, closeTo(0.2, 1e-6));
      }
      expect(frame.bass, closeTo(0.2, 1e-6));
      expect(frame.mid, closeTo(0.2, 1e-6));
      expect(frame.treble, closeTo(0.2, 1e-6));
    });

    test('e. spectrum is a view', () {
      final track = buildTrack();
      track.data[2 * AudioAnalysisTrack.stride] = 0.9;
      final frame = track.frameAt(const Duration(milliseconds: 250));
      expect(frame.spectrum[0], closeTo(0.9, 1e-6));
    });

    test('f. duration is 500ms', () {
      final track = buildTrack();
      expect(track.duration, const Duration(milliseconds: 500));
    });

    test('g. empty track', () {
      final track = AudioAnalysisTrack(
        sampleRate: 44100,
        fps: 10.0,
        frameCount: 0,
        data: Float32List(0),
      );
      expect(track.isEmpty, isTrue);
      expect(track.frameIndexAt(const Duration(seconds: 1)), -1);
      final frame = track.frameAt(const Duration(seconds: 1));
      expect(frame.spectrum, isEmpty);
      expect(frame.rms, closeTo(0.0, 1e-6));
      expect(frame.time, const Duration(seconds: 1));
    });

    test('h. constructor throws ArgumentError', () {
      expect(
        () => AudioAnalysisTrack(
          sampleRate: 44100,
          fps: 10.0,
          frameCount: 1,
          data: Float32List(67),
        ),
        throwsArgumentError,
      );
      expect(
        () => AudioAnalysisTrack(
          sampleRate: 44100,
          fps: 0,
          frameCount: 1,
          data: Float32List(68),
        ),
        throwsArgumentError,
      );
      expect(
        () => AudioAnalysisTrack(
          sampleRate: 44100,
          fps: double.nan,
          frameCount: 1,
          data: Float32List(68),
        ),
        throwsArgumentError,
      );
    });
  });
}
