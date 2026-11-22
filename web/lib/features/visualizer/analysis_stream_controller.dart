import 'dart:async';
import 'dart:typed_data';

import 'package:slowverb_web/domain/entities/audio_analysis_track.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';

/// Produces a periodic tick stream. Injected so tests can drive time by hand.
typedef TickerFactory = Stream<void> Function(Duration interval);

Stream<void> _periodicTicker(Duration interval) =>
    Stream<void>.periodic(interval);

/// Samples the offline [AudioAnalysisTrack] at the player's position and
/// emits [AudioAnalysisFrame]s at roughly [interval] (default ~30 fps).
///
/// - Ticks only while [playing] reports true; pausing stops the ticker and
///   leaves the last frame in place.
/// - When the position reaches the end of the track, one silent frame is
///   emitted and the ticker stops until playback starts again. The stream
///   itself stays open: listeners hold one subscription across replays and
///   re-rendered previews.
/// - Values are smoothed per emitted frame with a fast [attack] and a slower
///   [release] (fractions of the gap closed per frame; 1.0 = no smoothing).
///   Raw 43 fps frames jump by up to ~0.6 between neighbours on a loud master,
///   which reads as strobing; 0.5/0.12 keeps beats punchy and removes that.
/// - The track is read on every tick, so a re-rendered preview is picked up
///   without rebuilding the controller.
class AnalysisStreamController {
  AnalysisStreamController({
    required AudioAnalysisTrack? Function() track,
    required Duration Function() position,
    required Stream<bool> playing,
    this.interval = const Duration(milliseconds: 33),
    this.latency = defaultLatency,
    this.attack = 0.5,
    this.release = 0.12,
    TickerFactory ticker = _periodicTicker,
  }) : _track = track,
       _position = position,
       _ticker = ticker {
    _playingSub = playing.distinct().listen(_onPlaying);
  }

  /// The analysis window is 2048 samples starting at each frame's time, so its
  /// centre sits ~23 ms after the frame start at 44.1 kHz. Sampling this much
  /// earlier centres the window on the audible position.
  static const Duration defaultLatency = Duration(milliseconds: 23);

  final Duration interval;
  final Duration latency;
  final double attack;
  final double release;

  final AudioAnalysisTrack? Function() _track;
  final Duration Function() _position;
  final TickerFactory _ticker;

  final StreamController<AudioAnalysisFrame> _out =
      StreamController<AudioAnalysisFrame>.broadcast();
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<void>? _tickSub;

  AudioAnalysisTrack? _lastTrack;
  int _lastIndex = -1;
  bool _ended = false;

  // Smoothed state: spectrum (64 bands) then rms, bass, mid, treble.
  final Float64List _smooth = Float64List(AudioAnalysisTrack.bandCount + 4);

  Stream<AudioAnalysisFrame> get stream => _out.stream;

  bool get isTicking => _tickSub != null;

  void _onPlaying(bool playing) {
    if (playing) {
      _ended = false;
      _lastIndex = -1;
      _tickSub ??= _ticker(interval).listen((_) => _tick());
    } else {
      _stopTicker();
    }
  }

  void _tick() {
    final track = _track();
    if (track == null || track.isEmpty) return;
    if (!identical(track, _lastTrack)) {
      _lastTrack = track;
      _lastIndex = -1;
      _ended = false;
    }

    final position = _position();
    if (position >= track.duration) {
      if (!_ended) {
        _ended = true;
        _smooth.fillRange(0, _smooth.length, 0.0);
        _emit(_silent(track.duration));
      }
      _stopTicker();
      return;
    }

    final index = track.frameIndexAt(position - latency);
    if (index == _lastIndex) return; // Position stalled (buffering/seeking).
    _lastIndex = index;
    final frame = track.frameAt(position - latency);
    const n = AudioAnalysisTrack.bandCount;
    final spectrum = Float32List(n);
    for (var k = 0; k < n; k++) {
      spectrum[k] = _follow(k, frame.spectrum[k]);
    }
    _emit(
      AudioAnalysisFrame(
        spectrum: spectrum,
        rms: _follow(n, frame.rms),
        bass: _follow(n + 1, frame.bass),
        mid: _follow(n + 2, frame.mid),
        treble: _follow(n + 3, frame.treble),
        time: position,
      ),
    );
  }

  double _follow(int i, double target) {
    final current = _smooth[i];
    final k = target > current ? attack : release;
    return _smooth[i] = current + k * (target - current);
  }

  static AudioAnalysisFrame _silent(Duration time) => AudioAnalysisFrame(
    spectrum: const [],
    rms: 0.0,
    bass: 0.0,
    mid: 0.0,
    treble: 0.0,
    time: time,
  );

  void _emit(AudioAnalysisFrame frame) {
    if (!_out.isClosed) _out.add(frame);
  }

  void _stopTicker() {
    _tickSub?.cancel();
    _tickSub = null;
  }

  Future<void> dispose() async {
    _stopTicker();
    await _playingSub?.cancel();
    _playingSub = null;
    await _out.close();
  }
}
