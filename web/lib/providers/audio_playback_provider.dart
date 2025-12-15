import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Provider for audio playback
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();

  // Clean up player when provider is disposed
  ref.onDispose(() {
    player.dispose();
  });

  return player;
});

/// Provider for playback state
final playbackStateProvider = StreamProvider<PlayerState>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.playerStateStream;
});

/// Provider for playback position
final playbackPositionProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.positionStream;
});

/// Provider for playback duration
final playbackDurationProvider = StreamProvider<Duration?>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.durationStream;
});

/// Audio playback notifier
class AudioPlaybackNotifier extends StateNotifier<bool> {
  final Ref _ref;
  StreamSubscription<PlayerState>? _playerStateSub;

  AudioPlaybackNotifier(this._ref) : super(false) {
    _attachListeners();
  }

  void _attachListeners() {
    final player = _ref.read(audioPlayerProvider);
    _playerStateSub ??= player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = false;
      } else {
        state = playerState.playing;
      }
    });

    // Ensure subscription is cleaned up
    _ref.onDispose(() async {
      await _playerStateSub?.cancel();
    });
  }

  /// Load (if needed) and play a preview audio URL
  Future<void> loadAndPlay(Uri audioUri) async {
    final player = _ref.read(audioPlayerProvider);

    await player.setUrl(audioUri.toString());
    unawaited(player.play());
    state = true;
  }

  /// Play preview audio from URI
  Future<void> playPreview(Uri audioUri) async {
    try {
      await loadAndPlay(audioUri);
    } catch (e) {
      debugPrint('Error playing preview: $e');
      state = false;
    }
  }

  /// Stop playback
  Future<void> stop() async {
    final player = _ref.read(audioPlayerProvider);
    await player.stop();
    state = false;
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    final player = _ref.read(audioPlayerProvider);

    if (player.audioSource == null) {
      // Nothing loaded yet
      return;
    }

    if (player.playing) {
      await player.pause();
      state = false;
    } else {
      unawaited(player.play());
      state = true;
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    final player = _ref.read(audioPlayerProvider);
    await player.seek(position);
  }
}

/// Provider for audio playback control
final audioPlaybackProvider =
    StateNotifierProvider<AudioPlaybackNotifier, bool>((ref) {
      return AudioPlaybackNotifier(ref);
    });
