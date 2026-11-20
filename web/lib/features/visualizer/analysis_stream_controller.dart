import 'dart:async';

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
/// - The track is read on every tick, so a re-rendered preview is picked up
///   without rebuilding the controller.
class AnalysisStreamController {
  AnalysisStreamController({
    required AudioAnalysisTrack? Function() track,
    required Duration Function() position,
    required Stream<bool> playing,
    this.interval = const Duration(milliseconds: 33),
    this.latency = defaultLatency,
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
        _emit(_silent(track.duration));
      }
      _stopTicker();
      return;
    }

    final index = track.frameIndexAt(position - latency);
    if (index == _lastIndex) return; // Position stalled (buffering/seeking).
    _lastIndex = index;
    final frame = track.frameAt(position - latency);
    _emit(
      AudioAnalysisFrame(
        spectrum: frame.spectrum,
        rms: frame.rms,
        bass: frame.bass,
        mid: frame.mid,
        treble: frame.treble,
        time: position,
      ),
    );
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
