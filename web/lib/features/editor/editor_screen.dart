import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/router.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/app/widgets/responsive_scaffold.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/parameter_definitions.dart';
import 'package:slowverb_web/domain/entities/project.dart';
import 'package:slowverb_web/features/editor/layouts/mobile_editor_layout.dart';
import 'package:slowverb_web/features/editor/widgets/effect_slider.dart';
import 'package:slowverb_web/features/editor/widgets/playback_controls.dart';
import 'package:slowverb_web/features/editor/widgets/processing_indicator.dart';
import 'package:slowverb_web/features/visualizer/visualizer_controller.dart';
import 'package:slowverb_web/features/visualizer/visualizer_panel.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';
import 'package:slowverb_web/providers/audio_playback_provider.dart';
import 'package:slowverb_web/providers/preset_repository_provider.dart';
import 'package:slowverb_web/providers/settings_provider.dart';
import 'package:uuid/uuid.dart';
part 'editor_screen_mobile_widgets.dart';
part 'editor_screen_header_widgets.dart';
part 'editor_screen_effect_widgets.dart';
part 'editor_screen_chrome_widgets.dart';

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

    // Use playback duration (processed audio) when available, otherwise use original metadata duration
    final playbackDuration = ref.watch(playbackDurationProvider).value;
    final duration = playbackDuration ?? state.audioDuration ?? Duration.zero;
    // Calculate position from normalized playbackPosition
    final position = Duration(
      milliseconds: (state.playbackPosition * duration.inMilliseconds).toInt(),
    );

    final isPlaying = state.isPlaying;
    final isGeneratingPreview = state.isLoading; // Approximate
    final selectedPresetId = state.selectedPreset.id;
    final parameters = state.currentParameters;

    // Read mastering from persistent settings provider
    final masteringSettings = ref.watch(masteringSettingsProvider);
    final masteringEnabled = masteringSettings.masteringEnabled;

    // Track if preview was rendered with mastering
    final previewMasteringApplied = state.previewMasteringApplied;
    final hasGeneratedPreview = state.currentPreviewUri != null;

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
                    return MobileEditorLayout(
                      projectName: projectName,
                      presetName: presetName,
                      position: position,
                      duration: duration,
                      isPlaying: isPlaying,
                      isGeneratingPreview: isGeneratingPreview,
                      selectedPresetId: selectedPresetId,
                      parameters: parameters,
                      masteringEnabled: masteringEnabled,
                      previewMasteringApplied: previewMasteringApplied,

                      notifier: notifier,
                      projectId: projectId,
                      onBack: () {
                        notifier.stop();
                        context.go(AppRoutes.import_);
                      },
                    );
                  } // Desktop/tablet layout
                  return Padding(
                    padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Bar with Fullscreen Toggle
                        _EditorTitleBar(
                          presetName: presetName,
                          masteringEnabled: masteringEnabled,
                          previewMasteringApplied: previewMasteringApplied,
                          isLoading: isGeneratingPreview,
                          onBack: () {
                            notifier.stop();
                            context.go(AppRoutes.import_);
                          },
                          onExport: () =>
                              context.push(AppRoutes.export, extra: projectId),
                          onFullscreen: () {
                            setState(() => _isFullscreenVisualizer = true);
                          },
                          onForceStop: notifier.forceStop,
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
                                          masteringEnabled: masteringEnabled,
                                          previewMasteringApplied:
                                              previewMasteringApplied,
                                          hasGeneratedPreview:
                                              hasGeneratedPreview,
                                          onPlayPause: notifier.togglePlayback,
                                          onRegenerate: (resumeAt) =>
                                              notifier.regenerate(
                                                resumeAtPosition: resumeAt,
                                              ),
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
                                          onPresetSelected: (preset) {
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
                                              masteringEnabled:
                                                  masteringEnabled,
                                              previewMasteringApplied:
                                                  previewMasteringApplied,
                                              hasGeneratedPreview:
                                                  hasGeneratedPreview,
                                              onPlayPause:
                                                  notifier.togglePlayback,
                                              onRegenerate: (resumeAt) =>
                                                  notifier.regenerate(
                                                    resumeAtPosition: resumeAt,
                                                  ),
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
                                              onPresetSelected: (preset) {
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
                                              masteringEnabled:
                                                  masteringEnabled,
                                              previewMasteringApplied:
                                                  previewMasteringApplied,
                                              hasGeneratedPreview:
                                                  hasGeneratedPreview,
                                              onPlayPause:
                                                  notifier.togglePlayback,
                                              onRegenerate: (resumeAt) =>
                                                  notifier.regenerate(
                                                    resumeAtPosition: resumeAt,
                                                  ),
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
                                              onPresetSelected: (preset) {
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

