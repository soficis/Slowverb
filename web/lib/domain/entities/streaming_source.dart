/// Describes a streaming media source (YouTube or direct URL).
class StreamingSource {
  final Uri url;
  final bool isYouTube;
  final String? title;
  final Duration? duration;

  const StreamingSource({
    required this.url,
    required this.isYouTube,
    this.title,
    this.duration,
  });

  StreamingSource copyWith({
    Uri? url,
    bool? isYouTube,
    String? title,
    Duration? duration,
  }) {
    return StreamingSource(
      url: url ?? this.url,
      isYouTube: isYouTube ?? this.isYouTube,
      title: title ?? this.title,
      duration: duration ?? this.duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url.toString(),
      'isYouTube': isYouTube,
      'title': title,
      'durationMs': duration?.inMilliseconds,
    };
  }

  factory StreamingSource.fromJson(Map<String, dynamic> json) {
    return StreamingSource(
      url: Uri.parse(json['url'] as String),
      isYouTube: json['isYouTube'] as bool? ?? false,
      title: json['title'] as String?,
      duration: _parseDuration(json['durationMs']),
    );
  }

  static Duration? _parseDuration(dynamic value) {
    if (value == null) return null;
    if (value is int) return Duration(milliseconds: value);
    if (value is num) return Duration(milliseconds: value.toInt());
    return null;
  }
}

/// Capability detected for a streaming source.
enum StreamingCapability {
  unknown,
  fullEffects,
  visualizerOnly,
  unavailable,
}
