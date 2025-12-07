import 'package:flutter/material.dart';
import 'package:slowverb/app/colors.dart';
import 'package:slowverb/app/widgets/vaporwave_widgets.dart';

/// Slider widget for adjusting an effect parameter
class EffectSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final String Function(double) formatValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const EffectSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.formatValue,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: SlowverbColors.neonCyan,
                  shadows: [
                    const Shadow(color: SlowverbColors.neonCyan, blurRadius: 8),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SlowverbColors.deepPurple,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: SlowverbColors.hotPink.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  formatValue(value),
                  style: const TextStyle(
                    color: SlowverbColors.hotPink,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(
              sliderTheme: SliderThemeData(
                activeTrackColor: SlowverbColors.hotPink,
                inactiveTrackColor: SlowverbColors.deepPurple,
                thumbColor: SlowverbColors.neonCyan,
                overlayColor: SlowverbColors.neonCyan.withOpacity(0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  elevation: 4,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatValue(min),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: SlowverbColors.onSurfaceMuted,
                  ),
                ),
                Text(
                  formatValue(max),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: SlowverbColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
