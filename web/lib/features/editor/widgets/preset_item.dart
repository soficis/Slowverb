// Helper widget for displaying a single preset item
Widget _buildPresetItem({
  required BuildContext context,
  required EffectPreset preset,
  required String selectedPresetId,
  required bool isCustom,
  required ValueChanged<String> onPresetSelected,
  required WidgetRef ref,
}) {
  final isSelected = preset.id == selectedPresetId;

  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Container(
      decoration: BoxDecoration(
        color: isSelected
            ? SlowverbColors.hotPink.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
        border: Border.all(
          color: isSelected ? SlowverbColors.hotPink : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          // Clickable text area
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onPresetSelected(preset.id),
                borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    preset.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? SlowverbColors.hotPink
                          : SlowverbColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Delete button for custom presets
          if (isCustom)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: SlowverbColors.textHint,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              tooltip: 'Delete preset',
              onPressed: () async {
                final repo = ref.read(presetRepositoryProvider);
                await repo.deleteCustomPreset(preset.id);
                ref.invalidate(customPresetsProvider);
              },
            ),
        ],
      ),
    ),
  );
}
