import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/legacy.dart';
import 'package:web/web.dart' as web;
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';

class VisualizerState {
  final VisualizerPreset activePreset;
  final bool isPlaying;

  /// Shuffle mode: a random calm scene, changed every [VisualizerController.shuffleInterval]
  /// of playback.
  final bool shuffle;

  const VisualizerState({
    required this.activePreset,
    this.isPlaying = false,
    this.shuffle = false,
  });

  VisualizerState copyWith({
    VisualizerPreset? activePreset,
    bool? isPlaying,
    bool? shuffle,
  }) => VisualizerState(
    activePreset: activePreset ?? this.activePreset,
    isPlaying: isPlaying ?? this.isPlaying,
    shuffle: shuffle ?? this.shuffle,
  );
}

class VisualizerController extends StateNotifier<VisualizerState> {
  static const _storageKey = 'slowverb.visualizer';
  static const _shuffleId = 'shuffle';
  static const shuffleInterval = Duration(minutes: 2);

  static final _rng = Random();
  Timer? _shuffleTimer;

  VisualizerController() : super(_initialState());

  static List<VisualizerPreset> get presets => VisualizerPresets.all;

  /// The user's last choice if stored; otherwise (and for "shuffle") a random
  /// calm scene.
  static VisualizerState _initialState() {
    String? id;
    try {
      id = web.window.localStorage.getItem(_storageKey);
    } catch (_) {
      // Storage blocked (private mode etc.): fall through to shuffle.
    }
    final stored = presets.where((p) => p.id == id).firstOrNull;
    if (stored != null) return VisualizerState(activePreset: stored);
    return VisualizerState(activePreset: _randomExcept(null), shuffle: true);
  }

  static VisualizerPreset _randomExcept(VisualizerPreset? current) {
    final pool = VisualizerPresets.randomSelectable
        .where((p) => p.id != current?.id)
        .toList();
    return pool[_rng.nextInt(pool.length)];
  }

  void _persist(String id) {
    try {
      web.window.localStorage.setItem(_storageKey, id);
    } catch (_) {
      // Not persisting is fine.
    }
  }

  void selectPreset(String id) {
    final preset = presets.firstWhere(
      (p) => p.id == id,
      orElse: () => VisualizerPresets.pipesVaporwave,
    );
    state = state.copyWith(activePreset: preset, shuffle: false);
    _syncTimer();
    _persist(preset.id);
  }

  /// Turn on shuffle: switch to a different random scene now, then keep
  /// changing while music plays.
  void selectShuffle() {
    state = state.copyWith(
      activePreset: _randomExcept(state.activePreset),
      shuffle: true,
    );
    _syncTimer();
    _persist(_shuffleId);
  }

  void setPlaying(bool isPlaying) {
    if (state.isPlaying == isPlaying) return;
    state = state.copyWith(isPlaying: isPlaying);
    _syncTimer();
  }

  /// The shuffle timer runs only while shuffling and playing, so a paused
  /// track keeps its scene.
  void _syncTimer() {
    final shouldRun = state.shuffle && state.isPlaying;
    if (shouldRun && _shuffleTimer == null) {
      _shuffleTimer = Timer.periodic(shuffleInterval, (_) {
        state = state.copyWith(activePreset: _randomExcept(state.activePreset));
      });
    } else if (!shouldRun) {
      _shuffleTimer?.cancel();
      _shuffleTimer = null;
    }
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    super.dispose();
  }
}

final visualizerProvider =
    StateNotifierProvider<VisualizerController, VisualizerState>((ref) {
      return VisualizerController();
    });
