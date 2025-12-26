import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:slowverb_web/services/logger_service.dart';

/// Service for controlling audio playback with state management.
///
/// Extracted from AudioEditorNotifier to follow Single Responsibility Principle.
/// Handles play, pause, stop, seek operations and playback state.
class AudioPlaybackController {
  final AudioPlayer _player;
  static const _log = SlowverbLogger('AudioPlayback');

  AudioPlaybackController(this._player);

  /// Current playback position as normalized value (0.0 - 1.0).
  double get normalizedPosition {
    final duration = _player.duration;
    if (duration == null || duration.inMilliseconds == 0) return 0.0;
    return (_player.position.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  /// Whether playback is currently active.
  bool get isPlaying => _player.playing;

  /// Current playback duration.
  Duration? get duration => _player.duration;

  /// Current position.
  Duration get position => _player.position;

  /// Stream of position updates.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of player state updates.
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Play audio from a URI.
  ///
  /// If already playing, stops first.
  Future<void> playPreview(Uri uri) async {
    _log.debug('playPreview', uri);

    try {
      await _player.setUrl(uri.toString());
      await _player.play();
      _log.debug('Playback started');
    } catch (e, stack) {
      _log.error('playPreview failed', e, stack);
      rethrow;
    }
  }

  /// Stop playback and reset position.
  Future<void> stop() async {
    _log.debug('stop');
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  /// Pause playback without resetting position.
  Future<void> pause() async {
    _log.debug('pause');
    await _player.pause();
  }

  /// Resume playback from current position.
  Future<void> resume() async {
    _log.debug('resume');
    await _player.play();
  }

  /// Seek to specified position.
  Future<void> seekTo(Duration position) async {
    _log.debug('seekTo', position);
    await _player.seek(position);
  }

  /// Seek to normalized position (0.0 - 1.0).
  Future<void> seekToNormalized(
    double normalizedPosition,
    Duration totalDuration,
  ) async {
    final seekMs = (normalizedPosition * totalDuration.inMilliseconds).toInt();
    await seekTo(Duration(milliseconds: seekMs));
  }

  /// Dispose of resources.
  void dispose() {
    _log.debug('dispose');
    _player.dispose();
  }
}

/// Provider for audio playback controller.
final audioPlaybackControllerProvider = Provider<AudioPlaybackController>((
  ref,
) {
  final player = AudioPlayer();
  final controller = AudioPlaybackController(player);

  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});
