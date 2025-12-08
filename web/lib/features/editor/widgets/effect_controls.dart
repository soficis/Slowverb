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
import 'package:slowverb_web/app/colors.dart';

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EFFECT PARAMETERS',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(letterSpacing: 2.0),
            ),
            const SizedBox(height: 24),

            // Tempo
            _EffectSlider(
              label: 'TEMPO',
              value: tempo,
              min: 0.5,
              max: 1.5,
              divisions: 100,
              valueFormat: (v) => '${(v * 100).toInt()}%',
              onChanged: onTempoChanged,
              icon: Icons.speed,
            ),

            const SizedBox(height: 20),

            // Pitch
            _EffectSlider(
              label: 'PITCH',
              value: pitch,
              min: -12.0,
              max: 12.0,
              divisions: 24,
              valueFormat: (v) => '${v.toStringAsFixed(1)} st',
              onChanged: onPitchChanged,
              icon: Icons.music_note,
            ),

            const SizedBox(height: 20),

            // Reverb
            _EffectSlider(
              label: 'REVERB',
              value: reverbAmount,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              valueFormat: (v) => '${(v * 100).toInt()}%',
              onChanged: onReverbChanged,
              icon: Icons.waves,
            ),

            const SizedBox(height: 20),

            // Echo
            _EffectSlider(
              label: 'ECHO',
              value: echoAmount,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              valueFormat: (v) => '${(v * 100).toInt()}%',
              onChanged: onEchoChanged,
              icon: Icons.graphic_eq,
            ),

            const SizedBox(height: 20),

            // EQ Warmth
            _EffectSlider(
              label: 'WARMTH',
              value: eqWarmth,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              valueFormat: (v) => '${(v * 100).toInt()}%',
              onChanged: onEqWarmthChanged,
              icon: Icons.equalizer,
            ),
          ],
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: SlowverbColors.accentCyan),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: SlowverbColors.textSecondary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: SlowverbColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                valueFormat(value),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SlowverbColors.accentPink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
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
    );
  }
}
