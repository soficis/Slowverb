/// Supported categories of visualizers.
enum VisualizerType { screensaver, fractal, wmp, mystify, dvdBounce }

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
    name: 'Pipes',
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

  static const mazeRepeat = VisualizerPreset(
    id: 'maze_repeat',
    name: 'Maze Repeat',
    description: 'CPU-based neon maze with repeating patterns.',
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

  static const fractalDreams3d = VisualizerPreset(
    id: 'fractal_dreams_3d',
    name: 'Fractal Dreams 3D',
    description:
        'Enhanced fractal journey with spatial warping and chromatic effects.',
    type: VisualizerType.fractal,
    colorScheme: 'vaporwave',
    defaultIntensity: 0.8,
  );

  static const all = [
    pipesVaporwave,
    starfieldWarp,
    mazeNeon,
    mazeRepeat,
    fractalDream,
    fractalDreams3d,
    wmpRetro,
    mystify,
    dvdBounce,
    rainyWindow,
    rainyWindow3d,
    timeGate,
  ];

  static const mystify = VisualizerPreset(
    id: 'mystify',
    name: 'Mystify',
    description: 'Classic polygon morphing screensaver.',
    type: VisualizerType.mystify,
    colorScheme: 'luna',
    defaultIntensity: 0.8,
  );

  static const dvdBounce = VisualizerPreset(
    id: 'dvd_bounce',
    name: 'DVD Bounce',
    description: 'Bouncing logo homage that changes color on impact.',
    type: VisualizerType.dvdBounce,
    colorScheme: 'vaporwave',
    defaultIntensity: 0.6,
  );

  static const rainyWindow = VisualizerPreset(
    id: 'rainy_window',
    name: 'Rainy Window',
    description: '90s PC box gazing at a stormy day with lightning.',
    type: VisualizerType.screensaver,
    colorScheme: 'luna',
    defaultIntensity: 0.7,
  );

  static const rainyWindow3d = VisualizerPreset(
    id: 'rainy_window_3d',
    name: 'Rainy Window 3D',
    description: 'GPU-accelerated 3D scene with PC, CRT, rain, and lightning.',
    type: VisualizerType.screensaver,
    colorScheme: 'luna',
    defaultIntensity: 0.75,
  );

  static const timeGate = VisualizerPreset(
    id: 'time_gate',
    name: 'Time Gate',
    description: '3D time portal tunnel with temporal distortion effects.',
    type: VisualizerType.screensaver,
    colorScheme: 'vaporwave',
    defaultIntensity: 0.8,
  );

  /// Visualizers eligible for random selection (excludes WMP Retro and DVD Bounce)
  static const randomSelectable = [
    pipesVaporwave,
    starfieldWarp,
    mazeNeon,
    mazeRepeat,
    fractalDream,
    fractalDreams3d,
    mystify,
    rainyWindow,
    rainyWindow3d,
    timeGate,
  ];

  /// Returns a random visualizer from the selectable list
  static VisualizerPreset random() {
    final index =
        DateTime.now().millisecondsSinceEpoch % randomSelectable.length;
    return randomSelectable[index];
  }
}
