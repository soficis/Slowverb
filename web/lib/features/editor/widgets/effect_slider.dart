import 'package:flutter/material.dart';
import 'package:slowverb_web/app/colors.dart';

class EffectSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final String Function(double)? formatValue;
  final ValueChanged<double> onChanged;

  const EffectSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.formatValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SlowverbColors.textSecondary,
              ),
            ),
            Text(
              formatValue != null
                  ? formatValue!(value)
                  : '${value.toStringAsFixed(1)}$unit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SlowverbColors.neonCyan,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: SlowverbColors.neonCyan,
            inactiveTrackColor: SlowverbColors.surfaceVariant,
            thumbColor: Colors.white,
            overlayColor: SlowverbColors.neonCyan.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
