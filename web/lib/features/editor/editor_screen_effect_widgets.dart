part of 'editor_screen.dart';

class _EffectColumn extends ConsumerWidget {
  final String selectedPresetId;
  final Map<String, double> parameters;
  final ValueChanged<EffectPreset> onPresetSelected;
  final void Function(String, double) onUpdateParam;
  final VoidCallback onMinimize;

  const _EffectColumn({
    required this.selectedPresetId,
    required this.parameters,
    required this.onPresetSelected,
    required this.onUpdateParam,
    required this.onMinimize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masteringOn = (parameters['masteringEnabled'] ?? 0.0) > 0.5;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // If we have enough width (e.g. tablet/desktop), split side-by-side
          final useSideBySide = constraints.maxWidth > 500;

          if (useSideBySide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PRESETS COLUMN
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Presets',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          // Save Preset button (only visible in Manual mode)
                          if (selectedPresetId == 'manual')
                            TextButton.icon(
                              icon: const Icon(Icons.save, size: 16),
                              label: const Text('Save'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _showSavePresetDialog(
                                context,
                                ref,
                                parameters,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Vertical list of presets with reduced padding
                      // Watching all presets (built-in + custom)
                      ref
                          .watch(allPresetsProvider)
                          .when(
                            data: (allPresets) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: allPresets.map((preset) {
                                final isSelected =
                                    preset.id == selectedPresetId;
                                final isCustom = !Presets.all.any(
                                  (p) => p.id == preset.id,
                                );

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? SlowverbColors.hotPink.withValues(
                                              alpha: 0.1,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                        SlowverbTokens.radiusSm,
                                      ),
                                      border: Border.all(
                                        color: isSelected
                                            ? SlowverbColors.hotPink
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Clickable preset name area
                                        Expanded(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () =>
                                                  onPresetSelected(preset),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    SlowverbTokens.radiusSm,
                                                  ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                child: Text(
                                                  preset.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.copyWith(
                                                        color: isSelected
                                                            ? SlowverbColors
                                                                  .hotPink
                                                            : SlowverbColors
                                                                  .textSecondary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Delete button for custom presets
                                        if (isCustom)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                            ),
                                            color: SlowverbColors.textHint,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Delete preset',
                                            onPressed: () async {
                                              final repo = ref.read(
                                                presetRepositoryProvider,
                                              );
                                              await repo.deleteCustomPreset(
                                                preset.id,
                                              );
                                              ref.invalidate(
                                                customPresetsProvider,
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: Presets.all.map((preset) {
                                final isSelected =
                                    preset.id == selectedPresetId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: InkWell(
                                    onTap: () => onPresetSelected(preset),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? SlowverbColors.hotPink.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          SlowverbTokens.radiusSm,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? SlowverbColors.hotPink
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: Text(
                                        preset.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: isSelected
                                                  ? SlowverbColors.hotPink
                                                  : SlowverbColors
                                                        .textSecondary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(width: SlowverbTokens.spacingMd),
                // SETTINGS COLUMN
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Settings',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          _ChromeButton(
                            icon: Icons.unfold_less,
                            onTap: onMinimize,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: SlowverbColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            SlowverbTokens.radiusMd,
                          ),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mastering',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Adds final peak safety + polish.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  SlowverbColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: masteringOn,
                                  onChanged: (v) {
                                    onUpdateParam(
                                      'masteringEnabled',
                                      v ? 1.0 : 0.0,
                                    );
                                    if (v) {
                                      onUpdateParam('masteringAlgorithm', 1.0);
                                    }
                                  },
                                  activeThumbColor: SlowverbColors.hotPink,
                                  activeTrackColor: SlowverbColors.hotPink
                                      .withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                            if (masteringOn) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Colors.white10),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Quality',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: SlowverbColors.textSecondary,
                                        ),
                                  ),
                                  Text(
                                    (parameters['masteringAlgorithm'] ?? 1.0) <
                                            1.5
                                        ? 'Level 3'
                                        : 'Level 5',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
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
                                  inactiveTrackColor:
                                      SlowverbColors.surfaceVariant,
                                  thumbColor: Colors.white,
                                  overlayColor: SlowverbColors.neonCyan
                                      .withValues(alpha: 0.2),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16,
                                  ),
                                ),
                                child: Slider(
                                  value:
                                      (parameters['masteringAlgorithm'] ?? 1.0)
                                          .clamp(1.0, 2.0),
                                  min: 1.0,
                                  max: 2.0,
                                  divisions: 1,
                                  onChanged: (v) =>
                                      onUpdateParam('masteringAlgorithm', v),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Higher quality will result in longer rendering times.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: SlowverbColors.textSecondary
                                          .withValues(alpha: 0.7),
                                      fontStyle: FontStyle.italic,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...effectParameterDefinitions.map(
                        (param) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: EffectSlider(
                            label: param.label,
                            value: parameters[param.id] ?? param.defaultValue,
                            min: param.min,
                            max: param.max,
                            unit: '',
                            formatValue: (v) => _formatEffectValue(param.id, v),
                            onChanged: (value) =>
                                onUpdateParam(param.id, value),
                          ),
                        ),
                      ),
                      if (advancedReverbParameterDefinitions.isNotEmpty)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            'Advanced Reverb',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: SlowverbColors.textSecondary),
                          ),
                          children: [
                            _HqProcessingToggles(
                              parameters: parameters,
                              onUpdateParam: onUpdateParam,
                            ),
                            ...advancedReverbParameterDefinitions.map(
                              (param) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: EffectSlider(
                                  label: param.label,
                                  value:
                                      parameters[param.id] ??
                                      param.defaultValue,
                                  min: param.min,
                                  max: param.max,
                                  unit: '',
                                  formatValue: (v) =>
                                      _formatEffectValue(param.id, v),
                                  onChanged: (value) =>
                                      onUpdateParam(param.id, value),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Fallback to vertical stack for narrow spaces
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Presets',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _ChromeButton(icon: Icons.unfold_less, onTap: onMinimize),
                ],
              ),
              const SizedBox(height: SlowverbTokens.spacingSm),
              Wrap(
                spacing: SlowverbTokens.spacingSm,
                runSpacing: SlowverbTokens.spacingSm,
                children: Presets.all.map((preset) {
                  final isSelected = preset.id == selectedPresetId;
                  return ChoiceChip(
                    label: Text(preset.name),
                    selected: isSelected,
                    onSelected: (_) => onPresetSelected(preset),
                    selectedColor: SlowverbColors.hotPink.withValues(
                      alpha: 0.2,
                    ),
                    backgroundColor: SlowverbColors.surfaceVariant,
                    labelStyle: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(
                          color: isSelected
                              ? SlowverbColors.hotPink
                              : SlowverbColors.textPrimary,
                        ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        SlowverbTokens.radiusSm,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? SlowverbColors.hotPink
                            : SlowverbColors.surfaceVariant,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: SlowverbTokens.spacingMd),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: SlowverbColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mastering',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Adds final peak safety + polish to previews and exports.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: SlowverbColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: masteringOn,
                          onChanged: (v) {
                            onUpdateParam('masteringEnabled', v ? 1.0 : 0.0);
                            if (v) {
                              onUpdateParam('masteringAlgorithm', 1.0);
                            }
                          },
                          activeThumbColor: SlowverbColors.hotPink,
                          activeTrackColor: SlowverbColors.hotPink.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ],
                    ),
                    if (masteringOn) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Colors.white10),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quality',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: SlowverbColors.textSecondary),
                          ),
                          Text(
                            (parameters['masteringAlgorithm'] ?? 1.0) < 1.5
                                ? 'Level 3'
                                : 'Level 5',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
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
                          overlayColor: SlowverbColors.neonCyan.withValues(
                            alpha: 0.2,
                          ),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                        ),
                        child: Slider(
                          value: (parameters['masteringAlgorithm'] ?? 1.0)
                              .clamp(1.0, 2.0),
                          min: 1.0,
                          max: 2.0,
                          divisions: 1,
                          onChanged: (v) =>
                              onUpdateParam('masteringAlgorithm', v),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Higher quality will result in longer rendering times.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SlowverbColors.textSecondary.withValues(
                            alpha: 0.7,
                          ),
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SlowverbTokens.spacingMd),
              // All effect parameters
              ...effectParameterDefinitions.map(
                (param) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: SlowverbTokens.spacingMd,
                  ),
                  child: EffectSlider(
                    label: param.label,
                    value: parameters[param.id] ?? param.defaultValue,
                    min: param.min,
                    max: param.max,
                    unit: '',
                    formatValue: (v) => _formatEffectValue(param.id, v),
                    onChanged: (value) => onUpdateParam(param.id, value),
                  ),
                ),
              ),
              if (advancedReverbParameterDefinitions.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Advanced Reverb',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SlowverbColors.textSecondary,
                    ),
                  ),
                  children: [
                    _HqProcessingToggles(
                      parameters: parameters,
                      onUpdateParam: onUpdateParam,
                    ),
                    ...advancedReverbParameterDefinitions.map(
                      (param) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: SlowverbTokens.spacingMd,
                        ),
                        child: EffectSlider(
                          label: param.label,
                          value: parameters[param.id] ?? param.defaultValue,
                          min: param.min,
                          max: param.max,
                          unit: '',
                          formatValue: (v) => _formatEffectValue(param.id, v),
                          onChanged: (value) => onUpdateParam(param.id, value),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
