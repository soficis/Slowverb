import 'package:flutter/material.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/providers/mastering_provider.dart';

/// Controls widget for mastering settings
class MasteringControls extends StatelessWidget {
  final MasteringState state;
  final ValueChanged<double> onTargetLufsChanged;
  final ValueChanged<double> onBassPreservationChanged;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<int> onMp3BitrateChanged;
  final ValueChanged<int> onAacBitrateChanged;
  final ValueChanged<int> onFlacCompressionChanged;
  final ValueChanged<bool> onZipExportChanged;
  final ValueChanged<int> onModeChanged;

  const MasteringControls({
    super.key,
    required this.state,
    required this.onTargetLufsChanged,
    required this.onBassPreservationChanged,
    required this.onFormatChanged,
    required this.onMp3BitrateChanged,
    required this.onAacBitrateChanged,
    required this.onFlacCompressionChanged,
    required this.onZipExportChanged,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isProMode = state.settings.mode == 5;
    final modeLabel = isProMode ? 'LEVEL 5 PRO' : 'LEVEL 3 STANDARD';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlateLabel('Phaselimiter $modeLabel'),
        const SizedBox(height: SlowverbTokens.spacingSm),
        _buildModeSelector(context),
        const SizedBox(height: SlowverbTokens.spacingMd),
        _buildTargetLufsSlider(context),
        const SizedBox(height: SlowverbTokens.spacingMd),
        _buildBassPreservationSlider(context),
        const SizedBox(height: SlowverbTokens.spacingLg),
        const PlateLabel('Export format'),
        const SizedBox(height: SlowverbTokens.spacingSm),
        _buildFormatSelector(),
        const SizedBox(height: SlowverbTokens.spacingMd),
        _buildFormatSettings(context),
        if (state.showZipOption) ...[
          const SizedBox(height: SlowverbTokens.spacingMd),
          _buildZipToggle(context),
        ],
      ],
    );
  }

  Widget _buildModeSelector(BuildContext context) {
    final theme = Theme.of(context);
    final isProMode = state.settings.mode == 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: SlowverbTokens.spacingSm,
          runSpacing: SlowverbTokens.spacingSm,
          children: [
            HwKey(
              onPressed: () => onModeChanged(3),
              label: 'Standard',
              lit: !isProMode,
              size: 32,
            ),
            HwKey(
              onPressed: () => onModeChanged(5),
              label: 'Pro',
              lit: isProMode,
              size: 32,
              tooltip:
                  'Pro mode uses advanced AI optimization.\nProcessing may take several minutes.',
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Standard — fast processing', style: theme.textTheme.bodySmall),
        Text(
          'Pro — higher quality (slower)',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildTargetLufsSlider(BuildContext context) {
    final theme = Theme.of(context);
    final value = state.settings.targetLufs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Target loudness (LUFS)',
                style: theme.textTheme.titleSmall,
              ),
            ),
            VfdPanel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SegmentReadout(value.toStringAsFixed(0), size: 20),
                  const SizedBox(width: 4),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: PlateLabel('LUFS'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('-24', style: theme.textTheme.bodySmall),
            Expanded(
              child: Slider(
                value: value,
                min: -24.0,
                max: -6.0,
                divisions: 18,
                onChanged: onTargetLufsChanged,
              ),
            ),
            Text('-6', style: theme.textTheme.bodySmall),
          ],
        ),
        Wrap(
          spacing: SlowverbTokens.spacingSm,
          runSpacing: SlowverbTokens.spacingSm,
          children: [
            HwKey(
              onPressed: () => onTargetLufsChanged(-16),
              label: '-16 Podcast',
              lit: value == -16,
              size: 32,
            ),
            HwKey(
              onPressed: () => onTargetLufsChanged(-14),
              label: '-14 Streaming',
              lit: value == -14,
              size: 32,
            ),
            HwKey(
              onPressed: () => onTargetLufsChanged(-11),
              label: '-11 Club',
              lit: value == -11,
              size: 32,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBassPreservationSlider(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bass preservation',
                style: theme.textTheme.titleSmall,
              ),
            ),
            VfdPanel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: SegmentReadout(
                state.settings.bassPreservation.toStringAsFixed(1),
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: state.settings.bassPreservation,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          onChanged: onBassPreservationChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Full boost', style: theme.textTheme.bodySmall),
            Text('Natural', style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return Semantics(
      label: 'Export format',
      container: true,
      child: Wrap(
        spacing: SlowverbTokens.spacingSm,
        runSpacing: SlowverbTokens.spacingSm,
        children: [
          HwKey(
            onPressed: () => onFormatChanged('mp3'),
            label: 'MP3',
            lit: state.selectedFormat == 'mp3',
            size: 32,
          ),
          HwKey(
            onPressed: () => onFormatChanged('aac'),
            label: 'AAC',
            lit: state.selectedFormat == 'aac',
            size: 32,
          ),
          HwKey(
            onPressed: () => onFormatChanged('wav'),
            label: 'WAV',
            lit: state.selectedFormat == 'wav',
            size: 32,
          ),
          _buildFlacButton(),
        ],
      ),
    );
  }

  Widget _buildFlacButton() {
    final isEnabled = state.isFlacEnabled;

    return HwKey(
      onPressed: isEnabled ? () => onFormatChanged('flac') : null,
      label: 'FLAC',
      lit: state.selectedFormat == 'flac',
      size: 32,
      tooltip: isEnabled ? null : 'Requires lossless source',
    );
  }

  Widget _buildFormatSettings(BuildContext context) {
    switch (state.selectedFormat) {
      case 'mp3':
        return _buildBitrateSlider(
          context,
          label: 'MP3 bitrate',
          value: state.mp3Bitrate,
          min: 128,
          max: 320,
          divisions: 4,
          suffix: 'kbps',
          onChanged: onMp3BitrateChanged,
        );
      case 'aac':
        return _buildBitrateSlider(
          context,
          label: 'AAC bitrate',
          value: state.aacBitrate,
          min: 128,
          max: 320,
          divisions: 4,
          suffix: 'kbps',
          onChanged: onAacBitrateChanged,
        );
      case 'flac':
        return _buildBitrateSlider(
          context,
          label: 'FLAC compression',
          value: state.flacCompressionLevel,
          min: 0,
          max: 8,
          divisions: 8,
          suffix: '',
          onChanged: onFlacCompressionChanged,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBitrateSlider(
    BuildContext context, {
    required String label,
    required int value,
    required int min,
    required int max,
    required int divisions,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.titleSmall),
            ),
            VfdPanel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SegmentReadout('$value', size: 20),
                  if (suffix.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: PlateLabel(suffix),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: divisions,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  Widget _buildZipToggle(BuildContext context) {
    final theme = Theme.of(context);

    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Download as ZIP archive',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Switch(
            value: state.zipExportEnabled,
            onChanged: onZipExportChanged,
          ),
        ],
      ),
    );
  }
}
