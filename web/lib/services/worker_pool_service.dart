import 'dart:async';
import 'dart:typed_data';

import 'package:slowverb_web/services/phase_limiter_service.dart';

/// Result from a worker processing task
class WorkerTaskResult {
  final int taskIndex;
  final Float32List left;
  final Float32List right;
  final String? warning;
  final String? error;

  WorkerTaskResult({
    required this.taskIndex,
    required this.left,
    required this.right,
    this.warning,
    this.error,
  });
}

/// Task to be processed by a worker
class WorkerTask {
  final int index;
  final Float32List leftChannel;
  final Float32List rightChannel;
  final int sampleRate;
  final PhaseLimiterConfig config;
  final Completer<WorkerTaskResult> completer;

  WorkerTask({
    required this.index,
    required this.leftChannel,
    required this.rightChannel,
    required this.sampleRate,
    required this.config,
    required this.completer,
  });
}

/// Manages a pool of PhaseLimiter workers for concurrent batch processing
class WorkerPoolService {
  /// Maximum concurrent workers (conservative for browser memory)
  static const int maxConcurrency = 3;

  final List<PhaseLimiterService> _workers = [];
  final List<bool> _workerBusy = [];
  final List<WorkerTask> _taskQueue = [];

  final StreamController<({int taskIndex, double progress})>
  _progressController = StreamController.broadcast();

  /// Stream of progress updates for individual tasks
  Stream<({int taskIndex, double progress})> get progressStream =>
      _progressController.stream;

  bool _initialized = false;

  /// Initialize the worker pool
  Future<void> initialize() async {
    if (_initialized) return;

    for (int i = 0; i < maxConcurrency; i++) {
      final worker = PhaseLimiterService();
      await worker.initialize();
      _workers.add(worker);
      _workerBusy.add(false);
    }
    _initialized = true;
  }

  /// Process multiple files concurrently
  ///
  /// Returns a list of results in the same order as the input tasks.
  Future<List<WorkerTaskResult>> processAll(
    List<
      ({
        Float32List left,
        Float32List right,
        int sampleRate,
        PhaseLimiterConfig config,
      })
    >
    tasks,
  ) async {
    if (!_initialized) {
      await initialize();
    }

    final results = List<WorkerTaskResult?>.filled(tasks.length, null);
    final completers = <Completer<WorkerTaskResult>>[];

    // Create worker tasks for all files
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final completer = Completer<WorkerTaskResult>();
      completers.add(completer);

      _taskQueue.add(
        WorkerTask(
          index: i,
          leftChannel: task.left,
          rightChannel: task.right,
          sampleRate: task.sampleRate,
          config: task.config,
          completer: completer,
        ),
      );
    }

    // Start processing - dispatch to available workers
    _dispatchTasks();

    // Wait for all tasks to complete
    final allResults = await Future.wait(completers.map((c) => c.future));

    // Reorder results by original index
    for (final result in allResults) {
      results[result.taskIndex] = result;
    }

    return results.cast<WorkerTaskResult>();
  }

  void _dispatchTasks() {
    for (int i = 0; i < _workers.length; i++) {
      if (!_workerBusy[i] && _taskQueue.isNotEmpty) {
        final task = _taskQueue.removeAt(0);
        _workerBusy[i] = true;
        _processTask(i, task);
      }
    }
  }

  Future<void> _processTask(int workerIndex, WorkerTask task) async {
    final worker = _workers[workerIndex];

    // Listen to progress for this worker
    StreamSubscription<double>? progressSub;
    progressSub = worker.progressStream.listen((progress) {
      _progressController.add((taskIndex: task.index, progress: progress));
    });

    try {
      final result = await worker.process(
        leftChannel: task.leftChannel,
        rightChannel: task.rightChannel,
        sampleRate: task.sampleRate,
        config: task.config,
      );

      task.completer.complete(
        WorkerTaskResult(
          taskIndex: task.index,
          left: result.left,
          right: result.right,
        ),
      );
    } catch (e) {
      task.completer.complete(
        WorkerTaskResult(
          taskIndex: task.index,
          left: Float32List(0),
          right: Float32List(0),
          error: e.toString(),
        ),
      );
    } finally {
      await progressSub.cancel();
      _workerBusy[workerIndex] = false;

      // Check for more tasks to dispatch
      _dispatchTasks();
    }
  }

  /// Dispose all workers
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    _workerBusy.clear();
    _taskQueue.clear();
    _progressController.close();
    _initialized = false;
  }
}
