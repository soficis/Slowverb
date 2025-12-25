import 'package:flutter/material.dart';
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('PHASELIMITER $modeLabel'),
        const SizedBox(height: 16),
        _buildModeSelector(),
        const SizedBox(height: 24),
        _buildTargetLufsSlider(context),
        const SizedBox(height: 24),
        _buildBassPreservationSlider(context),
        const SizedBox(height: 32),
        _buildSectionHeader('EXPORT FORMAT'),
        const SizedBox(height: 16),
        _buildFormatSelector(),
        const SizedBox(height: 16),
        _buildFormatSettings(context),
        if (state.showZipOption) ...[
          const SizedBox(height: 24),
          _buildZipToggle(),
        ],
      ],
    );
  }

  Widget _buildModeSelector() {
    final isProMode = state.settings.mode == 5;

    return Row(
      children: [
        Expanded(
          child: _buildModeButton(
            mode: 3,
            label: 'Standard',
            description: 'Fast processing',
            isSelected: !isProMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Tooltip(
            message:
                'Pro mode uses advanced AI optimization.\nProcessing may take several minutes.',
            child: _buildModeButton(
              mode: 5,
              label: 'Pro',
              description: 'Higher quality (slower)',
              isSelected: isProMode,
              showWarning: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required int mode,
    required String label,
    required String description,
    required bool isSelected,
    bool showWarning = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onModeChanged(mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.purple.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.purple
                  : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.purple : Colors.white70,
                    ),
                  ),
                  if (showWarning && isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule, size: 16, color: Colors.orange),
                  ],
                  if (isSelected) ...[
                    const Spacer(),
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Colors.purple,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.purple.shade200 : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: Colors.white54,
      ),
    );
  }

  Widget _buildTargetLufsSlider(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Target Loudness (LUFS)',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              '${state.settings.targetLufs.toStringAsFixed(0)} LUFS',
              style: const TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.purple,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.purple,
          ),
          child: Slider(
            value: state.settings.targetLufs,
            min: -24.0,
            max: -6.0,
            divisions: 18,
            onChanged: onTargetLufsChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '-24',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            _buildLufsPreset('-16', 'Podcast'),
            _buildLufsPreset('-14', 'Streaming', isDefault: true),
            _buildLufsPreset('-11', 'Club'),
            const Text(
              '-6',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLufsPreset(
    String value,
    String label, {
    bool isDefault = false,
  }) {
    final isSelected = state.settings.targetLufs == double.parse(value);
    return GestureDetector(
      onTap: () => onTargetLufsChanged(double.parse(value)),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: isSelected ? Colors.purple : Colors.white38,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.purple.shade200 : Colors.white24,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBassPreservationSlider(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bass Preservation',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              state.settings.bassPreservation.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.purple,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.purple,
          ),
          child: Slider(
            value: state.settings.bassPreservation,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: onBassPreservationChanged,
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Full Boost',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            Text(
              'Natural',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFormatButton('mp3', 'MP3', Icons.music_note),
        _buildFormatButton('aac', 'AAC', Icons.audio_file),
        _buildFormatButton('wav', 'WAV', Icons.waves),
        _buildFlacButton(),
      ],
    );
  }

  Widget _buildFormatButton(String format, String label, IconData icon) {
    final isSelected = state.selectedFormat == format;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onFormatChanged(format),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.purple.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.purple
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.purple : Colors.white54,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.purple : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check, size: 16, color: Colors.purple),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlacButton() {
    final isSelected = state.selectedFormat == 'flac';
    final isEnabled = state.isFlacEnabled;

    return Tooltip(
      message: isEnabled ? '' : 'Requires lossless source',
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? () => onFormatChanged('flac') : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.purple.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.purple
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.high_quality,
                    size: 18,
                    color: isSelected ? Colors.purple : Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'FLAC',
                    style: TextStyle(
                      color: isSelected ? Colors.purple : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (!isEnabled) ...[
                    const SizedBox(width: 4),
                    const Text('*', style: TextStyle(color: Colors.orange)),
                  ],
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, size: 16, color: Colors.purple),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatSettings(BuildContext context) {
    switch (state.selectedFormat) {
      case 'mp3':
        return _buildBitrateSlider(
          context: context,
          label: 'MP3 Bitrate',
          value: state.mp3Bitrate,
          min: 128,
          max: 320,
          divisions: 4,
          suffix: 'kbps',
          onChanged: onMp3BitrateChanged,
        );
      case 'aac':
        return _buildBitrateSlider(
          context: context,
          label: 'AAC Bitrate',
          value: state.aacBitrate,
          min: 128,
          max: 320,
          divisions: 4,
          suffix: 'kbps',
          onChanged: onAacBitrateChanged,
        );
      case 'flac':
        return _buildBitrateSlider(
          context: context,
          label: 'FLAC Compression',
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

  Widget _buildBitrateSlider({
    required BuildContext context,
    required String label,
    required int value,
    required int min,
    required int max,
    required int divisions,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(
              '$value$suffix',
              style: const TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.purple,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.purple,
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }

  Widget _buildZipToggle() {
    return Row(
      children: [
        Checkbox(
          value: state.zipExportEnabled,
          onChanged: (v) => onZipExportChanged(v ?? false),
          activeColor: Colors.purple,
        ),
        const Text(
          'Download as ZIP archive',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  // No longer using static context hack
}
