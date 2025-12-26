import 'package:flutter/material.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/parameter_definitions.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';

/// Bottom sheet for effect controls on mobile devices.
///
/// Displays preset selector and parameter sliders in a compact
/// scrollable format optimized for touch interaction.
class MobileEffectsSheet extends StatelessWidget {
  final String selectedPresetId;
  final Map<String, double> parameters;
  final AudioEditorNotifier notifier;
  final VoidCallback onClose;

  const MobileEffectsSheet({
    super.key,
    required this.selectedPresetId,
    required this.parameters,
    required this.notifier,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SlowverbTokens.radiusLg),
        ),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: Column(
        children: [
          _buildHandleBar(),
          _buildPresetSelector(context),
          const Divider(height: 1),
          Expanded(child: _buildParameterSliders()),
        ],
      ),
    );
  }

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: SlowverbColors.surfaceVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildPresetSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SlowverbTokens.spacingMd,
        vertical: SlowverbTokens.spacingSm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: Presets.all.map((preset) {
            final isSelected = preset.id == selectedPresetId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(preset.name),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) notifier.applyPreset(preset);
                },
                selectedColor: SlowverbColors.hotPink.withValues(alpha: 0.3),
                labelStyle: TextStyle(
                  color: isSelected ? SlowverbColors.hotPink : null,
                  fontSize: 12,
                ),
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildParameterSliders() {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: SlowverbTokens.spacingMd,
        vertical: SlowverbTokens.spacingSm,
      ),
      children: [
        ...effectParameterDefinitions.map((param) {
          final value = parameters[param.id] ?? param.defaultValue;
          return CompactSlider(
            label: param.label,
            value: value,
            min: param.min,
            max: param.max,
            formatValue: (v) => _formatParameterValue(param.id, v),
            onChanged: (v) => notifier.updateParameter(param.id, v),
          );
        }),
        if (advancedReverbParameterDefinitions.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Advanced Reverb'),
            children: advancedReverbParameterDefinitions.map((param) {
              final value = parameters[param.id] ?? param.defaultValue;
              return CompactSlider(
                label: param.label,
                value: value,
                min: param.min,
                max: param.max,
                formatValue: (v) => _formatParameterValue(param.id, v),
                onChanged: (v) => notifier.updateParameter(param.id, v),
              );
            }).toList(),
          ),
      ],
    );
  }

  String _formatParameterValue(String paramId, double value) {
    if (paramId == 'tempo') return '${(value * 100).toInt()}%';
    if (paramId == 'pitch') return '${value.toStringAsFixed(1)} st';
    if (paramId == 'preDelayMs') return '${value.toStringAsFixed(0)} ms';
    if (paramId == 'stereoWidth') return '${value.toStringAsFixed(2)}x';
    return '${(value * 100).toInt()}%';
  }
}

/// Compact slider for mobile effects sheet.
///
/// Displays label, slider, and formatted value in a horizontal row.
class CompactSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) formatValue;
  final ValueChanged<double> onChanged;

  const CompactSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.formatValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SlowverbColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
                activeColor: SlowverbColors.neonCyan,
                inactiveColor: SlowverbColors.surfaceVariant,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              formatValue(value),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: SlowverbColors.neonCyan),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
