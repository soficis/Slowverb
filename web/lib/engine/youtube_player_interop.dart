// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// YouTube player state constants (matching JS YT.PlayerState)
enum YouTubePlayerState {
  unstarted(-1),
  ended(0),
  playing(1),
  paused(2),
  buffering(3),
  cued(5);

  final int value;
  const YouTubePlayerState(this.value);

  static YouTubePlayerState fromValue(int value) {
    return YouTubePlayerState.values.firstWhere(
      (s) => s.value == value,
      orElse: () => YouTubePlayerState.unstarted,
    );
  }
}

/// Time update event from YouTube player
class YouTubeTimeUpdate {
  final double currentTime;
  final double duration;
  final YouTubePlayerState state;
  final double progress;

  YouTubeTimeUpdate({
    required this.currentTime,
    required this.duration,
    required this.state,
  }) : progress = duration > 0 ? currentTime / duration : 0;

  bool get isPlaying => state == YouTubePlayerState.playing;
}

/// Dart interop for YouTube Player JavaScript wrapper
class YouTubePlayerInterop {
  static final StreamController<YouTubePlayerState> _stateController =
      StreamController.broadcast();
  static final StreamController<YouTubeTimeUpdate> _timeController =
      StreamController.broadcast();

  static bool _initialized = false;

  /// Stream of playback state changes
  static Stream<YouTubePlayerState> get stateChanges => _stateController.stream;

  /// Stream of time updates (for visualizer sync)
  static Stream<YouTubeTimeUpdate> get timeUpdates => _timeController.stream;

  /// Initialize callbacks (call once on app start)
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Set up state change callback
    final stateCallback = (JSNumber state) {
      _stateController.add(YouTubePlayerState.fromValue(state.toDartInt));
    }.toJS;

    _getSlowverbYouTube()?.callMethod(
      'setPlaybackCallback'.toJS,
      stateCallback,
    );

    // Set up time update callback
    final timeCallback = (JSNumber time, JSNumber duration, JSNumber state) {
      _timeController.add(
        YouTubeTimeUpdate(
          currentTime: time.toDartDouble,
          duration: duration.toDartDouble,
          state: YouTubePlayerState.fromValue(state.toDartInt),
        ),
      );
    }.toJS;

    _getSlowverbYouTube()?.callMethod(
      'setTimeUpdateCallback'.toJS,
      timeCallback,
    );
  }

  /// Get the SlowverbYouTube global object
  static JSObject? _getSlowverbYouTube() {
    return globalContext['SlowverbYouTube'] as JSObject?;
  }

  /// Parse a YouTube URL to extract video ID
  static String? parseVideoId(String url) {
    final result = _getSlowverbYouTube()?.callMethod(
      'parseVideoId'.toJS,
      url.toJS,
    );
    if (result == null || result.isUndefinedOrNull) return null;
    return (result as JSString).toDart;
  }

  /// Initialize YouTube player with a video ID
  static Future<double> initPlayer(String videoId, String containerId) async {
    initialize();

    try {
      final promise = _getSlowverbYouTube()?.callMethod(
        'init'.toJS,
        videoId.toJS,
        containerId.toJS,
      );

      if (promise == null) {
        throw Exception('SlowverbYouTube not available');
      }

      final result = await (promise as JSPromise).toDart;
      if (result is JSObject) {
        final duration = result['duration'];
        if (duration is JSNumber) {
          return duration.toDartDouble;
        }
      }
      return 0;
    } catch (e) {
      throw Exception('Failed to initialize YouTube player: $e');
    }
  }

  /// Play the video
  static bool play() {
    final result = _getSlowverbYouTube()?.callMethod('play'.toJS);
    return result is JSBoolean && result.toDart;
  }

  /// Pause the video
  static bool pause() {
    final result = _getSlowverbYouTube()?.callMethod('pause'.toJS);
    return result is JSBoolean && result.toDart;
  }

  /// Seek to a specific time in seconds
  static bool seek(double seconds) {
    final result = _getSlowverbYouTube()?.callMethod('seek'.toJS, seconds.toJS);
    return result is JSBoolean && result.toDart;
  }

  /// Get current playback time in seconds
  static double getCurrentTime() {
    final result = _getSlowverbYouTube()?.callMethod('getCurrentTime'.toJS);
    if (result is JSNumber) {
      return result.toDartDouble;
    }
    return 0;
  }

  /// Get video duration in seconds
  static double getDuration() {
    final result = _getSlowverbYouTube()?.callMethod('getDuration'.toJS);
    if (result is JSNumber) {
      return result.toDartDouble;
    }
    return 0;
  }

  /// Get current player state
  static YouTubePlayerState getState() {
    final result = _getSlowverbYouTube()?.callMethod('getState'.toJS);
    if (result is JSNumber) {
      return YouTubePlayerState.fromValue(result.toDartInt);
    }
    return YouTubePlayerState.unstarted;
  }

  /// Destroy the player and clean up resources
  static void destroy() {
    _getSlowverbYouTube()?.callMethod('destroy'.toJS);
  }

  /// Check if YouTube player wrapper is available
  static bool get isAvailable => _getSlowverbYouTube() != null;
}
