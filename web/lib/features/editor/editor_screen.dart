import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/router.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/app/widgets/responsive_scaffold.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/project.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';
import 'package:slowverb_web/features/editor/widgets/effect_slider.dart';
import 'package:slowverb_web/features/editor/widgets/playback_controls.dart';
import 'package:slowverb_web/features/visualizer/visualizer_controller.dart';
import 'package:slowverb_web/features/visualizer/visualizer_panel.dart';

// Parameter metadata definition
class _ParamDef {
  final String id;
  final String label;
  final double min;
  final double max;
  final double defaultValue;
  const _ParamDef(this.id, this.label, this.min, this.max, this.defaultValue);
}

const _kParameterDefinitions = [
  _ParamDef('tempo', 'Tempo', 0.5, 1.5, 1.0),
  _ParamDef('pitch', 'Pitch', -12.0, 12.0, 0.0),
  _ParamDef('reverbAmount', 'Reverb', 0.0, 1.0, 0.0),
  _ParamDef('echoAmount', 'Echo', 0.0, 1.0, 0.0),
  _ParamDef('eqWarmth', 'Warmth', 0.0, 1.0, 0.5),
];

/// Main editor screen with VaporXP layout shared with the web experience.
class EditorScreen extends ConsumerStatefulWidget {
  final AudioFileData? fileData;
  final Project? project;

