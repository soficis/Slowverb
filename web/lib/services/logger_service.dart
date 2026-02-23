import 'package:flutter/foundation.dart';

/// Log levels for application logging.
enum LogLevel { debug, info, warning, error }

/// Simple logging service for Slowverb application.
///
/// Replaces raw print() calls with structured logging that can be
/// configured and filtered. In production builds, debug logs are suppressed.
class SlowverbLogger {
  final String _tag;

  /// Create a logger with the given tag (usually class name).
  const SlowverbLogger(this._tag);

  /// Log debug message - only visible in debug builds.
  void debug(String message, [Object? data]) {
    if (kDebugMode) {
      _log(LogLevel.debug, message, data);
    }
  }

  /// Log info message.
  void info(String message, [Object? data]) {
    _log(LogLevel.info, message, data);
  }

  /// Log warning message.
  void warning(String message, [Object? data]) {
    _log(LogLevel.warning, message, data);
  }

  /// Log error message with optional error object and stack trace.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error);
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }

  void _log(LogLevel level, String message, Object? data) {
    final levelPrefix = switch (level) {
      LogLevel.debug => '🔍',
      LogLevel.info => 'ℹ️',
      LogLevel.warning => '⚠️',
      LogLevel.error => '❌',
    };

    final logMessage = '[$_tag] $levelPrefix $message';
    final fullMessage = data != null ? '$logMessage: $data' : logMessage;

    // Using debugPrint for proper Flutter integration
    debugPrint(fullMessage);
  }
}

/// Mixin to add logging capability to classes.
mixin Loggable {
  late final SlowverbLogger _logger = SlowverbLogger(runtimeType.toString());

  SlowverbLogger get log => _logger;
}
