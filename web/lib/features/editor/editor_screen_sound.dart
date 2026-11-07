part of 'editor_screen.dart';

/// Sound window: preset, the five main faders, playback device, mastering,
/// and a "More" disclosure for the rarer controls. One implementation for
/// every screen size.
class _SoundWindow extends ConsumerWidget {
  final bool collapsed;
  final VoidCallback onCollapse;

  const _SoundWindow({required this.collapsed, required this.onCollapse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioEditorProvider);
    final notifier = ref.read(audioEditorProvider.notifier);
    final params = state.currentParameters;
    final selectedId = state.selectedPreset.id;

    Widget slider(ParameterDefinition def) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: EffectSlider(
        label: def.label,
        value: params[def.id] ?? def.defaultValue,
        min: def.min,
        max: def.max,
        unit: '',
        formatValue: (v) => _formatEffectValue(def.id, v),
        onChanged: (v) => notifier.updateParameter(def.id, v),
      ),
    );

    return RetroWindow(
      title: 'Sound',
      collapsed: collapsed,
      onCollapse: onCollapse,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PlateLabel('Preset'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _PresetSelect(
                  selectedId: selectedId,
                  onSelected: notifier.applyPreset,
                ),
              ),
              if (selectedId == 'manual') ...[
                const SizedBox(width: 8),
                HwKey(
                  onPressed: () => _showSavePresetDialog(context, ref, params),
                  icon: Icons.save,
                  label: 'Save',
                  tooltip: 'Save these settings as a preset',
                ),
              ],
            ],
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),
          ...effectParameterDefinitions.map(slider),
          const SizedBox(height: SlowverbTokens.spacingSm),
          const PlateLabel('Playback device'),
          const SizedBox(height: 6),
          _KeySelector(
            semanticLabel: 'Playback device',
            options: _playbackDeviceOptions,
            value: params['playbackDevice'] ?? 0.0,
            onChanged: (v) => notifier.updateParameter('playbackDevice', v),
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),
          const _MasteringControls(),
          const SizedBox(height: SlowverbTokens.spacingSm),
          const Divider(height: 1),
          RetroDisclosure(
            title: 'More controls',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToggleRow(
                  label: 'HQ slow-down (SoundTouch)',
                  value: (params['hqTimeStretch'] ?? 0.0) > 0.5,
                  onChanged: (on) =>
                      notifier.updateParameter('hqTimeStretch', on ? 1 : 0),
                ),
                _ToggleRow(
                  label: 'HQ reverb',
                  value: (params['hqReverb'] ?? 0.0) > 0.5,
                  onChanged: (on) =>
                      notifier.updateParameter('hqReverb', on ? 1 : 0),
                ),
                const SizedBox(height: 6),
                const PlateLabel('Reverb type (HQ reverb)'),
                const SizedBox(height: 6),
                _KeySelector(
                  semanticLabel: 'Reverb type',
                  options: _reverbTypeOptions,
                  value: params['reverbType'] ?? 0.0,
                  enabled: (params['hqReverb'] ?? 0.0) > 0.5,
                  onChanged: (v) => notifier.updateParameter('reverbType', v),
                ),
                const SizedBox(height: SlowverbTokens.spacingMd),
                ...advancedReverbParameterDefinitions.map(slider),
                slider(phaserDecayDef),
                if ((params['phaserDecay'] ?? 0) > 0) slider(phaserSpeedHzDef),
                slider(bassGainDef),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetSelect extends ConsumerWidget {
  final String selectedId;
  final ValueChanged<EffectPreset> onSelected;
  const _PresetSelect({required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref
        .watch(allPresetsProvider)
        .maybeWhen(data: (all) => all, orElse: () => Presets.all);
    final builtIn = {for (final p in Presets.all) p.id};

    return RetroSelect<String>(
      semanticLabel: 'Preset',
      value: selectedId,
      fallbackLabel: 'Manual',
      onChanged: (id) {
        final preset = presets.where((p) => p.id == id).firstOrNull;
        if (preset != null) onSelected(preset);
      },
      options: [
        for (final p in presets)
          RetroOption(
            p.id,
            p.name,
            detail: p.description.isEmpty ? null : p.description,
            trailing: builtIn.contains(p.id)
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Delete preset',
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await ref
                          .read(presetRepositoryProvider)
                          .deleteCustomPreset(p.id);
                      ref.invalidate(customPresetsProvider);
                    },
                  ),
          ),
      ],
    );
  }
}

/// Mastering on/off plus quality level. Writes the persistent mastering
/// settings; the editor mirrors them into its render parameters, so the
/// switch, the MASTER lamp and the render always agree.
class _MasteringControls extends ConsumerWidget {
  const _MasteringControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(masteringSettingsProvider);
    final settingsNotifier = ref.read(masteringSettingsProvider.notifier);
    final level5 = settings.mode >= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ToggleRow(
          label: 'Mastering',
          detail: 'Final loudness and peak safety (PhaseLimiter).',
          value: settings.masteringEnabled,
          onChanged: (on) {
            if (on) settingsNotifier.setPhaselimiterEnabled(true);
            settingsNotifier.setMasteringEnabled(on);
          },
        ),
        if (settings.masteringEnabled) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const PlateLabel('Quality'),
              const SizedBox(width: 12),
              Expanded(
                child: _KeySelector(
                  semanticLabel: 'Mastering quality',
                  options: const ['Level 3', 'Level 5 (slow)'],
                  value: level5 ? 1 : 0,
                  onChanged: (v) => settingsNotifier.setMode(v >= 1 ? 5 : 3),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

const _playbackDeviceOptions = [
  'Off',
  'Car (front)',
  'Car (rear)',
  'Gramophone',
  'Cassette',
];
const _reverbTypeOptions = ['Tone', 'Freeverb', 'Plate', 'Hotel Bathroom'];

/// Row of selector keys; the lit key is the current choice. The value is
/// the selected option's index (as a double, to match effect parameters).
class _KeySelector extends StatelessWidget {
  final String semanticLabel;
  final List<String> options;
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;

  const _KeySelector({
    required this.semanticLabel,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < options.length; i++)
            HwKey(
              onPressed: enabled ? () => onChanged(i.toDouble()) : null,
              label: options[i],
              lit: value.round() == i,
              size: 32,
            ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String? detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                  if (detail != null)
                    Text(detail!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
