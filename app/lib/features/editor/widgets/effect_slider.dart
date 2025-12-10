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
import 'package:flutter/material.dart';
import 'package:slowverb/app/colors.dart';
import 'package:slowverb/app/slowverb_design_tokens.dart';
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
      padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: SlowverbColors.neonCyan),
              const SizedBox(width: SlowverbTokens.spacingXs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: SlowverbColors.onSurface,
                ),
              ),
              const Spacer(),
              _ValuePill(text: formatValue(value)),
            ],
          ),
          const SizedBox(height: SlowverbTokens.spacingSm),
          Theme(
            data: Theme.of(context).copyWith(
              sliderTheme: SliderThemeData(
                activeTrackColor: SlowverbColors.hotPink,
                inactiveTrackColor: SlowverbColors.onSurfaceMuted.withOpacity(
                  0.35,
                ),
                thumbColor: SlowverbColors.neonCyan,
                overlayColor: SlowverbColors.neonCyan.withOpacity(0.2),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 10,
                  elevation: 4,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              label: '${formatValue(value)} $unit',
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
        color: SlowverbColors.surfaceVariant,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusPill),
        border: Border.all(color: SlowverbColors.hotPink.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: SlowverbColors.hotPink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
