/*
 * Copyright (C) 2025 Slowverb Web
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/domain/entities/batch_render_progress.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/batch_job.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';

/// Batch export screen showing progress of batch audio processing
///
/// Displays:
/// - Overall progress bar
/// - Individual file progress rows
/// - Success/error status per file
/// - Estimated time remaining
/// - Files auto-download as they complete (web platform behavior)
class BatchExportScreen extends StatefulWidget {
  const BatchExportScreen({super.key});

  @override
  State<BatchExportScreen> createState() => _BatchExportScreenState();
}

class _BatchExportScreenState extends State<BatchExportScreen> {
  BatchRenderProgress? _progress;
  bool _isProcessing = true;
  Stream<BatchRenderProgress>? _progressStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get arguments passed from import screen
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) {
      Navigator.of(context).pop();
      return;
    }

    final files = args['files'] as List<BatchInputFile>;
    final defaultPreset = args['defaultPreset'] as EffectPreset;

    // Get default export options (MP3 320kbps)
    const options = ExportOptions.mp3High;

    // Start batch processing
    final engine = Provider.of<AudioEngineProvider>(
      context,
      listen: false,
    ).engine;
    _progressStream = engine.renderBatch(
      files: files,
      defaultPreset: defaultPreset,
      options: options,
    );

    _startListening();
  }

  void _startListening() {
    _progressStream?.listen(
      (progress) {
        setState(() {
          _progress = progress;
          if (progress.isFinished) {
            _isProcessing = false;
          }
        });
      },
      onError: (error) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch processing error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<void> _cancelBatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Batch?'),
        content: const Text(
          'Are you sure you want to cancel the batch processing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final engine = Provider.of<AudioEngineProvider>(
        context,
        listen: false,
      ).engine;
      await engine.cancelBatch();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Export'),
        actions: [
          if (_isProcessing)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _cancelBatch,
              tooltip: 'Cancel Batch',
            ),
        ],
      ),
      body: progress == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Overall progress header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Processing ${progress.totalFiles} files',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (progress.isFinished)
                            Icon(
                              progress.failedFiles == 0
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: progress.failedFiles == 0
                                  ? Colors.green
                                  : Colors.orange,
                              size: 32,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress.overallProgress,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${progress.completedFiles}/${progress.totalFiles} completed',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (progress.estimatedTimeRemaining != null &&
                              !progress.isFinished)
                            Text(
                              'ETA: ${_formatDuration(progress.estimatedTimeRemaining!)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                        ],
                      ),
                      if (progress.failedFiles > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${progress.failedFiles} file(s) failed',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // File list with status
                Expanded(
                  child: ListView.builder(
                    itemCount: progress.totalFiles,
                    itemBuilder: (context, index) {
                      final isCompleted = index < progress.completedFiles;
                      final isFailed = progress.errors.containsKey(
                        progress.completedFileNames.elementAtOrNull(index) ??
                            '',
                      );
                      final isCurrentFile = index == progress.currentFileIndex;
                      final fileName = isCompleted
                          ? progress.completedFileNames.elementAtOrNull(
                                  index,
                                ) ??
                                'File ${index + 1}'
                          : progress.currentFileName ?? 'File ${index + 1}';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Icon(
                            isCompleted
                                ? (isFailed ? Icons.error : Icons.check_circle)
                                : (isCurrentFile
                                      ? Icons.hourglass_bottom
                                      : Icons.pending),
                            color: isCompleted
                                ? (isFailed ? Colors.red : Colors.green)
                                : (isCurrentFile ? Colors.blue : Colors.grey),
                          ),
                          title: Text(fileName),
                          subtitle: isCurrentFile && !progress.isFinished
                              ? LinearProgressIndicator(
                                  value: progress.currentFileProgress,
                                )
                              : isFailed
                              ? Text(
                                  progress.errors[fileName] ?? 'Error',
                                  style: const TextStyle(color: Colors.red),
                                )
                              : null,
                          trailing: isCompleted
                              ? Icon(
                                  isFailed ? Icons.cancel : Icons.download_done,
                                  color: isFailed ? Colors.red : Colors.green,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),

                // Bottom action bar
                if (progress.isFinished)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.done),
                          label: const Text('Done'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
