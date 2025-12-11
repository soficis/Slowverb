/// Supported categories of visualizers.
enum VisualizerType { screensaver, fractal, wmp }

/// Configuration for a visualizer preset.
class VisualizerPreset {
  final String id;
  final String name;
  final String description;
  final VisualizerType type;
  final String colorScheme; // e.g., "vaporwave", "luna", "frutigerAero"
  final double defaultIntensity; // 0..1

  const VisualizerPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.colorScheme,
    required this.defaultIntensity,
  });
}

/// Represents a single frame of audio analysis for driving visuals.
class AudioAnalysisFrame {
  final List<double> spectrum; // normalized magnitudes, e.g., 64 bands
  final double rms; // overall volume 0..1
  final double bass; // low band energy 0..1
  final double mid; // mid band energy 0..1
  final double treble; // high band energy 0..1
  final Duration time; // playback position

  const AudioAnalysisFrame({
    required this.spectrum,
    required this.rms,
    required this.bass,
    required this.mid,
    required this.treble,
    required this.time,
  });

  factory AudioAnalysisFrame.empty() {
    return const AudioAnalysisFrame(
      spectrum: [],
      rms: 0.0,
      bass: 0.0,
      mid: 0.0,
      treble: 0.0,
      time: Duration.zero,
    );
  }
}

/// Baseline nostalgic visualizer presets for web.
abstract final class VisualizerPresets {
  static const pipesVaporwave = VisualizerPreset(
    id: 'pipes_vaporwave',
    name: 'Pipes (Vaporwave)',
    description: 'Windows 3D Pipes homage with neon gradients.',
    type: VisualizerType.screensaver,
    colorScheme: 'vaporwave',
    defaultIntensity: 0.7,
  );

  static const starfieldWarp = VisualizerPreset(
    id: 'starfield_warp',
    name: 'Starfield Warp',
    description: 'Classic starfield flight with audio-driven speed.',
    type: VisualizerType.screensaver,
    colorScheme: 'frutigerAero',
    defaultIntensity: 0.8,
  );

  static const mazeNeon = VisualizerPreset(
    id: 'maze_neon',
    name: 'Maze Neon',
    description: 'Neon maze runner with turn frequency from mids.',
    type: VisualizerType.screensaver,
    colorScheme: 'luna',
    defaultIntensity: 0.65,
  );

  static const fractalDream = VisualizerPreset(
    id: 'fractal_dream',
    name: 'Fractal Dream',
    description: 'Mandelbrot/Julia zooms with palette shifts.',
    type: VisualizerType.fractal,
    colorScheme: 'vaporwave',
    defaultIntensity: 0.75,
  );

  static const wmpRetro = VisualizerPreset(
    id: 'wmp_retro',
    name: 'WMP Retro',
    description: 'Windows Media Player bars and waves throwback.',
    type: VisualizerType.wmp,
    colorScheme: 'frutigerAero',
    defaultIntensity: 0.7,
  );

  static const all = [
    pipesVaporwave,
    starfieldWarp,
    mazeNeon,
    fractalDream,
    wmpRetro,
  ];
}
