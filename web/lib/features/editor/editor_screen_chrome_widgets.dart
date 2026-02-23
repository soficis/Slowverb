part of 'editor_screen.dart';

class _ChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ChromeButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(
        alpha: 0.2,
      ), // Fixed deprecated withOpacity
      borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _VisualizerSelector extends ConsumerWidget {
  const _VisualizerSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visualizerState = ref.watch(visualizerProvider);
    final currentPreset = visualizerState.activePreset;

    return PopupMenuButton<String>(
      tooltip: 'Change Visualizer',
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SlowverbTokens.spacingMd,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(SlowverbTokens.radiusPill),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              currentPreset.name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                letterSpacing: 0.8,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
          ],
        ),
      ),
      onSelected: (presetId) {
        ref.read(visualizerProvider.notifier).selectPreset(presetId);
      },
      itemBuilder: (context) {
        return VisualizerController.presets.map((preset) {
          final isSelected = preset.id == currentPreset.id;
          return PopupMenuItem<String>(
            value: preset.id,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: isSelected ? SlowverbColors.neonCyan : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      Text(
                        preset.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

class _PresetBadge extends StatelessWidget {
  final String presetName;

  const _PresetBadge({required this.presetName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SlowverbTokens.spacingMd,
        vertical: SlowverbTokens.spacingXs + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15), // Fixed withOpacity
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusPill),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 16, color: Colors.white),
          const SizedBox(width: SlowverbTokens.spacingXs),
          Flexible(
            child: Text(
              presetName,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                letterSpacing: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Show dialog to save current parameters as a custom preset
void _showSavePresetDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, double> parameters,
) {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Save Custom Preset'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Preset Name',
              hintText: 'My Custom Sound',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'A brief description',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              // Show error
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a preset name')),
              );
              return;
            }

            // Create preset
            const uuid = Uuid();
            final preset = EffectPreset(
              id: 'custom_${uuid.v4()}',
              name: name,
              description: descriptionController.text.trim(),
              parameters: Map.from(parameters),
            );

            // Save to repository
            final repo = ref.read(presetRepositoryProvider);
            await repo.saveCustomPreset(preset);

            // Refresh provider
            ref.invalidate(customPresetsProvider);

            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved preset "${preset.name}"')),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

String _formatEffectValue(String paramId, double value) {
  switch (paramId) {
    case 'tempo':
      return '${(value * 100).toInt()}%';
    case 'pitch':
      return '${value.toStringAsFixed(1)} st';
    case 'preDelayMs':
      return '${value.toStringAsFixed(0)} ms';
    case 'roomScale':
    case 'reverbMix':
    case 'hfDamping':
      return '${(value * 100).toInt()}%';
    case 'stereoWidth':
      return '${value.toStringAsFixed(2)}x';
    default:
      return '${(value * 100).toInt()}%';
  }
}
