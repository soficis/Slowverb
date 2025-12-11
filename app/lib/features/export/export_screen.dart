/*
 * Copyright (C) 2025 Slowverb
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb/app/colors.dart';
import 'package:slowverb/app/router.dart';
import 'package:slowverb/features/editor/editor_provider.dart';
import 'package:slowverb/services/codec_detector.dart';

/// Export screen for rendering and saving processed audio
class ExportScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ExportScreen({super.key, required this.projectId});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String _selectedFormat = 'mp3';
  String _selectedQuality = 'high';
  bool? _isSourceLossless; // null = checking, true/false = result
  final _codecDetector = CodecDetector();

  @override
  void initState() {
    super.initState();
    _checkSourceCodec();
  }

  Future<void> _checkSourceCodec() async {
    final state = ref.read(editorProvider);
    final project = state.currentProject;

    if (project != null) {
      final isLossless = await _codecDetector.isSourceLossless(
        project.sourcePath,
      );
      if (mounted) {
        setState(() {
          _isSourceLossless = isLossless;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorProvider);
    final project = state.currentProject;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, state.isExporting),
              Expanded(
                child: state.exportedFilePath != null
                    ? _buildSuccessState(context, state)
                    : state.isExporting
                    ? _buildExportingState(context, state)
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (project != null) ...[
                                _buildProjectInfo(context, project.name),
                                const SizedBox(height: 16),
                              ],
                              _buildOptionsContent(context, state),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectInfo(BuildContext context, String projectName) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: SlowverbColors.slowedReverbGradient,
            ),
            child: const Icon(Icons.music_note, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              projectName,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isExporting) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: isExporting ? null : () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Text('Export', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildOptionsContent(BuildContext context, EditorState state) {
    final params = state.parameters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show current effect settings
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SlowverbColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Effect Settings',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: SlowverbColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildParamChip(
                    'Tempo',
                    '${(params['tempo'] ?? 1.0).toStringAsFixed(2)}x',
                  ),
                  _buildParamChip(
                    'Pitch',
                    '${(params['pitch'] ?? 0.0).toStringAsFixed(1)} semi',
                  ),
                  _buildParamChip(
                    'Reverb',
                    '${((params['reverbAmount'] ?? 0.0) * 100).toInt()}%',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Output Format', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildFormatOptions(),
        const SizedBox(height: 24),
        Text('Quality', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildQualityOptions(),
        const SizedBox(height: 24),
        Text('Save Location', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildSaveLocationPicker(state),
        const SizedBox(height: 24),
        _buildExportButton(),
      ],
    );
  }

  Widget _buildParamChip(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: SlowverbColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: SlowverbColors.neonCyan,
          ),
        ),
      ],
    );
  }

  Widget _buildFormatOptions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildFormatChip('MP3', 'mp3'),
        _buildFormatChip('WAV', 'wav'),
        _buildFormatChip('AAC', 'aac'),
        _buildFormatChip(
          'FLAC',
          'flac',
          enabled: _isSourceLossless == true,
          tooltip: _isSourceLossless == false
              ? 'FLAC is only available when the original source is lossless (WAV, FLAC, AIFF, etc.)'
              : null,
        ),
      ],
    );
  }

  Widget _buildFormatChip(
    String label,
    String value, {
    bool enabled = true,
    String? tooltip,
  }) {
    final isSelected = _selectedFormat == value;
    final widget = ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: enabled
          ? (selected) {
              if (selected) {
                setState(() => _selectedFormat = value);
              }
            }
          : null,
      selectedColor: SlowverbColors.hotPink,
      backgroundColor: enabled
          ? SlowverbColors.surface
          : SlowverbColors.surface.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: enabled
            ? (isSelected ? Colors.white : SlowverbColors.onSurface)
            : SlowverbColors.onSurfaceMuted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: widget);
    }
    return widget;
  }

  Widget _buildQualityOptions() {
    return Row(
      children: [
        _buildQualityChip('Standard', 'standard', '128 kbps'),
        const SizedBox(width: 12),
        _buildQualityChip('High', 'high', '320 kbps'),
      ],
    );
  }

  Widget _buildQualityChip(String label, String value, String subtitle) {
    final isSelected = _selectedQuality == value;
    return ChoiceChip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.8)
                  : SlowverbColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedQuality = value);
        }
      },
      selectedColor: SlowverbColors.hotPink,
      backgroundColor: SlowverbColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : SlowverbColors.onSurface,
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startExport,
        icon: const Icon(Icons.download),
        label: const Text('Start Export'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildExportingState(BuildContext context, EditorState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: state.exportProgress,
                    strokeWidth: 8,
                    backgroundColor: SlowverbColors.surface,
                    valueColor: const AlwaysStoppedAnimation(
                      SlowverbColors.neonCyan,
                    ),
                  ),
                  Text(
                    '${(state.exportProgress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Exporting...', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Processing audio with effects',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SlowverbColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context, EditorState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: SlowverbColors.success,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 32),
            Text(
              'Export Complete!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your track has been saved',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SlowverbColors.onSurfaceMuted,
              ),
            ),
            if (state.exportedFilePath != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SlowverbColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.exportedFilePath!,
                  style: Theme.of(context).textTheme.labelMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SlowverbColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: SlowverbColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: SlowverbColors.warning,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;

                final openButton = OutlinedButton.icon(
                  onPressed: _openFileLocation,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open Folder'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SlowverbColors.neonCyan),
                    foregroundColor: SlowverbColors.neonCyan,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                );

                final doneButton = ElevatedButton.icon(
                  onPressed: () => context.go(RoutePaths.home),
                  icon: const Icon(Icons.done),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    minimumSize: isNarrow
                        ? const Size.fromHeight(48)
                        : const Size(0, 0),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      openButton,
                      const SizedBox(height: 12),
                      doneButton,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [openButton, const SizedBox(width: 16), doneButton],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveLocationPicker(EditorState state) {
    final currentDir =
        state.exportDirectory ?? 'V:\\Documents\\Slowverb (Default)';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SlowverbColors.surfaceVariant, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentDir,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final dir = await FilePicker.platform.getDirectoryPath();
              if (dir != null) {
                ref.read(editorProvider.notifier).setExportDirectory(dir);
              }
            },
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Change'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: SlowverbColors.neonCyan),
              foregroundColor: SlowverbColors.neonCyan,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startExport() async {
    final notifier = ref.read(editorProvider.notifier);

    // Reset export state before starting new export
    notifier.resetExportState();

    await notifier.exportAudio(
      format: _selectedFormat,
      quality: _selectedQuality,
    );
  }

  Future<void> _openFileLocation() async {
    final filePath = ref.read(editorProvider).exportedFilePath;
    if (filePath == null) return;

    try {
      if (Platform.isWindows) {
        // Open Windows Explorer and select the file
        // Important: /select, must be followed by filepath without space
        await Process.run('explorer', ['/select,"$filePath"']);
      } else if (Platform.isMacOS) {
        // Open Finder and select the file
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        // Open file manager to the directory
        final dir = File(filePath).parent.path;
        await Process.run('xdg-open', [dir]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file location: $e'),
            backgroundColor: SlowverbColors.error,
          ),
        );
      }
    }
  }
}
