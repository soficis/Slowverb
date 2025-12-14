import 'package:flutter/material.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';

/// Preset selector dialog
class PresetSelectorDialog extends StatefulWidget {
  final EffectPreset? currentPreset;

  const PresetSelectorDialog({super.key, this.currentPreset});

  @override
  State<PresetSelectorDialog> createState() => _PresetSelectorDialogState();
}

class _PresetSelectorDialogState extends State<PresetSelectorDialog> {
  late EffectPreset _selectedPreset;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.currentPreset ?? Presets.slowedReverb;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SlowverbColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      SlowverbColors.primaryGradient.createShader(bounds),
                  child: Text(
                    'EFFECT PRESETS',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      letterSpacing: 3.0,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Choose a professionally tuned preset or customize manually',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 24),

            // Preset grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: Presets.all.length,
                itemBuilder: (context, index) {
                  final preset = Presets.all[index];
                  final isSelected = preset.id == _selectedPreset.id;

                  return _PresetCard(
                    preset: preset,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _selectedPreset = preset);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Selected preset details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: SlowverbColors.backgroundLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedPreset.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedPreset.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: _selectedPreset.parameters.entries.map((entry) {
                      return _ParameterChip(
                        label: entry.key,
                        value: entry.value,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(_selectedPreset);
                  },
                  child: const Text('APPLY PRESET'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Preset card widget
class _PresetCard extends StatelessWidget {
  final EffectPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? SlowverbColors.primaryPurple.withOpacity(0.2)
              : SlowverbColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? SlowverbColors.primaryPurple
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getPresetIcon(preset.id),
              size: 32,
              color: isSelected
                  ? SlowverbColors.accentPink
                  : SlowverbColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              preset.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected
                    ? SlowverbColors.textPrimary
                    : SlowverbColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPresetIcon(String id) {
    switch (id) {
      case 'slowed_reverb':
        return Icons.waves;
      case 'vaporwave_chill':
        return Icons.spa;
      case 'nightcore':
        return Icons.flash_on;
      case 'echo_slow':
        return Icons.graphic_eq;
      case 'lofi':
        return Icons.headphones;
      case 'ambient':
        return Icons.cloud;
      case 'deep_bass':
        return Icons.music_note;
      case 'crystal_clear':
        return Icons.diamond;
      case 'underwater':
        return Icons.water;
      case 'synthwave':
        return Icons.electric_bolt;
      case 'slow_motion':
        return Icons.slow_motion_video;
      case 'manual':
        return Icons.tune;
      default:
        return Icons.music_note;
    }
  }
}

/// Parameter chip widget
class _ParameterChip extends StatelessWidget {
  final String label;
  final double value;

  const _ParameterChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: ${_formatValue(label, value)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: SlowverbColors.accentCyan,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatValue(String label, double value) {
    switch (label) {
      case 'tempo':
        return '${(value * 100).toInt()}%';
      case 'pitch':
        return '${value.toStringAsFixed(1)}st';
      default:
        return '${(value * 100).toInt()}%';
    }
  }
}
