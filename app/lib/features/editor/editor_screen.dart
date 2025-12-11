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
import 'package:slowverb/features/visualizer/visualizer_controller.dart';
import 'package:slowverb/features/visualizer/visualizer_panel.dart';

/// Main editor screen with VaporXP layout shared with the web experience.
class EditorScreen extends ConsumerStatefulWidget {
  final String projectId;

  const EditorScreen({super.key, required this.projectId});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _showControls = true;
  bool _isFullscreenVisualizer = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final project = state.currentProject;

    if (state.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        notifier.clearError();
        notifier.clearError();
      });
    }

    // Sync playback state with visualizer
    ref.listen(editorProvider.select((s) => s.isPlaying), (_, isPlaying) {
      ref.read(visualizerProvider.notifier).setPlaying(isPlaying);
    });

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

    final presetName = _presetNameFor(
      state.selectedPresetId ?? project.presetId,
    );

    return ResponsiveScaffold(
      // Use Stack to layer visualizer behind controls
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Visualizer
          const Positioned.fill(
            child: VisualizerPanel(mode: VisualizerMode.background),
          ),

          // Content Overlay
          if (!_isFullscreenVisualizer)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Bar with Fullscreen Toggle
                    _EditorTitleBar(
                      presetName: presetName,
                      onBack: () {
                        notifier.stopPlayback();
                        context.go(RoutePaths.home);
                      },
                      onExport: () => context.push(
                        RoutePaths.exportWithId(widget.projectId),
                      ),
                      onFullscreen: () {
                        setState(() => _isFullscreenVisualizer = true);
                      },
                    ),

                    const SizedBox(height: SlowverbTokens.spacingMd),

                    // Controls with minimize option
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;
                          final isLandscape =
                              constraints.maxWidth > constraints.maxHeight;

                          if (!_showControls) {
                            return Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: SlowverbTokens.spacingMd,
                                  right: SlowverbTokens.spacingMd,
                                ),
                                child: FloatingActionButton.small(
                                  onPressed: () =>
                                      setState(() => _showControls = true),
                                  tooltip: 'Show Controls',
                                  child: const Icon(Icons.unfold_more),
                                ),
                              ),
                            );
                          }

                          final controls = (isWide || isLandscape)
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: isLandscape ? 2 : 3,
                                      child: SingleChildScrollView(
                                        child: _WaveformTransportCard(
                                          projectName: project.name,
                                          position: state.position,
                                          duration: state.duration,
                                          isPlaying: state.isPlaying,
                                          isGeneratingPreview:
                                              state.isGeneratingPreview,
                                          onPlayPause: notifier.togglePlayback,
                                          onSeek: (pos) => notifier.seekTo(
                                            Duration(milliseconds: pos),
                                          ),
                                          onSeekBackward: notifier.seekBackward,
                                          onSeekForward: notifier.seekForward,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: SlowverbTokens.spacingMd,
                                    ),
                                    Expanded(
                                      flex: isLandscape ? 1 : 2,
                                      child: SingleChildScrollView(
                                        child: _EffectColumn(
                                          state: state,
                                          onPresetSelected:
                                              notifier.selectPreset,
                                          onUpdateParam:
                                              notifier.updateParameter,
                                          onMinimize: () => setState(
                                            () => _showControls = false,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: _WaveformTransportCard(
                                          projectName: project.name,
                                          position: state.position,
                                          duration: state.duration,
                                          isPlaying: state.isPlaying,
                                          isGeneratingPreview:
                                              state.isGeneratingPreview,
                                          onPlayPause: notifier.togglePlayback,
                                          onSeek: (pos) => notifier.seekTo(
                                            Duration(milliseconds: pos),
                                          ),
                                          onSeekBackward: notifier.seekBackward,
                                          onSeekForward: notifier.seekForward,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: SlowverbTokens.spacingMd,
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: _EffectColumn(
                                          state: state,
                                          onPresetSelected:
                                              notifier.selectPreset,
                                          onUpdateParam:
                                              notifier.updateParameter,
                                          onMinimize: () => setState(
                                            () => _showControls = false,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );

                          return controls;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Fullscreen Exit Buttons
          if (_isFullscreenVisualizer)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FloatingActionButton.small(
                      onPressed: () {
                        notifier.stopPlayback();
                        context.go(RoutePaths.home);
                      },
                      tooltip: 'Back',
                      child: const Icon(Icons.arrow_back),
                    ),
                    FloatingActionButton.small(
                      onPressed: () {
                        setState(() => _isFullscreenVisualizer = false);
                      },
                      tooltip: 'Exit Fullscreen',
                      child: const Icon(Icons.fullscreen_exit),
                    ),
                  ],
                ),
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
  final VoidCallback onFullscreen;

  const _EditorTitleBar({
    required this.presetName,
    required this.onBack,
    required this.onExport,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow
            ? SlowverbTokens.spacingSm
            : SlowverbTokens.spacingLg,
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
          const Flexible(child: _VisualizerSelector()),
          if (!isNarrow) const SizedBox(width: SlowverbTokens.spacingSm),
          if (!isNarrow)
            Flexible(
              child: Text(
                'Slowverb Editor',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  letterSpacing: 1.2,
                  shadows: const [
                    Shadow(color: Colors.black54, offset: Offset(0, 1)),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Spacer(),
          _ChromeButton(icon: Icons.fullscreen, onTap: onFullscreen),
          if (!isNarrow) const SizedBox(width: SlowverbTokens.spacingSm),
          if (!isNarrow) Flexible(child: _PresetBadge(presetName: presetName)),
          const SizedBox(width: SlowverbTokens.spacingSm),
          isNarrow
              ? IconButton(
                  onPressed: onExport,
                  icon: const Icon(Icons.download),
                  tooltip: 'Export',
                )
              : ElevatedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
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
          Text(projectName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SlowverbTokens.spacingMd),
          // Visualizer is now in background
          Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) => onSeek((value * totalMs).toInt()),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Center(
              child: PlaybackControls(
                isPlaying: isPlaying,
                onPlayPause: onPlayPause,
                onSeekBackward: onSeekBackward,
                onSeekForward: onSeekForward,
                onLoop: () {},
                isProcessing: isGeneratingPreview,
              ),
            ),
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
  final VoidCallback onMinimize;

  const _EffectColumn({
    required this.state,
    required this.onPresetSelected,
    required this.onUpdateParam,
    required this.onMinimize,
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: Presets.all.map((preset) {
                final isSelected =
                    preset.id == (state.selectedPresetId ?? 'slowed_reverb');
                return Padding(
                  padding: const EdgeInsets.only(
                    right: SlowverbTokens.spacingSm,
                  ),
                  child: ChoiceChip(
                    label: Text(preset.name),
                    selected: isSelected,
                    onSelected: (_) => onPresetSelected(preset.id),
                    selectedColor: SlowverbColors.hotPink.withOpacity(0.2),
                    backgroundColor: SlowverbColors.surfaceVariant,
                    labelStyle: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(
                          color: isSelected
                              ? SlowverbColors.hotPink
                              : SlowverbColors.onSurface,
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
                  ),
                );
              }).toList(),
            ),
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
            const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            const SizedBox(width: SlowverbTokens.spacingXs),
            Flexible(
              child: Text(
                currentPreset.name,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
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
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
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
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      Text(
                        preset.description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
        color: Colors.white.withOpacity(0.15),
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
