import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/domain/entities/audio_analysis_track.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';
import 'package:slowverb_web/features/visualizer/analysis_stream_controller.dart';

/// 10 fps keeps the arithmetic readable: frame f covers [f*100ms, (f+1)*100ms).
/// rms of frame f is f / 100 so tests can tell which frame was sampled.
AudioAnalysisTrack _track({int frames = 10, double fps = 10}) {
  final data = Float32List(frames * AudioAnalysisTrack.stride);
  for (var f = 0; f < frames; f++) {
    data[f * AudioAnalysisTrack.stride + 64] = f / 100;
  }
  return AudioAnalysisTrack(
    sampleRate: 44100,
    fps: fps,
    frameCount: frames,
    data: data,
  );
}

int _frameOf(AudioAnalysisFrame f) => (f.rms * 100).round();

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _Harness {
  _Harness({AudioAnalysisTrack? track, Duration latency = Duration.zero})
    : track = track ?? _track() {
    controller = AnalysisStreamController(
      track: () => this.track,
      position: () => position,
      playing: playing.stream,
      latency: latency,
      ticker: (interval) {
        requestedInterval = interval;
        return ticks.stream;
      },
    );
    controller.stream.listen(frames.add);
  }

  AudioAnalysisTrack? track;
  Duration position = Duration.zero;
  Duration? requestedInterval;
  final playing = StreamController<bool>();
  // Broadcast so the controller can cancel and resubscribe across pauses.
  final ticks = StreamController<void>.broadcast();
  final frames = <AudioAnalysisFrame>[];
  late final AnalysisStreamController controller;

  Future<void> tick([Duration? at]) async {
    if (at != null) position = at;
    ticks.add(null);
    await _flush();
  }

  Future<void> setPlaying(bool value) async {
    playing.add(value);
    await _flush();
  }
}

void main() {
  test('emits nothing until playback starts', () async {
    final h = _Harness();
    await h.tick(const Duration(milliseconds: 150));
    expect(h.frames, isEmpty);
    expect(h.controller.isTicking, isFalse);
  });

  test('defaults to ~30 fps', () async {
    final h = _Harness();
    await h.setPlaying(true);
    expect(h.requestedInterval, const Duration(milliseconds: 33));
  });

  test('samples the frame at the player position, stamped with it', () async {
    final h = _Harness();
    await h.setPlaying(true);
    await h.tick(const Duration(milliseconds: 0));
    await h.tick(const Duration(milliseconds: 250));
    await h.tick(const Duration(milliseconds: 730));
    expect(h.frames.map(_frameOf), [0, 2, 7]);
    expect(h.frames.last.time, const Duration(milliseconds: 730));
    expect(h.frames.last.spectrum, hasLength(64));
  });

  test('skips duplicate frames while the position stalls', () async {
    final h = _Harness();
    await h.setPlaying(true);
    await h.tick(const Duration(milliseconds: 210));
    await h.tick(const Duration(milliseconds: 210));
    await h.tick(const Duration(milliseconds: 290));
    expect(h.frames.map(_frameOf), [2]);
  });

  test('latency shifts sampling earlier, clamped at frame 0', () async {
    final h = _Harness(latency: const Duration(milliseconds: 60));
    await h.setPlaying(true);
    await h.tick(const Duration(milliseconds: 30)); // -30ms -> frame 0
    await h.tick(const Duration(milliseconds: 250)); // 190ms -> frame 1
    expect(h.frames.map(_frameOf), [0, 1]);
  });

  test('pause stops ticking; resume re-emits the current frame', () async {
    final h = _Harness();
    await h.setPlaying(true);
    await h.tick(const Duration(milliseconds: 310));
    await h.setPlaying(false);
    expect(h.controller.isTicking, isFalse);
    await h.tick(const Duration(milliseconds: 510));
    expect(h.frames.map(_frameOf), [3]);

    await h.setPlaying(true);
    await h.tick(const Duration(milliseconds: 310));
    expect(h.frames.map(_frameOf), [3, 3]);
  });

  test('track end emits one silent frame, stops, and stays open', () async {
    final h = _Harness();
    var closed = false;
    h.controller.stream.listen(null, onDone: () => closed = true);
    await h.setPlaying(true);
    await h.tick(const Duration(milliseconds: 950));
    await h.tick(const Duration(milliseconds: 1000));
    await h.tick(const Duration(milliseconds: 1200));

    expect(h.frames, hasLength(2));
    final end = h.frames.last;
    expect(end.rms, 0.0);
    expect(end.bass + end.mid + end.treble, 0.0);
    expect(end.spectrum, isEmpty);
    expect(end.time, const Duration(seconds: 1));
    expect(h.controller.isTicking, isFalse);
    expect(closed, isFalse);

    // Replay from the start works on the same stream.
    h.position = Duration.zero;
    await h.setPlaying(false);
    await h.setPlaying(true);
    await h.tick();
    expect(h.frames.map(_frameOf).last, 0);
    expect(h.frames, hasLength(3));
  });

  test('no track or an empty track emits nothing', () async {
    final h = _Harness();
    h.track = null;
    await h.setPlaying(true);
    await h.tick(const Duration(milliseconds: 100));
    h.track = _track(frames: 0);
    await h.tick(const Duration(milliseconds: 200));
    expect(h.frames, isEmpty);
  });

  test('picks up a re-rendered track without a restart', () async {
    final h = _Harness();
    await h.setPlaying(true);
    await h.tick(const Duration(milliseconds: 420));
    final next = _track(frames: 20, fps: 20); // 50ms frames
    h.track = next;
    await h.tick(const Duration(milliseconds: 420)); // same position, new track
    expect(h.frames.map(_frameOf), [4, 8]);
  });

  test('dispose closes the stream and stops ticking', () async {
    final h = _Harness();
    var closed = false;
    h.controller.stream.listen(null, onDone: () => closed = true);
    await h.setPlaying(true);
    await h.controller.dispose();
    await _flush();
    expect(closed, isTrue);
    expect(h.controller.isTicking, isFalse);
  });
}
