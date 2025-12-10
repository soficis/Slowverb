import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:slowverb/app/colors.dart';
import 'package:slowverb/app/router.dart';
import 'package:slowverb/domain/entities/batch_job.dart';
import 'package:slowverb/domain/entities/effect_preset.dart';
import 'package:slowverb/domain/entities/render_job.dart';
import 'package:slowverb/features/batch/batch_processor.dart';

class BatchImportScreen extends ConsumerStatefulWidget {
  const BatchImportScreen({super.key});

  @override
  ConsumerState<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends ConsumerState<BatchImportScreen> {
  final List<String> _selectedFiles = [];
  String _selectedPresetId = 'slowed_reverb';
  String _selectedFormat = 'mp3';
  int _selectedBitrate = 320;
  String? _outputFolder;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final batchState = ref.watch(batchProcessorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Import'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.home),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File selection
              _buildSection(
                title: 'Audio Files',
                child: Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _pickFiles,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Audio Files'),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedFiles.isNotEmpty)
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: SlowverbColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _selectedFiles[index];
                            return ListTile(
                              leading: const Icon(Icons.audio_file),
                              title: Text(
                                p.basename(file),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _isProcessing
                                    ? null
                                    : () => setState(() {
                                        _selectedFiles.removeAt(index);
                                      }),
                              ),
                            );
                          },
                        ),
                      ),
                    if (_selectedFiles.isEmpty)
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: SlowverbColors.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Center(
                          child: Text(
                            'No files selected',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Preset selection
              _buildSection(
                title: 'Effect Preset',
                child: Wrap(
                  spacing: 8,
                  children: Presets.all.map((preset) {
                    return ChoiceChip(
                      label: Text(preset.name),
                      selected: _selectedPresetId == preset.id,
                      onSelected: _isProcessing
                          ? null
                          : (selected) {
                              if (selected) {
                                setState(() => _selectedPresetId = preset.id);
                              }
                            },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Format & Quality
              _buildSection(
                title: 'Export Format',
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: ['mp3', 'wav', 'flac'].map((fmt) {
                          return ChoiceChip(
                            label: Text(fmt.toUpperCase()),
                            selected: _selectedFormat == fmt,
                            onSelected: _isProcessing
                                ? null
                                : (selected) {
                                    if (selected) {
                                      setState(() => _selectedFormat = fmt);
                                    }
                                  },
                          );
                        }).toList(),
                      ),
                    ),
                    if (_selectedFormat == 'mp3') ...[
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: _selectedBitrate,
                        items: [128, 192, 256, 320].map((br) {
                          return DropdownMenuItem(
                            value: br,
                            child: Text('$br kbps'),
                          );
                        }).toList(),
                        onChanged: _isProcessing
                            ? null
                            : (v) {
                                if (v != null) {
                                  setState(() => _selectedBitrate = v);
                                }
                              },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Output folder
              _buildSection(
                title: 'Output Folder',
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _pickOutputFolder,
                  icon: const Icon(Icons.folder_open),
                  label: Text(_outputFolder ?? 'Choose folder...'),
                ),
              ),
              const Spacer(),

              // Progress indicator
              if (batchState != null) ...[
                LinearProgressIndicator(
                  value: batchState.overallProgress,
                  backgroundColor: SlowverbColors.surface,
                  valueColor: const AlwaysStoppedAnimation(
                    SlowverbColors.neonCyan,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${batchState.completedCount}/${batchState.totalCount} completed',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
              ],

              // Start button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canStart() ? _startBatchProcessing : null,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_isProcessing ? 'Processing...' : 'Start Batch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: SlowverbColors.neonCyan),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  bool _canStart() {
    return _selectedFiles.isNotEmpty && _outputFolder != null && !_isProcessing;
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null && !_selectedFiles.contains(file.path)) {
            _selectedFiles.add(file.path!);
          }
        }
      });
    }
  }

  Future<void> _pickOutputFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Output Folder',
    );

    if (result != null) {
      setState(() => _outputFolder = result);
    }
  }

  Future<void> _startBatchProcessing() async {
    if (!_canStart()) return;

    setState(() => _isProcessing = true);

    final preset = Presets.getById(_selectedPresetId) ?? Presets.slowedReverb;

    final items = _selectedFiles.map((filePath) {
      return BatchJobItem(
        fileId:
            DateTime.now().millisecondsSinceEpoch.toString() +
            p.basename(filePath),
        fileName: p.basename(filePath),
        filePath: filePath,
        status: RenderJobStatus.queued,
      );
    }).toList();

    final batchJob = BatchJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: items,
      defaultPreset: preset,
      exportOptions: ExportOptions(
        format: _selectedFormat,
        bitrateKbps: _selectedFormat == 'mp3' ? _selectedBitrate : null,
      ),
      status: BatchJobStatus.pending,
      createdAt: DateTime.now(),
    );

    await ref
        .read(batchProcessorProvider.notifier)
        .startBatch(batchJob, _outputFolder!);

    setState(() => _isProcessing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch processing complete!'),
          backgroundColor: SlowverbColors.success,
        ),
      );
    }
  }
}
