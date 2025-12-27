import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State representing current processing progress for the audio editor.
class ProcessingProgressState {
  /// Progress from 0.0 to 1.0
  final double progress;

  /// Current processing stage (e.g., "decoding", "mastering", "encoding")
  final String stage;

  /// When processing started (for time estimation)
  final DateTime? startTime;

  /// Whether this is Level 5 mastering (shows more detail)
  final bool isLevel5;

  /// Whether any processing is currently active
  final bool isActive;

  const ProcessingProgressState({
    this.progress = 0.0,
    this.stage = '',
    this.startTime,
    this.isLevel5 = false,
    this.isActive = false,
  });

  /// Estimated time remaining based on progress and elapsed time
  Duration? get estimatedRemaining {
    if (startTime == null || progress <= 0.0 || progress >= 1.0) return null;

    final elapsed = DateTime.now().difference(startTime!);
    final estimatedTotal = elapsed.inMilliseconds / progress;
    final remaining = estimatedTotal - elapsed.inMilliseconds;

    return Duration(milliseconds: remaining.round());
  }

  /// Format the estimated remaining time as a human-readable string
  String get estimatedRemainingText {
    final remaining = estimatedRemaining;
    if (remaining == null) return '';

    if (remaining.inMinutes >= 1) {
      final mins = remaining.inMinutes;
      final secs = remaining.inSeconds % 60;
      return '~$mins min ${secs > 0 ? '$secs sec' : ''}';
    }

    final secs = remaining.inSeconds;
    if (secs <= 0) return 'Almost done...';
    return '~$secs sec';
  }

  ProcessingProgressState copyWith({
    double? progress,
    String? stage,
    DateTime? startTime,
    bool? isLevel5,
    bool? isActive,
  }) {
    return ProcessingProgressState(
      progress: progress ?? this.progress,
      stage: stage ?? this.stage,
      startTime: startTime ?? this.startTime,
      isLevel5: isLevel5 ?? this.isLevel5,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Reset state when processing completes or is cancelled
  ProcessingProgressState reset() {
    return const ProcessingProgressState();
  }
}

/// Notifier for processing progress state
class ProcessingProgressNotifier
    extends StateNotifier<ProcessingProgressState> {
  ProcessingProgressNotifier() : super(const ProcessingProgressState());

  /// Start tracking a new processing job
  void startProcessing({bool isLevel5 = false}) {
    state = ProcessingProgressState(
      progress: 0.0,
      stage: 'Starting...',
      startTime: DateTime.now(),
      isLevel5: isLevel5,
      isActive: true,
    );
  }

  /// Update progress
  void updateProgress(double progress, String stage) {
    if (!state.isActive) return;

    state = state.copyWith(progress: progress.clamp(0.0, 1.0), stage: stage);
  }

  /// Mark processing as complete
  void complete() {
    state = state.reset();
  }

  /// Cancel/reset processing
  void cancel() {
    state = state.reset();
  }
}

/// Provider for processing progress state
final processingProgressProvider =
    StateNotifierProvider<ProcessingProgressNotifier, ProcessingProgressState>(
      (ref) => ProcessingProgressNotifier(),
    );
