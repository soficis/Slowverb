import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb/domain/entities/batch_job.dart';
import 'package:slowverb/domain/entities/history_entry.dart';
import 'package:slowverb/features/batch/batch_processor.dart';

class BatchExportDialog extends ConsumerStatefulWidget {
  final List<HistoryEntry> entries;

  const BatchExportDialog({super.key, required this.entries});

  @override
  ConsumerState<BatchExportDialog> createState() => _BatchExportDialogState();
}

class _BatchExportDialogState extends ConsumerState<BatchExportDialog> {
  String _selectedFormat = 'mp3';
  int _selectedBitrate = 320;
  String? _destinationFolder;

  final List<String> _formats = ['mp3', 'wav', 'aac', 'flac'];
  final List<int> _bitrates = [128, 192, 256, 320];

  @override
  Widget build(BuildContext context) {
    // Count missing source files
    final missingCount = widget.entries
        .where((e) => !File(e.sourcePath).existsSync())
        .length;

    return AlertDialog(
      title: const Text('Batch Export'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected items summary
            Text(
              '${widget.entries.length} items selected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (missingCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$missingCount source file(s) missing - will be skipped',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Format selection
            Text(
              'Export Format',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _formats.map((format) {
                return ChoiceChip(
                  label: Text(format.toUpperCase()),
                  selected: _selectedFormat == format,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFormat = format);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Bitrate selection (only for lossy formats)
            if (_selectedFormat == 'mp3' || _selectedFormat == 'aac') ...[
              Text(
                'Bitrate (kbps)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _bitrates.map((bitrate) {
                  return ChoiceChip(
                    label: Text(bitrate.toString()),
                    selected: _selectedBitrate == bitrate,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedBitrate = bitrate);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Destination folder
            Text(
              'Destination Folder',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDestination,
              icon: const Icon(Icons.folder_open),
              label: Text(
                _destinationFolder ?? 'Choose folder...',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _destinationFolder != null ? _startBatchExport : null,
          child: const Text('Start Export'),
        ),
      ],
    );
  }

  Future<void> _pickDestination() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Destination Folder',
    );

    if (result != null) {
      setState(() => _destinationFolder = result);
    }
  }

  void _startBatchExport() {
    if (_destinationFolder == null) return;

    // Create export options
    final exportOptions = ExportOptions(
      format: _selectedFormat,
      bitrateKbps: (_selectedFormat == 'mp3' || _selectedFormat == 'aac')
          ? _selectedBitrate
          : null,
    );

    // Create batch job
    final batchJob = BatchJob.fromHistoryEntries(
      entries: widget.entries,
      exportOptions: exportOptions,
      destinationFolder: _destinationFolder!,
    );

    // Start batch processing
    ref
        .read(batchProcessorProvider.notifier)
        .startBatch(batchJob, _destinationFolder!);

    Navigator.pop(context, true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Batch export started: ${widget.entries.length} items'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
