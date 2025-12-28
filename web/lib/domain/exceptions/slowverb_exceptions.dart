/// Base exception class for all Slowverb exceptions.
///
/// Provides structured error handling with message and optional cause.
/// All domain-specific exceptions should extend this class.
abstract class SlowverbException implements Exception {
  /// Human-readable error message.
  String get message;

  /// Optional underlying cause of this exception.
  Object? get cause;

  @override
  String toString() =>
      'SlowverbException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Exception thrown during audio processing operations.
class AudioProcessingException extends SlowverbException {
  @override
  final String message;

  @override
  final Object? cause;

  /// Optional path to the source file being processed.
  final String? sourcePath;

  /// Optional effect parameters that were in use.
  final Map<String, dynamic>? effectParams;

  AudioProcessingException(
    this.message, {
    this.cause,
    this.sourcePath,
    this.effectParams,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AudioProcessingException: $message');
    if (sourcePath != null) buffer.write(' (source: $sourcePath)');
    if (cause != null) buffer.write(' (caused by: $cause)');
    return buffer.toString();
  }
}

/// Exception thrown during file operations (import/export).
class FileOperationException extends SlowverbException {
  @override
  final String message;

  @override
  final Object? cause;

  /// The file path involved in the operation.
  final String? filePath;

  /// The operation that failed (e.g., 'read', 'write', 'delete').
  final String? operation;

  FileOperationException(
    this.message, {
    this.cause,
    this.filePath,
    this.operation,
  });

  @override
  String toString() {
    final buffer = StringBuffer('FileOperationException: $message');
    if (operation != null) buffer.write(' (operation: $operation)');
    if (filePath != null) buffer.write(' (path: $filePath)');
    if (cause != null) buffer.write(' (caused by: $cause)');
    return buffer.toString();
  }
}

/// Exception thrown during mastering operations.
class MasteringException extends SlowverbException {
  @override
  final String message;

  @override
  final Object? cause;

  /// Error code from WASM module, if applicable.
  final int? errorCode;

  /// The mastering level that failed (3 = Standard, 5 = Pro).
  final int? masteringLevel;

  MasteringException(
    this.message, {
    this.cause,
    this.errorCode,
    this.masteringLevel,
  });

  @override
  String toString() {
    final buffer = StringBuffer('MasteringException: $message');
    if (masteringLevel != null) buffer.write(' (level: $masteringLevel)');
    if (errorCode != null) buffer.write(' (code: $errorCode)');
    if (cause != null) buffer.write(' (caused by: $cause)');
    return buffer.toString();
  }
}

/// Exception thrown during export operations.
class ExportException extends SlowverbException {
  @override
  final String message;

  @override
  final Object? cause;

  /// The target format (e.g., 'mp3', 'wav', 'flac').
  final String? format;

  /// The output path if known.
  final String? outputPath;

  ExportException(this.message, {this.cause, this.format, this.outputPath});

  @override
  String toString() {
    final buffer = StringBuffer('ExportException: $message');
    if (format != null) buffer.write(' (format: $format)');
    if (outputPath != null) buffer.write(' (output: $outputPath)');
    if (cause != null) buffer.write(' (caused by: $cause)');
    return buffer.toString();
  }
}

/// Exception thrown when a project is not found.
class ProjectNotFoundException extends SlowverbException {
  @override
  final String message;

  @override
  final Object? cause = null;

  /// The project ID that was not found.
  final String projectId;

  ProjectNotFoundException(this.projectId)
    : message = 'Project not found: $projectId';

  @override
  String toString() => 'ProjectNotFoundException: $message';
}

/// Exception thrown when WASM engine operations fail.
class EngineException extends SlowverbException {
  @override
  final String message;

  @override
  final Object? cause;

  /// The engine operation that failed.
  final String? operation;

  EngineException(this.message, {this.cause, this.operation});

  @override
  String toString() {
    final buffer = StringBuffer('EngineException: $message');
    if (operation != null) buffer.write(' (operation: $operation)');
    if (cause != null) buffer.write(' (caused by: $cause)');
    return buffer.toString();
  }
}
