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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  // Mobile-optimized minimal overlay layout
                  if (isMobile) {
                    return _MobileOverlayLayout(
                      projectName: project.name,
                      presetName: presetName,
                      state: state,
                      notifier: notifier,
                      projectId: widget.projectId,
                      onBack: () {
                        notifier.stopPlayback();
                        context.go(RoutePaths.home);
                      },
                    );
                  }

                  // Desktop/tablet layout
                  return Padding(
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
                              final isUltraWide = constraints.maxWidth >= 1400;
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

                              // Ultra-wide layout (3 columns): Waveform | Metadata | Effects
                              if (isUltraWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left: Expanded Waveform Transport
                                    Expanded(
                                      flex: 3,
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
                                    // Center: Track Info & Metadata Panel
                                    Expanded(
                                      flex: 2,
                                      child: SingleChildScrollView(
                                        child: _TrackMetadataPanel(
                                          projectName: project.name,
                                          duration: state.duration,
                                          presetId:
                                              state.selectedPresetId ??
                                              project.presetId,
                                          parameters: state.parameters,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: SlowverbTokens.spacingMd,
                                    ),
                                    // Right: Effects Column
                                    Expanded(
                                      flex: 2,
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
                              }

                              final controls = (isWide || isLandscape)
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              onPlayPause:
                                                  notifier.togglePlayback,
                                              onSeek: (pos) => notifier.seekTo(
                                                Duration(milliseconds: pos),
                                              ),
                                              onSeekBackward:
                                                  notifier.seekBackward,
                                              onSeekForward:
                                                  notifier.seekForward,
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
                                              onPlayPause:
                                                  notifier.togglePlayback,
                                              onSeek: (pos) => notifier.seekTo(
                                                Duration(milliseconds: pos),
                                              ),
                                              onSeekBackward:
                                                  notifier.seekBackward,
                                              onSeekForward:
                                                  notifier.seekForward,
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
                  );
                },
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

/// Mobile-optimized layout with floating controls and bottom sheet effects
class _MobileOverlayLayout extends StatefulWidget {
  final String projectName;
  final String presetName;
  final EditorState state;
  final EditorNotifier notifier;
  final String projectId;
  final VoidCallback onBack;

  const _MobileOverlayLayout({
    required this.projectName,
    required this.presetName,
    required this.state,
    required this.notifier,
    required this.projectId,
    required this.onBack,
  });

  @override
  State<_MobileOverlayLayout> createState() => _MobileOverlayLayoutState();
}

class _MobileOverlayLayoutState extends State<_MobileOverlayLayout> {
  bool _showEffectsSheet = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Slim top bar: back + export only
        Positioned(
          top: SlowverbTokens.spacingSm,
          left: SlowverbTokens.spacingSm,
          right: SlowverbTokens.spacingSm,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              _MiniChromeButton(icon: Icons.arrow_back, onTap: widget.onBack),
              // Export button
              _MiniChromeButton(
                icon: Icons.download,
                onTap: () =>
                    context.push(RoutePaths.exportWithId(widget.projectId)),
              ),
            ],
          ),
        ),

        // Floating mini transport bar at bottom
        Positioned(
          bottom: _showEffectsSheet ? 300 : SlowverbTokens.spacingMd,
          left: SlowverbTokens.spacingSm,
          right: SlowverbTokens.spacingSm,
          child: _MiniTransportBar(
            projectName: widget.projectName,
            position: widget.state.position,
            duration: widget.state.duration,
            isPlaying: widget.state.isPlaying,
            onPlayPause: widget.notifier.togglePlayback,
            onSeek: (pos) =>
                widget.notifier.seekTo(Duration(milliseconds: pos)),
            onExpandEffects: () =>
                setState(() => _showEffectsSheet = !_showEffectsSheet),
            isEffectsExpanded: _showEffectsSheet,
            presetName: widget.presetName,
          ),
        ),

        // Bottom sheet for effects (collapsed by default)
        if (_showEffectsSheet)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _MobileEffectsSheet(
              state: widget.state,
              notifier: widget.notifier,
              onClose: () => setState(() => _showEffectsSheet = false),
            ),
          ),
      ],
    );
  }
}

/// Compact chrome button for mobile
class _MiniChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniChromeButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Floating mini transport bar with slim progress and play/pause
class _MiniTransportBar extends StatelessWidget {
  final String projectName;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final void Function(int) onSeek;
  final VoidCallback onExpandEffects;
  final bool isEffectsExpanded;
  final String presetName;

