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
 * You should have received a copy of the  GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';

/// Export screen for rendering and downloading final audio
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String _selectedFormat = 'mp3';
  int _mp3Bitrate = 320;
  int _flacCompressionLevel = 8;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  RenderJobId? _activeJobId;
  StreamSubscription<RenderProgress>? _progressSub;
  String? _downloadUrl;
  String? _downloadFilename;
  String? _errorMessage;

  @override
  void dispose() {
    _progressSub?.cancel();
    _cleanupDownloadUrl();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SlowverbColors.backgroundDark,
      appBar: AppBar(title: const Text('EXPORT')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: SlowverbColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _isExporting
                ? _buildExportingView()
                : _buildConfigurationView(),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        ShaderMask(
          shaderCallback: (bounds) =>
              SlowverbColors.primaryGradient.createShader(bounds),
          child: Text(
            'EXPORT AUDIO',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              letterSpacing: 3.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Choose your export format and settings',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // Format selector
        Text('FORMAT', style: Theme.of(context).textTheme.labelLarge),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _FormatButton(
                label: 'MP3',
                description: 'Compressed, universally compatible',
                icon: Icons.music_note,
                isSelected: _selectedFormat == 'mp3',
                onTap: () => setState(() => _selectedFormat = 'mp3'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FormatButton(
                label: 'WAV',
                description: 'Uncompressed, max quality',
                icon: Icons.graphic_eq,
                isSelected: _selectedFormat == 'wav',
                onTap: () => setState(() => _selectedFormat = 'wav'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FormatButton(
                label: 'FLAC',
                description: 'Lossless compression',
                icon: Icons.high_quality,
                isSelected: _selectedFormat == 'flac',
                onTap: () => setState(() => _selectedFormat = 'flac'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Format-specific settings
        if (_selectedFormat == 'mp3') ...[
          Text('MP3 BITRATE', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _mp3Bitrate.toDouble(),
                  min: 128,
                  max: 320,
                  divisions: 3,
                  label: '$_mp3Bitrate kbps',
                  onChanged: (value) =>
                      setState(() => _mp3Bitrate = value.toInt()),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: SlowverbColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_mp3Bitrate kbps',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SlowverbColors.accentPink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],

        if (_selectedFormat == 'flac') ...[
          Text(
            'FLAC COMPRESSION LEVEL',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _flacCompressionLevel.toDouble(),
                  min: 0,
                  max: 8,
                  divisions: 8,
                  label: 'Level $_flacCompressionLevel',
                  onChanged: (value) =>
                      setState(() => _flacCompressionLevel = value.toInt()),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: SlowverbColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Level $_flacCompressionLevel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SlowverbColors.accentCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),

        // Privacy notice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SlowverbColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock,
                color: SlowverbColors.accentMint,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'All processing happens locally in your browser. Your audio never leaves your device.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SlowverbColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Export button
        ElevatedButton.icon(
          onPressed: _startExport,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.download, size: 24),
          label: Text(
            'EXPORT AS ${_selectedFormat.toUpperCase()}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SlowverbColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: SlowverbColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SlowverbColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_downloadUrl != null) ...[
          const SizedBox(height: 24),
          _buildDownloadReadyCard(),
        ],
      ],
    );
  }

  Widget _buildExportingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.downloading,
          size: 64,
          color: SlowverbColors.primaryPurple,
        ),

        const SizedBox(height: 24),

        Text(
          'EXPORTING',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(letterSpacing: 2.0),
        ),

        const SizedBox(height: 8),

        Text(
          'Processing your audio with FFmpeg...',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: SlowverbColors.textSecondary),
        ),

        const SizedBox(height: 32),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _exportProgress,
            minHeight: 12,
            backgroundColor: SlowverbColors.backgroundLight,
            valueColor: const AlwaysStoppedAnimation<Color>(
              SlowverbColors.primaryPurple,
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          '${(_exportProgress * 100).toInt()}%',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: SlowverbColors.accentPink,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 32),

        // Cancel button
        TextButton(onPressed: _cancelExport, child: const Text('CANCEL')),
      ],
    );
  }

  Widget _buildDownloadReadyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SlowverbColors.accentMint.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: SlowverbColors.accentMint),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Export ready',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_downloadFilename != null)
            Text(
              _downloadFilename!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _triggerDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: SlowverbColors.primaryPurple,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _startExport() async {
    final editorState = ref.read(audioEditorProvider);
    if (editorState.fileId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Load a track before exporting.'),
            backgroundColor: SlowverbColors.error,
          ),
        );
      }
      return;
    }

    // Ensure engine is ready
    await ref.read(engineInitProvider.future);

    _progressSub?.cancel();
    _cleanupDownloadUrl();

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _errorMessage = null;
    });

    final engine = ref.read(audioEngineProvider);
    final config = EffectConfig.fromParams(
      editorState.selectedPreset.id,
      editorState.currentParameters,
    );
    final options = _buildExportOptions();

    try {
      final jobId = await engine.startRender(
        fileId: editorState.fileId!,
        config: config,
        options: options,
      );

      _activeJobId = jobId;
      _progressSub = engine
          .watchProgress(jobId)
          .listen(
            (progress) {
              if (!mounted) return;
              setState(() => _exportProgress = progress.progress);
            },
            onError: (error, stack) {
              if (!mounted) return;
              _progressSub = null;
              setState(() {
                _isExporting = false;
                _errorMessage = 'Export failed: $error';
                _activeJobId = null;
              });
            },
            onDone: () async {
              if (_activeJobId == null) {
                return;
              }
              try {
                final result = await engine.getResult(jobId);
                if (!mounted) return;

                if (!result.success || result.outputBytes == null) {
                  _progressSub = null;
                  setState(() {
                    _isExporting = false;
                    _errorMessage =
                        result.errorMessage ?? 'Export did not produce a file.';
                    _activeJobId = null;
                  });
                  return;
                }

                _onExportComplete(
                  result.outputBytes!,
                  options.format,
                  originalName: editorState.audioFileName,
                );
              } catch (e) {
                if (!mounted) return;
                _progressSub = null;
                setState(() {
                  _isExporting = false;
                  _errorMessage = 'Failed to finalize export: $e';
                  _activeJobId = null;
                });
              }
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _errorMessage = 'Failed to start export: $e';
        _activeJobId = null;
      });
    }
  }

  Future<void> _cancelExport() async {
    final jobId = _activeJobId;
    if (jobId != null) {
      final engine = ref.read(audioEngineProvider);
      await engine.cancelRender(jobId);
    }

    await _progressSub?.cancel();

    setState(() {
      _isExporting = false;
      _exportProgress = 0.0;
      _activeJobId = null;
      _progressSub = null;
    });
  }

  void _onExportComplete(
    Uint8List bytes,
    String format, {
    String? originalName,
  }) {
    _cleanupDownloadUrl();

    final mimeType = _mimeTypeForFormat(format);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final filename = _deriveDownloadName(originalName, format);

    _progressSub = null;

    setState(() {
      _isExporting = false;
      _exportProgress = 1.0;
      _downloadUrl = url;
      _downloadFilename = filename;
      _activeJobId = null;
    });

    _triggerDownload();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export ready. Click Download to save $filename.'),
          backgroundColor: SlowverbColors.primaryPurple,
        ),
      );
    }
  }

  void _triggerDownload() {
    if (_downloadUrl == null) return;

    final anchor = html.AnchorElement(href: _downloadUrl!)
      ..download = _downloadFilename ?? 'slowverb-export'
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  ExportOptions _buildExportOptions() {
    switch (_selectedFormat) {
      case 'mp3':
        return ExportOptions(format: 'mp3', bitrateKbps: _mp3Bitrate);
      case 'flac':
        return ExportOptions(
          format: 'flac',
          compressionLevel: _flacCompressionLevel,
        );
      case 'wav':
      default:
        return const ExportOptions(format: 'wav');
    }
  }

  String _deriveDownloadName(String? originalName, String format) {
    if (originalName == null || !originalName.contains('.')) {
      return 'slowverb-export.$format';
    }
    final base = originalName.split('.').first;
    return '$base.$format';
  }

  void _cleanupDownloadUrl() {
    if (_downloadUrl != null) {
      html.Url.revokeObjectUrl(_downloadUrl!);
      _downloadUrl = null;
      _downloadFilename = null;
    }
  }

  String _mimeTypeForFormat(String format) {
    switch (format) {
      case 'mp3':
        return 'audio/mpeg';
      case 'flac':
        return 'audio/flac';
      case 'wav':
      default:
        return 'audio/wav';
    }
  }
}

/// Format button widget
class _FormatButton extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? SlowverbColors.primaryPurple.withOpacity(0.2)
              : SlowverbColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? SlowverbColors.primaryPurple
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? SlowverbColors.accentPink
                  : SlowverbColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected
                    ? SlowverbColors.textPrimary
                    : SlowverbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
