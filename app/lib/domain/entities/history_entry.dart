import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

/// Represents a historical record of an exported project or saved session.
class HistoryEntry {
  final String id;
  final String sourcePath;
  final String? outputPath;
  final String presetId;
  final Map<String, double> parameters;
  final DateTime timestamp;
  final String format;
  final int durationMs;
  final String? sourceFileName; // Cached for display if file is missing

  const HistoryEntry({
    required this.id,
    required this.sourcePath,
    this.outputPath,
    required this.presetId,
    required this.parameters,
    required this.timestamp,
    required this.format,
    required this.durationMs,
    this.sourceFileName,
  });

  /// Creates a new entry with a generated UUID and current timestamp
  factory HistoryEntry.create({
    required String sourcePath,
    String? outputPath,
    required String presetId,
    required Map<String, double> parameters,
    required String format,
    required int durationMs,
    String? sourceFileName,
  }) {
    return HistoryEntry(
      id: const Uuid().v4(),
      sourcePath: sourcePath,
      outputPath: outputPath,
      presetId: presetId,
      parameters: parameters,
      timestamp: DateTime.now(),
      format: format,
      durationMs: durationMs,
      sourceFileName: sourceFileName ?? sourcePath.split(RegExp(r'[/\\]')).last,
    );
  }

  /// Serialization for Hive storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourcePath': sourcePath,
      'outputPath': outputPath,
      'presetId': presetId,
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
      'format': format,
      'durationMs': durationMs,
      'sourceFileName': sourceFileName,
    };
  }

  /// Deserialization from Hive storage
  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      sourcePath: json['sourcePath'] as String,
      outputPath: json['outputPath'] as String?,
      presetId: json['presetId'] as String,
      parameters: Map<String, double>.from(json['parameters'] as Map),
      timestamp: DateTime.parse(json['timestamp'] as String),
      format: json['format'] as String,
      durationMs: json['durationMs'] as int,
      sourceFileName: json['sourceFileName'] as String?,
    );
  }

  HistoryEntry copyWith({
    String? id,
    String? sourcePath,
    String? outputPath,
    String? presetId,
    Map<String, double>? parameters,
    DateTime? timestamp,
    String? format,
    int? durationMs,
    String? sourceFileName,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      sourcePath: sourcePath ?? this.sourcePath,
      outputPath: outputPath ?? this.outputPath,
      presetId: presetId ?? this.presetId,
      parameters: parameters ?? this.parameters,
      timestamp: timestamp ?? this.timestamp,
      format: format ?? this.format,
      durationMs: durationMs ?? this.durationMs,
      sourceFileName: sourceFileName ?? this.sourceFileName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final mapEquals = const MapEquality().equals;

    return other is HistoryEntry &&
        other.id == id &&
        other.sourcePath == sourcePath &&
        other.outputPath == outputPath &&
        other.presetId == presetId &&
        mapEquals(other.parameters, parameters) &&
        other.timestamp == timestamp &&
        other.format == format &&
        other.durationMs == durationMs;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        sourcePath.hashCode ^
        outputPath.hashCode ^
        presetId.hashCode ^
        const MapEquality().hash(parameters) ^
        timestamp.hashCode ^
        format.hashCode ^
        durationMs.hashCode;
  }
}
