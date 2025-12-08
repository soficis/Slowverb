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
import 'package:slowverb/app/slowverb_design_tokens.dart';
import 'package:slowverb/app/widgets/responsive_scaffold.dart';
import 'package:slowverb/domain/entities/effect_preset.dart';
import 'package:slowverb/features/editor/editor_provider.dart';
import 'package:slowverb/features/editor/widgets/effect_slider.dart';
import 'package:slowverb/features/editor/widgets/playback_controls.dart';

/// Main editor screen with VaporXP layout shared with the web experience.
class EditorScreen extends ConsumerWidget {
  final String projectId;

  const EditorScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final project = state.currentProject;

    if (state.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!)),
        );
        notifier.clearError();
      });
    }

    if (project == null) {
      return ResponsiveScaffold(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.white),
              const SizedBox(height: SlowverbTokens.spacingMd),
              Text(
                'No project loaded',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: SlowverbTokens.spacingMd),
              ElevatedButton(
                onPressed: () => context.go(RoutePaths.home),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    final presetName = _presetNameFor(state.selectedPresetId ?? project.presetId);

    return ResponsiveScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditorTitleBar(
            presetName: presetName,
            onBack: () {
              notifier.stopPlayback();
              context.go(RoutePaths.home);
            },
            onExport: () =>
                context.push(RoutePaths.exportWithId(projectId)),
          ),
          const SizedBox(height: SlowverbTokens.spacingLg),
          _FileInfoBanner(
            name: project.name,
            duration: state.duration,
            onChangeFile: () => context.go(RoutePaths.home),
          ),
          const SizedBox(height: SlowverbTokens.spacingLg),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1100;
                final content = isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _WaveformTransportCard(
                              projectName: project.name,
                              position: state.position,
                              duration: state.duration,
                              isPlaying: state.isPlaying,
                              isGeneratingPreview: state.isGeneratingPreview,
                              onPlayPause: notifier.togglePlayback,
                              onSeek: (pos) =>
                                  notifier.seekTo(Duration(milliseconds: pos)),
                              onSeekBackward: notifier.seekBackward,
                              onSeekForward: notifier.seekForward,
                            ),
                          ),
                          const SizedBox(width: SlowverbTokens.spacingLg),
                          Expanded(
                            flex: 2,
                            child: _EffectColumn(
                              state: state,
                              onPresetSelected: notifier.selectPreset,
                              onUpdateParam: notifier.updateParameter,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _WaveformTransportCard(
                            projectName: project.name,
                            position: state.position,
                            duration: state.duration,
                            isPlaying: state.isPlaying,
                            isGeneratingPreview: state.isGeneratingPreview,
                            onPlayPause: notifier.togglePlayback,
                            onSeek: (pos) =>
                                notifier.seekTo(Duration(milliseconds: pos)),
                            onSeekBackward: notifier.seekBackward,
                            onSeekForward: notifier.seekForward,
                          ),
                          const SizedBox(height: SlowverbTokens.spacingLg),
                          _EffectColumn(
                            state: state,
                            onPresetSelected: notifier.selectPreset,
                            onUpdateParam: notifier.updateParameter,
                          ),
                        ],
                      );

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: content,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _presetNameFor(String presetId) {
    final preset = Presets.all.firstWhere(
      (p) => p.id == presetId,
      orElse: () => Presets.slowedReverb,
    );
    return preset.name;
  }
}

class _EditorTitleBar extends StatelessWidget {
  final String presetName;
  final VoidCallback onBack;
  final VoidCallback onExport;

  const _EditorTitleBar({
    required this.presetName,
    required this.onBack,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SlowverbTokens.spacingLg,
        vertical: SlowverbTokens.spacingSm,
      ),
      decoration: BoxDecoration(
        gradient: SlowverbTokens.titleBarGradient,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: Row(
        children: [
          _ChromeButton(icon: Icons.arrow_back, onTap: onBack),
          const SizedBox(width: SlowverbTokens.spacingSm),
          Text(
            'Slowverb Editor',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  letterSpacing: 1.2,
                  shadows: const [
                    Shadow(color: Colors.black54, offset: Offset(0, 1)),
                  ],
                ),
          ),
          const Spacer(),
          _PresetBadge(presetName: presetName),
          const SizedBox(width: SlowverbTokens.spacingSm),
          ElevatedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download),
            label: const Text('Export'),
          ),
        ],
      ),
    );
  }
}

class _FileInfoBanner extends StatelessWidget {
  final String name;
  final Duration duration;
  final VoidCallback onChangeFile;

