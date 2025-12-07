/// Status of a render/export job
enum RenderJobStatus { queued, running, success, failed, cancelled }

/// Represents an audio rendering/export job
///
/// Tracks the progress and status of an export operation.
class RenderJob {
  final String id;
  final String projectId;
  final RenderJobStatus status;
  final double progress;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? outputPath;
  final String? outputFormat;
  final int? outputBitrateKbps;
  final String? errorMessage;

  const RenderJob({
    required this.id,
    required this.projectId,
    required this.status,
    this.progress = 0.0,
    this.startedAt,
    this.finishedAt,
    this.outputPath,
    this.outputFormat,
    this.outputBitrateKbps,
    this.errorMessage,
  });

  /// Create a copy with updated fields
  RenderJob copyWith({
    String? id,
    String? projectId,
    RenderJobStatus? status,
    double? progress,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? outputPath,
    String? outputFormat,
    int? outputBitrateKbps,
    String? errorMessage,
  }) {
    return RenderJob(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      outputPath: outputPath ?? this.outputPath,
      outputFormat: outputFormat ?? this.outputFormat,
      outputBitrateKbps: outputBitrateKbps ?? this.outputBitrateKbps,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
