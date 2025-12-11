/// Represents a user's audio editing project on web.
///
/// Mirrors the desktop/mobile `Project` shape while allowing web-specific
/// handles (e.g., File System Access API IDs instead of absolute paths).
class Project {
  final String id;
  final String name;
  final String? sourcePath; // Logical handle or persisted path reference
  final String? sourceHandleId; // For File System Access API handles
  final String? sourceFileName;
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
    this.sourcePath,
    this.sourceHandleId,
    this.sourceFileName,
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

  Project copyWith({
    String? id,
    String? name,
    String? sourcePath,
    String? sourceHandleId,
    String? sourceFileName,
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
      sourceHandleId: sourceHandleId ?? this.sourceHandleId,
      sourceFileName: sourceFileName ?? this.sourceFileName,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sourcePath': sourcePath,
      'sourceHandleId': sourceHandleId,
      'sourceFileName': sourceFileName,
      'sourceTitle': sourceTitle,
      'sourceArtist': sourceArtist,
      'durationMs': durationMs,
      'presetId': presetId,
      'parameters': parameters,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastExportPath': lastExportPath,
      'lastExportFormat': lastExportFormat,
      'lastExportBitrateKbps': lastExportBitrateKbps,
      'lastExportDate': lastExportDate?.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    final rawParams =
        (json['parameters'] as Map?)?.cast<String, dynamic>() ?? {};

    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      sourcePath: json['sourcePath'] as String?,
      sourceHandleId: json['sourceHandleId'] as String?,
      sourceFileName: json['sourceFileName'] as String?,
      sourceTitle: json['sourceTitle'] as String?,
      sourceArtist: json['sourceArtist'] as String?,
      durationMs: (json['durationMs'] as num).toInt(),
      presetId: json['presetId'] as String,
      parameters: rawParams.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      createdAt: _parseDate(json['createdAt'] as String?),
      updatedAt: _parseDate(json['updatedAt'] as String?),
      lastExportPath: json['lastExportPath'] as String?,
      lastExportFormat: json['lastExportFormat'] as String?,
      lastExportBitrateKbps: json['lastExportBitrateKbps'] as int?,
      lastExportDate: _parseDate(json['lastExportDate'] as String?),
    );
  }

  static DateTime? _parseDate(String? value) {
    return value == null ? null : DateTime.tryParse(value);
  }
}