  const _FileInfoBanner({
    required this.name,
    required this.duration,
    required this.onChangeFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
      decoration: BoxDecoration(
        color: SlowverbColors.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
        border: Border.all(
          color: SlowverbColors.hotPink.withOpacity(0.25),
        ),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: Row(
        children: [
          const Icon(Icons.audio_file, color: SlowverbColors.hotPink),
          const SizedBox(width: SlowverbTokens.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Duration: ${_formatDuration(duration)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onChangeFile,
            icon: const Icon(Icons.close),
            tooltip: 'Change file',
          ),
        ],
      ),
    );
  }
}

class _WaveformTransportCard extends StatelessWidget {
  final String projectName;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isGeneratingPreview;
  final VoidCallback onPlayPause;
  final ValueChanged<int> onSeek;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;

  const _WaveformTransportCard({
    required this.projectName,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isGeneratingPreview,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSeekBackward,
    required this.onSeekForward,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
    final progress = position.inMilliseconds / totalMs;

    return Container(
      padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            projectName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F1B2F), Color(0xFF2A2343)],
              ),
              borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
              border: Border.all(
                color: SlowverbColors.neonCyan.withOpacity(0.25),
              ),
            ),
            child: const Center(
              child: Text(
                'Waveform Preview',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(height: SlowverbTokens.spacingSm),
          Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) => onSeek(
              (value * totalMs).toInt(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SlowverbTokens.spacingSm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  _formatDuration(duration),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: SlowverbTokens.spacingSm),
          PlaybackControls(
            isPlaying: isPlaying,
            onPlayPause: onPlayPause,
            onSeekBackward: onSeekBackward,
            onSeekForward: onSeekForward,
            onLoop: () {},
            isProcessing: isGeneratingPreview,
          ),
        ],
      ),
    );
  }
}

class _EffectColumn extends StatelessWidget {
  final EditorState state;
  final ValueChanged<String> onPresetSelected;
  final void Function(String, double) onUpdateParam;

  const _EffectColumn({
    required this.state,
    required this.onPresetSelected,
    required this.onUpdateParam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuickPresetChips(
            selectedId: state.selectedPresetId ?? 'slowed_reverb',
            onPresetSelected: onPresetSelected,
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),
          EffectSlider(
            label: 'Tempo',
            value: state.parameters['tempo'] ?? 1.0,
            min: 0.5,
            max: 1.5,
            unit: 'x',
            formatValue: (v) => '${(v * 100).toInt()}%',
            onChanged: (value) => onUpdateParam('tempo', value),
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),
          EffectSlider(
            label: 'Pitch',
            value: state.parameters['pitch'] ?? 0.0,
            min: -12,
            max: 12,
            unit: 'st',
            formatValue: (v) => v.toStringAsFixed(1),
            onChanged: (value) => onUpdateParam('pitch', value),
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),
          EffectSlider(
            label: 'Reverb',
            value: state.parameters['reverbAmount'] ?? 0.0,
            min: 0,
            max: 1,
            unit: '%',
            formatValue: (v) => '${(v * 100).toInt()}%',
            onChanged: (value) => onUpdateParam('reverbAmount', value),
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),
          EffectSlider(
            label: 'Echo',
            value: state.parameters['wetDryMix'] ?? 0.0,
            min: 0,
            max: 1,
            unit: '%',
            formatValue: (v) => '${(v * 100).toInt()}%',
            onChanged: (value) => onUpdateParam('wetDryMix', value),
          ),
        ],
      ),
    );
  }
}

class _QuickPresetChips extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onPresetSelected;

  const _QuickPresetChips({
    required this.selectedId,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Presets',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: SlowverbTokens.spacingSm),
        Wrap(
          spacing: SlowverbTokens.spacingSm,
          runSpacing: SlowverbTokens.spacingSm,
          children: Presets.all.map((preset) {
            final isSelected = preset.id == selectedId;
            return ChoiceChip(
              label: Text(preset.name),
              selected: isSelected,
              onSelected: (_) => onPresetSelected(preset.id),
              selectedColor: SlowverbColors.hotPink.withOpacity(0.2),
              backgroundColor: SlowverbColors.surfaceVariant,
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? SlowverbColors.hotPink
                        : SlowverbColors.onSurface,
                  ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
                side: BorderSide(
                  color: isSelected
                      ? SlowverbColors.hotPink
                      : SlowverbColors.surfaceVariant,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ChromeButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.2),
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
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusPill),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 16, color: Colors.white),
          const SizedBox(width: SlowverbTokens.spacingXs),
          Text(
            presetName,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  letterSpacing: 1.2,
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
