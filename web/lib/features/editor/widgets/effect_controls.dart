import 'package:flutter/material.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

/// Effect parameter controls
class EffectControls extends StatelessWidget {
  final double tempo;
  final double pitch;
  final double reverbAmount;
  final double echoAmount;
  final double eqWarmth;
  final ValueChanged<double> onTempoChanged;
  final ValueChanged<double> onPitchChanged;
  final ValueChanged<double> onReverbChanged;
  final ValueChanged<double> onEchoChanged;
  final ValueChanged<double> onEqWarmthChanged;

  const EffectControls({
    super.key,
    required this.tempo,
    required this.pitch,
    required this.reverbAmount,
    required this.echoAmount,
    required this.eqWarmth,
    required this.onTempoChanged,
    required this.onPitchChanged,
    required this.onReverbChanged,
    required this.onEchoChanged,
    required this.onEqWarmthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sliders = [
      _EffectSlider(
        label: 'Tempo',
        value: tempo,
        min: 0.5,
        max: 1.5,
        divisions: 100,
        valueFormat: (v) => '${(v * 100).toInt()}%',
        onChanged: onTempoChanged,
        icon: Icons.speed,
      ),
      _EffectSlider(
        label: 'Pitch',
        value: pitch,
        min: -12.0,
        max: 12.0,
        divisions: 24,
        valueFormat: (v) => '${v.toStringAsFixed(1)} st',
        onChanged: onPitchChanged,
        icon: Icons.music_note,
      ),
      _EffectSlider(
        label: 'Reverb',
        value: reverbAmount,
        min: 0.0,
        max: 1.0,
        divisions: 100,
        valueFormat: (v) => '${(v * 100).toInt()}%',
        onChanged: onReverbChanged,
        icon: Icons.waves,
      ),
      _EffectSlider(
        label: 'Echo',
        value: echoAmount,
        min: 0.0,
        max: 1.0,
        divisions: 100,
        valueFormat: (v) => '${(v * 100).toInt()}%',
        onChanged: onEchoChanged,
        icon: Icons.graphic_eq,
      ),
      _EffectSlider(
        label: 'Warmth',
        value: eqWarmth,
        min: 0.0,
        max: 1.0,
        divisions: 100,
        valueFormat: (v) => '${(v * 100).toInt()}%',
        onChanged: onEqWarmthChanged,
        icon: Icons.equalizer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 640;
        final itemWidth = isWide
            ? (constraints.maxWidth - SlowverbTokens.spacingLg) / 2
            : constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Effect Parameters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SlowverbTokens.spacingSm),
            Wrap(
              spacing: SlowverbTokens.spacingLg,
              runSpacing: SlowverbTokens.spacingMd,
              children: sliders
                  .map((slider) => SizedBox(width: itemWidth, child: slider))
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

/// Reusable effect slider widget
class _EffectSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) valueFormat;
  final ValueChanged<double> onChanged;
  final IconData icon;

  const _EffectSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueFormat,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SlowverbTokens.spacingSm),
      decoration: BoxDecoration(
        color: SlowverbColors.surfaceVariant,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
        border: Border.all(color: SlowverbColors.surface.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: SlowverbColors.accentCyan),
              const SizedBox(width: SlowverbTokens.spacingXs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: SlowverbColors.textSecondary,
                ),
              ),
              const Spacer(),
              _ValuePill(text: valueFormat(value)),
            ],
          ),
          const SizedBox(height: SlowverbTokens.spacingSm),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueFormat(value),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String text;

  const _ValuePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SlowverbTokens.spacingSm,
        vertical: SlowverbTokens.spacingXs,
      ),
      decoration: BoxDecoration(
        color: SlowverbColors.backgroundLight,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusPill),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: SlowverbColors.accentPink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
