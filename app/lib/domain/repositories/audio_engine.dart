/// Abstract interface for audio processing operations
///
/// All audio processing (preview and render) goes through this interface.
/// This allows swapping implementations (FFmpeg, native DSP, etc.)
/// without changing the rest of the app.
abstract class AudioEngine {
  /// Initialize the audio engine
  Future<void> initialize();

  /// Dispose of resources
  Future<void> dispose();

  /// Start preview playback with the given effects applied
  ///
  /// Returns the path to the processed preview file.
  Future<String> startPreview({
    required String sourcePath,
    required Map<String, double> params,
  });

  /// Stop preview playback
  Future<void> stopPreview();

  /// Render the full track with effects to the output path
  ///
  /// Returns a stream of progress updates (0.0 to 1.0).
  Stream<double> render({
    required String sourcePath,
    required Map<String, double> params,
    required String outputPath,
    required String format,
    int? bitrateKbps,
  });

  /// Cancel an ongoing render operation
  Future<void> cancelRender();

  /// Check if FFmpeg is available on this platform
  Future<bool> isAvailable();
}

/// Result of a render operation
class RenderResult {
  final bool success;
  final String? outputPath;
  final String? errorMessage;
  final Duration? duration;

  const RenderResult({
    required this.success,
    this.outputPath,
    this.errorMessage,
    this.duration,
  });
}
