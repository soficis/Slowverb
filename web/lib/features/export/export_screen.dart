import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';
import 'package:slowverb_web/providers/settings_provider.dart';
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
  String _exportStage = 'processing';
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
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    final padding = isNarrow
        ? SlowverbTokens.spacingMd
        : SlowverbTokens.spacingXl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
        leading: const BackButton(),
      ),
      body: RetroDesktop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _isExporting
                        ? _buildExportingView()
                        : _buildConfigurationView(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationView() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RetroWindow(
          title: 'Format',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose your export format and settings',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: SlowverbTokens.spacingMd),
              Row(
                children: [
                  const PlateLabel('Output format'),
                  const Spacer(),
                  _buildSourceFormatBadge(context),
                ],
              ),
              const SizedBox(height: SlowverbTokens.spacingSm),
              Wrap(
                spacing: SlowverbTokens.spacingSm,
                runSpacing: SlowverbTokens.spacingSm,
                children: [
                  HwKey(
                    onPressed: () => setState(() => _selectedFormat = 'mp3'),
                    label: 'MP3',
                    lit: _selectedFormat == 'mp3',
                    size: 32,
                  ),
                  HwKey(
                    onPressed: () => setState(() => _selectedFormat = 'aac'),
                    label: 'AAC',
                    lit: _selectedFormat == 'aac',
                    size: 32,
                  ),
                  HwKey(
                    onPressed: () => setState(() => _selectedFormat = 'wav'),
                    label: 'WAV',
                    lit: _selectedFormat == 'wav',
                    size: 32,
                  ),
                  _buildFlacKey(),
                ],
              ),
              const SizedBox(height: SlowverbTokens.spacingSm),
              Wrap(
                spacing: SlowverbTokens.spacingMd,
                runSpacing: SlowverbTokens.spacingXs,
                children: [
                  _buildFormatNote('MP3', 'Compressed, universally compatible'),
                  _buildFormatNote('AAC', 'High quality, modern codec'),
                  _buildFormatNote('WAV', 'Uncompressed, max quality'),
                  _buildFormatNote(
                    'FLAC',
                    _isSourceLossless
                        ? 'Lossless compression'
                        : 'Requires lossless source',
                  ),
                ],
              ),
              if (_selectedFormat != 'wav') ...[
                const Divider(height: SlowverbTokens.spacingLg),
                if (_selectedFormat == 'mp3')
                  _buildBitrateSetting(
                    label: 'MP3 bitrate',
                    value: _mp3Bitrate,
                    min: 128,
                    max: 320,
                    divisions: 3,
                    onChanged: (value) =>
                        setState(() => _mp3Bitrate = value),
                  ),
                if (_selectedFormat == 'aac')
                  _buildBitrateSetting(
                    label: 'AAC bitrate',
                    value: _aacBitrate,
                    min: 128,
                    max: 256,
                    divisions: 2,
                    onChanged: (value) =>
                        setState(() => _aacBitrate = value),
                  ),
                if (_selectedFormat == 'flac')
                  _buildSliderSetting(
                    label: 'FLAC compression level',
                    readout: _buildReadout('$_flacCompressionLevel', 'level'),
                    slider: Slider(
                      value: _flacCompressionLevel.toDouble(),
                      min: 0,
                      max: 8,
                      divisions: 8,
                      label: 'Level $_flacCompressionLevel',
                      onChanged: (value) =>
                          setState(() => _flacCompressionLevel = value.toInt()),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: SlowverbTokens.spacingMd),
        RetroWindow(
          title: 'Export',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: SlowverbTokens.success,
                    size: 18,
                  ),
                  const SizedBox(width: SlowverbTokens.spacingSm),
                  Expanded(
                    child: Text(
                      'All processing happens locally in your browser. Your audio never leaves your device.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SlowverbTokens.spacingMd),
              if (_errorMessage != null) ...[
                VfdPanel(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: SlowverbTokens.error,
                        size: 18,
                      ),
                      const SizedBox(width: SlowverbTokens.spacingSm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: SlowverbTokens.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SlowverbTokens.spacingMd),
              ],
              HwKey(
                onPressed: _startExport,
                icon: Icons.download,
                label: 'Export as ${_selectedFormat.toUpperCase()}',
                style: HwKeyStyle.primary,
                isDefault: true,
              ),
            ],
          ),
        ),
        if (_downloadUrl != null) ...[
          const SizedBox(height: SlowverbTokens.spacingMd),
          _buildDownloadReadyCard(),
        ],
      ],
    );
  }

  Widget _buildExportingView() {
    final theme = Theme.of(context);
    final percent = (_exportProgress * 100).toInt();

    return RetroWindow(
      title: 'Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Annunciator(
                'EXPORTING',
                lit: true,
                color: SlowverbTokens.vfdAmber,
              ),
            ],
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),
          Center(child: VfdText('$percent%', size: 40)),
          const SizedBox(height: SlowverbTokens.spacingSm),
          Text(
            _formatExportStage(_exportStage),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SlowverbTokens.spacingLg),
          LinearProgressIndicator(value: _exportProgress, minHeight: 12),
          const SizedBox(height: SlowverbTokens.spacingLg),
          Align(
            alignment: Alignment.centerLeft,
            child: HwKey(
              onPressed: _cancelExport,
              icon: Icons.cancel,
              label: 'Cancel',
              style: HwKeyStyle.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required Widget readout,
    required Slider slider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlateLabel(label),
        const SizedBox(height: SlowverbTokens.spacingXs),
        Row(
          children: [
            Expanded(child: slider),
            const SizedBox(width: SlowverbTokens.spacingSm),
            VfdPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: readout,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBitrateSetting({
    required String label,
    required int value,
    required int min,
    required int max,
    required int divisions,
    required ValueChanged<int> onChanged,
  }) {
    return _buildSliderSetting(
      label: label,
      readout: _buildReadout('$value', 'kbps'),
      slider: Slider(
        value: value.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: divisions,
        label: '$value kbps',
        onChanged: (newValue) => onChanged(newValue.toInt()),
      ),
    );
  }

  Widget _buildReadout(String value, String unit) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SegmentReadout(value, size: 22),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: PlateLabel(unit),
        ),
      ],
    );
  }

  Widget _buildFormatNote(String label, String description) {
    final style = Theme.of(context).textTheme.bodySmall;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: style?.copyWith(
              color: SlowverbTokens.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: description, style: style),
        ],
      ),
    );
  }

  String _formatExportStage(String stage) {
    switch (stage) {
      case 'decoding':
        return 'Decoding audio...';
      case 'mastering':
        return 'Mastering audio...';
      case 'encoding':
        return 'Encoding export...';
      default:
        return 'Processing your audio...';
    }
  }

  Widget _buildDownloadReadyCard() {
    final theme = Theme.of(context);

    return RetroWindow(
      title: 'Download',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: SlowverbTokens.success,
                size: 20,
              ),
              const SizedBox(width: SlowverbTokens.spacingSm),
              Expanded(
                child: Text(
                  'Export ready',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (_downloadFilename != null) ...[
            const SizedBox(height: SlowverbTokens.spacingXs),
            Text(_downloadFilename!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: SlowverbTokens.spacingMd),
          Align(
            alignment: Alignment.centerLeft,
            child: HwKey(
              onPressed: _triggerDownload,
              icon: Icons.download,
              label: 'Download',
            ),
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
            backgroundColor: SlowverbTokens.error,
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
      _exportStage = 'processing';
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
              setState(() {
                _exportProgress = progress.progress;
                _exportStage = progress.stage;
              });
            },
            onError: (error, stack) {
              if (!mounted) return;
              _progressSub = null;
              setState(() {
                _isExporting = false;
                _errorMessage = 'Export failed: $error';
                _activeJobId = null;
                _exportStage = 'processing';
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
                    _exportStage = 'processing';
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
                  _exportStage = 'processing';
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
        _exportStage = 'processing';
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
      _exportStage = 'processing';
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
    // Check if mastering is enabled
    final masteringSettings = ref.read(masteringSettingsProvider);
    final masteringEnabled = masteringSettings.masteringEnabled;

    String base;
    if (originalName == null || !originalName.contains('.')) {
      base = 'slowverb-export';
    } else {
      base = originalName.split('.').first;
    }

    // Append _mastered if mastering is enabled
    if (masteringEnabled) {
      return '${base}_mastered.$format';
    }
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
      case 'aac':
        return 'audio/aac';
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
    final color = isLossless ? SlowverbTokens.success : SlowverbTokens.warning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isLossless ? Icons.high_quality : Icons.compress,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        VfdText('Source: $_sourceFormat', size: 11, color: color),
      ],
    );
  }

  Widget _buildFlacKey() {
    final isLossless = _isSourceLossless;

    return HwKey(
      onPressed: isLossless
          ? () => setState(() => _selectedFormat = 'flac')
          : null,
      label: 'FLAC',
      lit: _selectedFormat == 'flac',
      size: 32,
      tooltip: isLossless
          ? null
          : 'FLAC export requires a lossless source file (WAV, FLAC, AIFF).\n'
                'Your source is $_sourceFormat which is lossy.',
    );
  }
}
