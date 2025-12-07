/// Represents a user's audio editing project
///
/// Contains the source audio file path, selected preset,
/// parameter overrides, and export history.
class Project {
  final String id;
  final String name;
  final String sourcePath;
  final String? sourceTitle;
  final String? sourceArtist;
  final int durationMs;
  final String presetId;
  final Map<String, double> parameters;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? lastExportPath;
  final String? lastExportFormat;
  final int? lastExportBitrateKbps;
  final DateTime? lastExportDate;

  const Project({
    required this.id,
    required this.name,
    required this.sourcePath,
    this.sourceTitle,
    this.sourceArtist,
    required this.durationMs,
    required this.presetId,
    this.parameters = const {},
    this.createdAt,
    this.updatedAt,
    this.lastExportPath,
    this.lastExportFormat,
    this.lastExportBitrateKbps,
    this.lastExportDate,
  });

  /// Create a copy with updated fields
  Project copyWith({
    String? id,
    String? name,
    String? sourcePath,
    String? sourceTitle,
    String? sourceArtist,
    int? durationMs,
    String? presetId,
    Map<String, double>? parameters,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastExportPath,
    String? lastExportFormat,
    int? lastExportBitrateKbps,
    DateTime? lastExportDate,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      sourceArtist: sourceArtist ?? this.sourceArtist,
      durationMs: durationMs ?? this.durationMs,
      presetId: presetId ?? this.presetId,
      parameters: parameters ?? this.parameters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastExportPath: lastExportPath ?? this.lastExportPath,
      lastExportFormat: lastExportFormat ?? this.lastExportFormat,
      lastExportBitrateKbps:
          lastExportBitrateKbps ?? this.lastExportBitrateKbps,
      lastExportDate: lastExportDate ?? this.lastExportDate,
    );
  }
}
