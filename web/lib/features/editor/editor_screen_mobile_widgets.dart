part of 'editor_screen.dart';

class _HqProcessingToggles extends StatelessWidget {
  final Map<String, double> parameters;
  final void Function(String, double) onUpdateParam;

  const _HqProcessingToggles({
    required this.parameters,
    required this.onUpdateParam,
  });

  @override
  Widget build(BuildContext context) {
    final hqTimeStretch = (parameters['hqTimeStretch'] ?? 0.0) > 0.5;
    final hqReverb = (parameters['hqReverb'] ?? 0.0) > 0.5;

    return Column(
      children: [
        _CompactToggleRow(
          label: 'HQ Slow (SoundTouch)',
          value: hqTimeStretch,
          onChanged: (enabled) =>
              onUpdateParam('hqTimeStretch', enabled ? 1.0 : 0.0),
        ),
        _CompactToggleRow(
          label: 'HQ Reverb (Tone IR)',
          value: hqReverb,
          onChanged: (enabled) =>
              onUpdateParam('hqReverb', enabled ? 1.0 : 0.0),
        ),
      ],
    );
  }
}

class _CompactToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SlowverbColors.textSecondary,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: SlowverbColors.neonCyan,
            activeTrackColor: SlowverbColors.neonCyan.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
