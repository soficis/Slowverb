import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/features/visualizer/visualizer_controller.dart';

/// Compact visualizer preset selector for the title bar.
///
/// Displays the current visualizer preset name and allows
/// selecting from available presets via popup menu.
class VisualizerSelector extends ConsumerWidget {
  const VisualizerSelector({super.key});

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
