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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb/app/colors.dart';
import 'package:slowverb/app/router.dart';
import 'package:slowverb/features/editor/editor_provider.dart';
import 'package:slowverb/features/effects/widgets/preset_card.dart';

/// Screen for selecting an effect preset
///
/// Displays available presets as a grid of cards.
/// User selects a preset after importing a track.
class EffectSelectionScreen extends ConsumerWidget {
  const EffectSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final project = editorState.currentProject;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, project?.name),
              Expanded(child: _buildPresetGrid(context, ref)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? trackName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go(RoutePaths.home),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose Effect',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trackName != null) ...[
                  Text(
                    trackName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: SlowverbColors.neonCyan,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  'Select a preset to apply to your track',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  Widget _buildPresetGrid(BuildContext context, WidgetRef ref) {
    final presets = _getPresets();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        return PresetCard(
          name: preset.name,
          description: preset.description,
          gradient: preset.gradient,
          icon: preset.icon,
          onTap: () => _selectPreset(context, ref, preset.id),
        );
      },
    );
  }

  List<_PresetData> _getPresets() {
    return [
      const _PresetData(
        id: 'slowed_reverb',
        name: 'Slowed + Reverb',
        description: 'Classic dreamy vaporwave effect',
        gradient: SlowverbColors.slowedReverbGradient,
        icon: Icons.slow_motion_video,
      ),
      const _PresetData(
        id: 'vaporwave_chill',
        name: 'Vaporwave Chill',
        description: 'Warm, nostalgic sound',
        gradient: SlowverbColors.vaporwaveChillGradient,
        icon: Icons.nights_stay,
      ),
      const _PresetData(
        id: 'nightcore',
        name: 'Nightcore',
        description: 'Fast & energetic',
        gradient: SlowverbColors.nightcoreGradient,
        icon: Icons.bolt,
      ),
      const _PresetData(
        id: 'echo_slow',
        name: 'Echo Slow',
        description: 'Hazy with deep echoes',
        gradient: SlowverbColors.echoSlowGradient,
        icon: Icons.waves,
      ),
      const _PresetData(
        id: 'manual',
        name: 'Manual',
        description: 'Full control over all params',
        gradient: LinearGradient(
          colors: [SlowverbColors.surfaceVariant, SlowverbColors.surface],
        ),
        icon: Icons.tune,
      ),
    ];
  }

  void _selectPreset(BuildContext context, WidgetRef ref, String presetId) {
    final notifier = ref.read(editorProvider.notifier);
    notifier.selectPreset(presetId);

    final project = ref.read(editorProvider).currentProject;
    if (project != null) {
      context.go(RoutePaths.editorWithId(project.id));
    } else {
      // No project, go back to home
      context.go(RoutePaths.home);
    }
  }
}

class _PresetData {
  final String id;
  final String name;
  final String description;
  final Gradient gradient;
  final IconData icon;

  const _PresetData({
    required this.id,
    required this.name,
    required this.description,
    required this.gradient,
    required this.icon,
  });
}
