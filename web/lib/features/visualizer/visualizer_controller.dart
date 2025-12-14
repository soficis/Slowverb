import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';

class VisualizerState {
  final VisualizerPreset activePreset;
  final bool isPlaying;

  const VisualizerState({required this.activePreset, this.isPlaying = false});
}

class VisualizerController extends StateNotifier<VisualizerState> {
  VisualizerController()
    : super(VisualizerState(activePreset: VisualizerPresets.random()));

  static List<VisualizerPreset> get presets => VisualizerPresets.all;

  void selectPreset(String id) {
    if (state.activePreset.id == id) return;

    final preset = presets.firstWhere(
      (p) => p.id == id,
      orElse: () => VisualizerPresets.pipesVaporwave,
    );
    state = VisualizerState(activePreset: preset, isPlaying: state.isPlaying);
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