  const EditorScreen({super.key, this.fileData, this.project});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _showControls = true;
  bool _isFullscreenVisualizer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.fileData != null) {
        ref
            .read(audioEditorProvider.notifier)
            .loadAudioFile(widget.fileData!, project: widget.project);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ported: editorProvider -> audioEditorProvider
    final state = ref.watch(audioEditorProvider);
    final notifier = ref.read(audioEditorProvider.notifier);

    // Adapted logic: construct project-like properties from state
    final hasProject = state.fileId != null || state.audioFileName != null;
    final projectName = state.projectName ?? state.audioFileName ?? 'Untitled';
    final duration = state.audioDuration ?? Duration.zero;
    // Calculate position from normalized playbackPosition
    final position = Duration(
      milliseconds: (state.playbackPosition * duration.inMilliseconds).toInt(),
    );

    final isPlaying = state.isPlaying;
    final isGeneratingPreview = state.isLoading; // Approximate
    final selectedPresetId = state.selectedPreset.id;
    final parameters = state.currentParameters;

    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        notifier.clearError();
      });
    }

    // Sync playback state with visualizer
    ref.listen(audioEditorProvider.select((s) => s.isPlaying), (_, isPlaying) {
      ref.read(visualizerProvider.notifier).setPlaying(isPlaying);
    });

    if (!hasProject && !state.isLoading) {
      return ResponsiveScaffold(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isLoading)
                const CircularProgressIndicator()
              else ...[
                const Icon(Icons.error_outline, size: 64, color: Colors.white),
                const SizedBox(height: SlowverbTokens.spacingMd),
                Text(
                  'No project loaded',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: SlowverbTokens.spacingMd),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.import_),
                  child: const Text('Go Home'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final presetName = _presetNameFor(selectedPresetId);
    final projectId = state.projectId ?? 'temp';

    return ResponsiveScaffold(
      fullWidth: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Visualizer
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, _) {
                final visualizerState = ref.watch(visualizerProvider);
                return VisualizerPanel(
                  preset: visualizerState.activePreset,
                  isPlaying: visualizerState.isPlaying,
                  analysisStream: null,
                  isFullscreen: true,
                );
              },
            ),
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
                      projectName: projectName,
                      presetName: presetName,
                      position: position,
                      duration: duration,
                      isPlaying: isPlaying,
                      isGeneratingPreview: isGeneratingPreview,
                      selectedPresetId: selectedPresetId,
                      parameters: parameters,

                      notifier: notifier,
                      projectId: projectId,
                      onBack: () {
                        notifier.stop();
                        context.go(AppRoutes.import_);
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
                            notifier.stop();
                            context.go(AppRoutes.import_);
                          },
                          onExport: () =>
                              context.push(AppRoutes.export, extra: projectId),
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
                                      flex: 2,
                                      child: SingleChildScrollView(
                                        child: _WaveformTransportCard(
                                          projectName: projectName,
                                          position: position,
                                          duration: duration,
                                          isPlaying: isPlaying,
                                          isGeneratingPreview:
                                              isGeneratingPreview,
                                          onPlayPause: notifier.togglePlayback,
                                          onSeek: (pos) => notifier.seek(
                                            duration.inMilliseconds > 0
                                                ? pos / duration.inMilliseconds
                                                : 0.0,
                                          ),
                                          onSeekBackward: () => notifier.seek(
                                            (position.inMilliseconds - 10000)
                                                    .clamp(
                                                      0,
                                                      duration.inMilliseconds,
                                                    ) /
                                                (duration.inMilliseconds > 0
                                                    ? duration.inMilliseconds
                                                    : 1),
                                          ),
                                          onSeekForward: () => notifier.seek(
                                            (position.inMilliseconds + 10000)
                                                    .clamp(
                                                      0,
                                                      duration.inMilliseconds,
                                                    ) /
                                                (duration.inMilliseconds > 0
                                                    ? duration.inMilliseconds
                                                    : 1),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: SlowverbTokens.spacingMd,
                                    ),
                                    // Right: Effects Column
                                    Expanded(
                                      flex: 3,
                                      child: SingleChildScrollView(
                                        child: _EffectColumn(
                                          selectedPresetId: selectedPresetId,
                                          parameters: parameters,
                                          onPresetSelected: (id) {
                                            final preset =
                                                Presets.getById(id) ??
                                                Presets.slowedReverb;
                                            notifier.applyPreset(preset);
                                          },
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
                                              projectName: projectName,
                                              position: position,
                                              duration: duration,
                                              isPlaying: isPlaying,
                                              isGeneratingPreview:
                                                  isGeneratingPreview,
                                              onPlayPause:
                                                  notifier.togglePlayback,
                                              onSeek: (pos) => notifier.seek(
                                                duration.inMilliseconds > 0
                                                    ? pos /
                                                          duration
                                                              .inMilliseconds
                                                    : 0.0,
                                              ),
                                              onSeekBackward: () => notifier.seek(
                                                (position.inMilliseconds -
                                                            10000)
                                                        .clamp(
                                                          0,
                                                          duration
                                                              .inMilliseconds,
                                                        ) /
                                                    (duration.inMilliseconds > 0
                                                        ? duration
                                                              .inMilliseconds
                                                        : 1),
                                              ),
                                              onSeekForward: () => notifier.seek(
                                                (position.inMilliseconds +
                                                            10000)
                                                        .clamp(
                                                          0,
                                                          duration
                                                              .inMilliseconds,
                                                        ) /
                                                    (duration.inMilliseconds > 0
                                                        ? duration
                                                              .inMilliseconds
                                                        : 1),
                                              ),
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
                                              selectedPresetId:
                                                  selectedPresetId,
                                              parameters: parameters,
                                              onPresetSelected: (id) {
                                                final preset =
                                                    Presets.getById(id) ??
                                                    Presets.slowedReverb;
                                                notifier.applyPreset(preset);
                                              },
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
                                              projectName: projectName,
                                              position: position,
                                              duration: duration,
                                              isPlaying: isPlaying,
                                              isGeneratingPreview:
                                                  isGeneratingPreview,
                                              onPlayPause:
                                                  notifier.togglePlayback,
                                              onSeek: (pos) => notifier.seek(
                                                duration.inMilliseconds > 0
                                                    ? pos /
                                                          duration
                                                              .inMilliseconds
                                                    : 0.0,
                                              ),
                                              onSeekBackward: () => notifier.seek(
                                                (position.inMilliseconds -
                                                            10000)
                                                        .clamp(
                                                          0,
                                                          duration
                                                              .inMilliseconds,
                                                        ) /
                                                    (duration.inMilliseconds > 0
                                                        ? duration
                                                              .inMilliseconds
                                                        : 1),
                                              ),
                                              onSeekForward: () => notifier.seek(
                                                (position.inMilliseconds +
                                                            10000)
                                                        .clamp(
                                                          0,
                                                          duration
                                                              .inMilliseconds,
                                                        ) /
                                                    (duration.inMilliseconds > 0
                                                        ? duration
                                                              .inMilliseconds
                                                        : 1),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          height: SlowverbTokens.spacingMd,
                                        ),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: _EffectColumn(
                                              selectedPresetId:
                                                  selectedPresetId,
                                              parameters: parameters,
                                              onPresetSelected: (id) {
                                                final preset =
                                                    Presets.getById(id) ??
                                                    Presets.slowedReverb;
                                                notifier.applyPreset(preset);
                                              },
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
                        notifier.stop();
                        context.go(AppRoutes.import_);
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
  final AudioEditorNotifier notifier; // Changed type
  final String projectId;
  final VoidCallback onBack;

  // Flattened state props
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isGeneratingPreview;
  final String selectedPresetId;
  final Map<String, double> parameters;

  const _MobileOverlayLayout({
    required this.projectName,
    required this.presetName,
    required this.notifier,
    required this.projectId,
    required this.onBack,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isGeneratingPreview,
    required this.selectedPresetId,
    required this.parameters,
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
                    context.push(AppRoutes.export, extra: widget.projectId),
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
            position: widget.position,
            duration: widget.duration,
            isPlaying: widget.isPlaying,
            onPlayPause: widget.notifier.togglePlayback,
            onSeek: (pos) => widget.notifier.seek(
              widget.duration.inMilliseconds > 0
                  ? pos / widget.duration.inMilliseconds
                  : 0.0,
            ),
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
              selectedPresetId: widget.selectedPresetId,
              parameters: widget.parameters,
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
                    color: SlowverbColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: SlowverbColors.textSecondary,
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
                      : SlowverbColors.textSecondary,
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
  final String selectedPresetId;
  final Map<String, double> parameters;
  final AudioEditorNotifier notifier;
  final VoidCallback onClose;

  const _MobileEffectsSheet({
    required this.selectedPresetId,
    required this.parameters,
    required this.notifier,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final presetId = selectedPresetId;
    // final preset = Presets.getById(presetId) ?? Presets.slowedReverb;

    return Container(
      height: 320,
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
                        if (selected) notifier.applyPreset(p);
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
              children: _kParameterDefinitions.map((param) {
                final value = parameters[param.id] ?? param.defaultValue;
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
                color: SlowverbColors.textSecondary,
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
  final String selectedPresetId;
  final Map<String, double> parameters;
  final ValueChanged<String> onPresetSelected;
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
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
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          // Minimize button moved to far right, but we need it somewhere.
                          // Actually, keeping it on the far right of the whole container is better.
                          // But we can put it here if the header is split.
                          // Let's put it in the Settings column header to align with "top right".
                        ],
                      ),
                      const SizedBox(height: SlowverbTokens.spacingSm),
                      // Vertical list of presets
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: Presets.all.map((preset) {
                          final isSelected = preset.id == selectedPresetId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => onPresetSelected(preset.id),
                              borderRadius: BorderRadius.circular(
                                SlowverbTokens.radiusSm,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
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
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: isSelected
                                            ? SlowverbColors.hotPink
                                            : SlowverbColors.textSecondary,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SlowverbTokens.spacingLg),
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
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          _ChromeButton(
                            icon: Icons.unfold_less,
                            onTap: onMinimize,
                          ),
                        ],
                      ),
                      const SizedBox(height: SlowverbTokens.spacingMd),
                      ..._kParameterDefinitions.map(
                        (param) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: SlowverbTokens.spacingMd,
                          ),
                          child: EffectSlider(
                            label: param.label,
                            value: parameters[param.id] ?? param.defaultValue,
                            min: param.min,
                            max: param.max,
                            unit: param.id == 'pitch' ? 'st' : '%',
                            formatValue: param.id == 'pitch'
                                ? (v) => v.toStringAsFixed(1)
                                : (v) => '${(v * 100).toInt()}%',
                            onChanged: (value) =>
                                onUpdateParam(param.id, value),
                          ),
                        ),
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
                    onSelected: (_) => onPresetSelected(preset.id),
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
              // All effect parameters
              ..._kParameterDefinitions.map(
                (param) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: SlowverbTokens.spacingMd,
                  ),
                  child: EffectSlider(
                    label: param.label,
                    value: parameters[param.id] ?? param.defaultValue,
                    min: param.min,
                    max: param.max,
                    unit: param.id == 'pitch' ? 'st' : '%',
                    formatValue: param.id == 'pitch'
                        ? (v) => v.toStringAsFixed(1)
                        : (v) => '${(v * 100).toInt()}%',
                    onChanged: (value) => onUpdateParam(param.id, value),
                  ),
                ),
              ),
            ],
          );
        },
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
      color: Colors.white.withValues(
        alpha: 0.2,
      ), // Fixed deprecated withOpacity
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
          color: Colors.white.withValues(alpha: 0.15), // Fixed withOpacity
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
        color: Colors.white.withValues(alpha: 0.15), // Fixed withOpacity
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
