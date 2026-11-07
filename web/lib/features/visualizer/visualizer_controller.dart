import 'package:flutter_riverpod/legacy.dart';
import 'package:web/web.dart' as web;
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';

class VisualizerState {
  final VisualizerPreset activePreset;
  final bool isPlaying;

  const VisualizerState({required this.activePreset, this.isPlaying = false});
}

class VisualizerController extends StateNotifier<VisualizerState> {
  static const _storageKey = 'slowverb.visualizer';

  VisualizerController()
    : super(VisualizerState(activePreset: _initialPreset()));

  static List<VisualizerPreset> get presets => VisualizerPresets.all;

  /// The user's last choice if stored, otherwise a random calm one.
  static VisualizerPreset _initialPreset() {
    try {
      final id = web.window.localStorage.getItem(_storageKey);
      final stored = presets.where((p) => p.id == id).firstOrNull;
      if (stored != null) return stored;
    } catch (_) {
      // Storage blocked (private mode etc.): fall through to random.
    }
    return VisualizerPresets.random();
  }

  void selectPreset(String id) {
    if (state.activePreset.id == id) return;

    final preset = presets.firstWhere(
      (p) => p.id == id,
      orElse: () => VisualizerPresets.pipesVaporwave,
    );
    state = VisualizerState(activePreset: preset, isPlaying: state.isPlaying);
    try {
      web.window.localStorage.setItem(_storageKey, preset.id);
    } catch (_) {
      // Not persisting is fine.
    }
  }

  void setPlaying(bool isPlaying) {
    if (state.isPlaying == isPlaying) return;
    state = VisualizerState(
      activePreset: state.activePreset,
      isPlaying: isPlaying,
    );
  }
}

final visualizerProvider =
    StateNotifierProvider<VisualizerController, VisualizerState>((ref) {
      return VisualizerController();
    });