  const _MiniTransportBar({
    required this.projectName,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeek,
    required this.onExpandEffects,
    required this.isEffectsExpanded,
    required this.presetName,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(SlowverbTokens.spacingSm),
      decoration: BoxDecoration(
        color: SlowverbColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
        boxShadow: [SlowverbTokens.shadowCard],
        border: Border.all(color: SlowverbColors.surfaceVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title and time
          Row(
            children: [
              Expanded(
                child: Text(
                  projectName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SlowverbColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: SlowverbColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Slim progress bar
          GestureDetector(
            onTapDown: (details) {
              final width = context.size?.width ?? 1;
              final percent = details.localPosition.dx / width;
              onSeek((duration.inMilliseconds * percent).toInt());
            },
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: SlowverbColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [SlowverbColors.hotPink, SlowverbColors.neonCyan],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Controls row: effects toggle, play/pause, preset badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Effects toggle
              IconButton(
                onPressed: onExpandEffects,
                icon: Icon(
                  isEffectsExpanded ? Icons.expand_more : Icons.tune,
                  color: isEffectsExpanded
                      ? SlowverbColors.neonCyan
                      : SlowverbColors.onSurfaceMuted,
                ),
                iconSize: 22,
                visualDensity: VisualDensity.compact,
                tooltip: 'Effects',
              ),

              // Play/pause button
              Material(
                color: SlowverbColors.accentGradient.colors.first,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPlayPause,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Preset badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SlowverbColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(
                    SlowverbTokens.radiusPill,
                  ),
                ),
                child: Text(
                  presetName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: SlowverbColors.hotPink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for effect controls on mobile
class _MobileEffectsSheet extends StatelessWidget {
  final EditorState state;
  final EditorNotifier notifier;
  final VoidCallback onClose;

  const _MobileEffectsSheet({
    required this.state,
    required this.notifier,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final presetId = state.selectedPresetId ?? 'slowed_reverb';
    final preset = Presets.getById(presetId) ?? Presets.slowedReverb;

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SlowverbTokens.radiusLg),
        ),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SlowverbColors.surfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Preset selector
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SlowverbTokens.spacingMd,
              vertical: SlowverbTokens.spacingSm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: Presets.all.map((p) {
                  final isSelected = p.id == presetId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) notifier.selectPreset(p.id);
                      },
                      selectedColor: SlowverbColors.hotPink.withValues(
                        alpha: 0.3,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? SlowverbColors.hotPink : null,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(height: 1),

          // Parameter sliders (scrollable)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: SlowverbTokens.spacingMd,
                vertical: SlowverbTokens.spacingSm,
              ),
              children: preset.parameters.map((param) {
                final value = state.parameters[param.id] ?? param.defaultValue;
                return _CompactSlider(
                  label: param.label,
                  value: value,
                  min: param.min,
                  max: param.max,
                  formatValue: (v) {
                    if (param.id == 'tempo') return '${(v * 100).toInt()}%';
                    if (param.id == 'pitch') {
                      return '${v.toStringAsFixed(1)} st';
                    }
                    return '${(v * 100).toInt()}%';
                  },
                  onChanged: (v) => notifier.updateParameter(param.id, v),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact slider for mobile effects sheet
class _CompactSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) formatValue;
  final ValueChanged<double> onChanged;

  const _CompactSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.formatValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SlowverbColors.onSurfaceMuted,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
                activeColor: SlowverbColors.neonCyan,
                inactiveColor: SlowverbColors.surfaceVariant,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              formatValue(value),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: SlowverbColors.neonCyan),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
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

/// Metadata panel for ultra-wide displays showing track info and effect summary.
class _TrackMetadataPanel extends StatelessWidget {
  final String projectName;
  final Duration duration;
  final String presetId;
  final Map<String, double> parameters;

  const _TrackMetadataPanel({
    required this.projectName,
    required this.duration,
    required this.presetId,
    required this.parameters,
  });

  @override
  Widget build(BuildContext context) {
    final preset = Presets.all.firstWhere(
      (p) => p.id == presetId,
      orElse: () => Presets.slowedReverb,
    );

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
          // Header
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: SlowverbColors.neonCyan,
                size: 20,
              ),
              const SizedBox(width: SlowverbTokens.spacingSm),
              Text(
                'Track Info',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),

          // Track Details
          _MetadataRow(label: 'Name', value: projectName),
          const SizedBox(height: SlowverbTokens.spacingSm),
          _MetadataRow(label: 'Duration', value: _formatDuration(duration)),
          const SizedBox(height: SlowverbTokens.spacingSm),
          _MetadataRow(label: 'Preset', value: preset.name),

          const SizedBox(height: SlowverbTokens.spacingLg),

          // Current Effect Values
          Text(
            'Current Effects',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: SlowverbColors.hotPink),
          ),
          const SizedBox(height: SlowverbTokens.spacingSm),

          _EffectValueBar(
            label: 'Tempo',
            value: parameters['tempo'] ?? 1.0,
            min: 0.5,
            max: 1.5,
            formatValue: (v) => '${(v * 100).toInt()}%',
          ),
          const SizedBox(height: SlowverbTokens.spacingXs),
          _EffectValueBar(
            label: 'Pitch',
            value: parameters['pitch'] ?? 0.0,
            min: -12,
            max: 12,
            formatValue: (v) => '${v.toStringAsFixed(1)} st',
          ),
          const SizedBox(height: SlowverbTokens.spacingXs),
          _EffectValueBar(
            label: 'Reverb',
            value: parameters['reverbAmount'] ?? 0.0,
            min: 0,
            max: 1,
            formatValue: (v) => '${(v * 100).toInt()}%',
          ),
          const SizedBox(height: SlowverbTokens.spacingXs),
          _EffectValueBar(
            label: 'Echo',
            value: parameters['wetDryMix'] ?? 0.0,
            min: 0,
            max: 1,
            formatValue: (v) => '${(v * 100).toInt()}%',
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: SlowverbColors.onSurfaceMuted,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: SlowverbColors.onSurface,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EffectValueBar extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) formatValue;

  const _EffectValueBar({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedValue = ((value - min) / (max - min)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SlowverbColors.onSurfaceMuted,
              ),
            ),
            Text(
              formatValue(value),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: SlowverbColors.neonCyan),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: SlowverbColors.surfaceVariant,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: normalizedValue,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SlowverbColors.hotPink, SlowverbColors.neonCyan],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
