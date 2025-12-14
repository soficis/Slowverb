import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';
import 'package:web/web.dart' as web;

/// Export screen for rendering and downloading final audio
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String _selectedFormat = 'mp3';
  int _mp3Bitrate = 320;
  int _aacBitrate = 256;
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

        // Format selector with source format indicator
        Row(
          children: [
            Text('FORMAT', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            _buildSourceFormatBadge(context),
          ],
        ),

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
                label: 'AAC',
                description: 'High quality, modern codec',
                icon: Icons.high_quality_outlined,
                isSelected: _selectedFormat == 'aac',
                onTap: () => setState(() => _selectedFormat = 'aac'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
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
            Expanded(child: _buildFlacButton()),
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

        if (_selectedFormat == 'aac') ...[
          Text('AAC BITRATE', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _aacBitrate.toDouble(),
                  min: 128,
                  max: 256,
                  divisions: 2,
                  label: '$_aacBitrate kbps',
                  onChanged: (value) =>
                      setState(() => _aacBitrate = value.toInt()),
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
                  '$_aacBitrate kbps',
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
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final filename = _deriveDownloadName(originalName, format);

    _progressSub = null;

    setState(() {
      _isExporting = false;
      _exportProgress = 1.0;
      _downloadUrl = url;
      _downloadFilename = filename;
      _activeJobId = null;
    });

    // Persist export metadata to the current project.
    unawaited(
      ref
          .read(audioEditorProvider.notifier)
          .recordExport(
            format: format,
            bitrateKbps: _selectedFormat == 'mp3'
                ? _mp3Bitrate
                : _selectedFormat == 'aac'
                ? _aacBitrate
                : null,
            path: filename,
          ),
    );

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

    final anchor = web.HTMLAnchorElement()
      ..href = _downloadUrl!
      ..download = _downloadFilename ?? 'slowverb-export'
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  ExportOptions _buildExportOptions() {
    switch (_selectedFormat) {
      case 'mp3':
        return ExportOptions(format: 'mp3', bitrateKbps: _mp3Bitrate);
      case 'aac':
        return ExportOptions(format: 'aac', bitrateKbps: _aacBitrate);
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
      web.URL.revokeObjectURL(_downloadUrl!);
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

  bool get _isSourceLossless {
    final editorState = ref.read(audioEditorProvider);
    return editorState.metadata?.isLossless ?? false;
  }

  String get _sourceFormat {
    final editorState = ref.read(audioEditorProvider);
    return editorState.metadata?.format.toUpperCase() ?? 'UNKNOWN';
  }

  Widget _buildSourceFormatBadge(BuildContext context) {
    final isLossless = _isSourceLossless;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isLossless ? SlowverbColors.accentMint : SlowverbColors.warning)
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              (isLossless ? SlowverbColors.accentMint : SlowverbColors.warning)
                  .withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLossless ? Icons.high_quality : Icons.compress,
            size: 12,
            color: isLossless
                ? SlowverbColors.accentMint
                : SlowverbColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            'Source: $_sourceFormat',
            style: TextStyle(
              color: isLossless
                  ? SlowverbColors.accentMint
                  : SlowverbColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlacButton() {
    final isLossless = _isSourceLossless;

    final button = _FormatButton(
      label: 'FLAC',
      description: isLossless
          ? 'Lossless compression'
          : 'Requires lossless source',
      icon: Icons.high_quality,
      isSelected: _selectedFormat == 'flac',
      onTap: isLossless
          ? () => setState(() => _selectedFormat = 'flac')
          : () {},
      isDisabled: !isLossless,
    );

    if (!isLossless) {
      return Tooltip(
        message:
            'FLAC export requires a lossless source file (WAV, FLAC, AIFF).\n'
            'Your source is $_sourceFormat which is lossy.',
        child: button,
      );
    }

    return button;
  }
}

/// Format button widget
class _FormatButton extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDisabled;

  const _FormatButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? SlowverbColors.primaryPurple.withValues(alpha: 0.2)
                : SlowverbColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected && !isDisabled
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
                color: isSelected && !isDisabled
                    ? SlowverbColors.accentPink
                    : SlowverbColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isSelected && !isDisabled
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
      ),
    );
  }
}
