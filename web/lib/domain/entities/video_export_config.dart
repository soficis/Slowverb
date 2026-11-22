/// Output height of a video export. Width is always 16:9.
enum VideoResolution {
  p720(1280, 720, '720p'),
  p1080(1920, 1080, '1080p'),
  p2160(3840, 2160, '4K');

  const VideoResolution(this.width, this.height, this.label);

  final int width;
  final int height;
  final String label;
}

/// Speed/size trade-off for the H.264 encode. Maps to the x264 CRF value.
enum VideoQuality {
  fast(28, 'Fast'),
  balanced(23, 'Balanced'),
  slow(18, 'Best');

  const VideoQuality(this.crf, this.label);

  final int crf;
  final String label;
}

/// What sits behind the audio. `frame` (animated) is not supported yet.
enum VideoBackground {
  /// The source's cover art; black when the source has none.
  cover('Cover art'),
  solid('Black');

  const VideoBackground(this.label);

  final String label;
}

/// Settings for a still-image MP4 export.
class VideoExportConfig {
  const VideoExportConfig({
    this.resolution = VideoResolution.p1080,
    this.quality = VideoQuality.balanced,
    this.background = VideoBackground.cover,
  });

  final VideoResolution resolution;
  final VideoQuality quality;
  final VideoBackground background;

  /// Frame rate is fixed: the picture never changes.
  static const int fps = 30;

  int get width => resolution.width;
  int get height => resolution.height;
  int get crf => quality.crf;

  VideoExportConfig copyWith({
    VideoResolution? resolution,
    VideoQuality? quality,
    VideoBackground? background,
  }) {
    return VideoExportConfig(
      resolution: resolution ?? this.resolution,
      quality: quality ?? this.quality,
      background: background ?? this.background,
    );
  }
}
