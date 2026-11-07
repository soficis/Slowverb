part of 'editor_screen.dart';

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
    case 'phaserSpeedHz':
      return '${value.toStringAsFixed(1)} Hz';
    case 'phaserDecay':
      return '${(value * 100).toInt()}%';
    case 'bassGain':
      return '${value.toStringAsFixed(0)} dB';
    case 'stereoWidth':
      return '${value.toStringAsFixed(2)}x';
    default:
      return '${(value * 100).toInt()}%';
  }
}
