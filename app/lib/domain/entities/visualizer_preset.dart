/// Types of supported visualizers
enum VisualizerType { wmpRetro, starfield, fractal, pipes3d, maze3d }

/// Configuration for a visualizer style
class VisualizerPreset {
  final String id;
  final String name;
  final String description;
  final VisualizerType type;

  const VisualizerPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
  });
}

/// Represents a single frame of audio analysis data
class AudioAnalysisFrame {
  final List<double> magnitudes; // Normalized 0.0-1.0
  final double level; // Overall RMS level 0.0-1.0

  const AudioAnalysisFrame({required this.magnitudes, required this.level});

  factory AudioAnalysisFrame.empty() {
    return const AudioAnalysisFrame(magnitudes: [], level: 0.0);
  }
}
