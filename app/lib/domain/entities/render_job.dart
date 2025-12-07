/*
 * Copyright (C) 2025 Slowverb
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
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
