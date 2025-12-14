import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/app/widgets/responsive_scaffold.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/project.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/features/editor/widgets/effect_controls.dart';
import 'package:slowverb_web/features/editor/widgets/transport_bar.dart';
import 'package:slowverb_web/features/editor/widgets/waveform_panel.dart';
import 'package:slowverb_web/features/presets/preset_selector_dialog.dart';
import 'package:slowverb_web/features/visualizer/visualizer_panel.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';
import 'package:slowverb_web/providers/audio_playback_provider.dart';

/// Main audio editor screen
class EditorScreen extends ConsumerStatefulWidget {
  final AudioFileData? fileData;
  final Project? project;

  const EditorScreen({super.key, this.fileData, this.project});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  // Visualizer state - randomly selected on track import (excluding WMP Retro)
  late VisualizerPreset _visualizerPreset;
  bool _isFullscreenVisualizer = false;

  @override
  void initState() {
    super.initState();

    // Randomly select a visualizer when importing a track (excludes WMP Retro)
    _visualizerPreset = VisualizerPresets.random();

    if (widget.fileData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(audioEditorProvider.notifier)
            .loadAudioFile(widget.fileData!, project: widget.project);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(audioEditorProvider);
    final editorNotifier = ref.read(audioEditorProvider.notifier);
    final playbackNotifier = ref.read(audioPlaybackProvider.notifier);
    final isPlaying = ref.watch(audioPlaybackProvider);
    final audioPlayer = ref.watch(audioPlayerProvider);
    final currentPosition = ref
        .watch(playbackPositionProvider)
        .maybeWhen(data: (pos) => pos, orElse: () => Duration.zero);
    final totalDuration =
        ref
            .watch(playbackDurationProvider)
            .maybeWhen(data: (dur) => dur, orElse: () => null) ??
        editorState.audioDuration ??
        const Duration(minutes: 3, seconds: 45);
    final waveformTotalMs = totalDuration.inMilliseconds <= 0
        ? 1
        : totalDuration.inMilliseconds;
    final waveformPosition = totalDuration.inMilliseconds <= 0
        ? 0.0
        : (currentPosition.inMilliseconds / waveformTotalMs).clamp(0.0, 1.0);
    final effectValues = _EffectValues(
      tempo: editorState.currentParameters['tempo'] ?? 1.0,
      pitch: editorState.currentParameters['pitch'] ?? 0.0,
      reverbAmount: editorState.currentParameters['reverbAmount'] ?? 0.0,
      echoAmount: editorState.currentParameters['echoAmount'] ?? 0.0,
      eqWarmth: editorState.currentParameters['eqWarmth'] ?? 0.5,
    );

    _showErrorIfNeeded(context, editorState, editorNotifier);

    return ResponsiveScaffold(
      background: VisualizerPanel(
        preset: _visualizerPreset,
        isPlaying: isPlaying,
        onDoubleTap: () =>
            setState(() => _isFullscreenVisualizer = !_isFullscreenVisualizer),
      ),
      child: _isFullscreenVisualizer
          ? _buildFullscreenVisualizerOverlay(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EditorTitleBar(
                  presetName: editorState.selectedPreset.name,
                  onBack: () => context.go('/'),
                  onOpenPresets: () =>
                      _openPresetDialog(context, editorState, editorNotifier),
                  onExport: () => context.push('/export'),
                  visualizerPreset: _visualizerPreset,
                  onVisualizerPresetChanged: (preset) =>
                      setState(() => _visualizerPreset = preset),
                  onToggleFullscreen: () =>
                      setState(() => _isFullscreenVisualizer = true),
                ),
                const SizedBox(height: SlowverbTokens.spacingLg),
                if (editorState.audioFileName != null) ...[
                  _FileInfoBanner(
                    fileName: editorState.audioFileName!,
                    metadata: editorState.metadata,
                    onChangeFile: () => context.go('/'),
                  ),
                  const SizedBox(height: SlowverbTokens.spacingLg),
                ],
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1100;
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: _buildContent(
                            isWide: isWide,
                            state: editorState,
                            effectValues: effectValues,
                            isPlaying: isPlaying,
                            waveformPosition: waveformPosition,
                            currentPosition: currentPosition,
                            totalDuration: totalDuration,
                            audioPlayer: audioPlayer,
                            editorNotifier: editorNotifier,
                            playbackNotifier: playbackNotifier,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFullscreenVisualizerOverlay(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Back to Home',
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _isFullscreenVisualizer = false),
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                  tooltip: 'Exit Fullscreen',
                ),
              ],
            ),
            const Spacer(),
            // Visualizer preset selector at bottom
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SlowverbTokens.spacingMd,
                vertical: SlowverbTokens.spacingSm,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
              ),
              child: Wrap(
                spacing: SlowverbTokens.spacingSm,
                children: VisualizerPresets.all.map((preset) {
                  final isSelected = preset.id == _visualizerPreset.id;
                  return ChoiceChip(
                    label: Text(preset.name),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _visualizerPreset = preset),
                    selectedColor: SlowverbColors.hotPink.withValues(
                      alpha: 0.3,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? SlowverbColors.hotPink
                          : Colors.white70,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required bool isWide,
    required AudioEditorState state,
    required _EffectValues effectValues,
    required bool isPlaying,
    required double waveformPosition,
    required Duration currentPosition,
    required Duration totalDuration,
    required AudioPlayer audioPlayer,
    required AudioEditorNotifier editorNotifier,
    required AudioPlaybackNotifier playbackNotifier,
  }) {
    final content = isWide
        ? _WideEditorLayout(
            waveformPosition: waveformPosition,
            currentPosition: currentPosition,
            totalDuration: totalDuration,
            isPlaying: isPlaying,
            isLoading: state.isLoading,
            effectValues: effectValues,
            selectedPreset: state.selectedPreset,
            onPlayPause: () =>
                _handlePlayPause(editorNotifier, playbackNotifier, audioPlayer),
            onPreview: () => _handlePreview(editorNotifier, playbackNotifier),
            onStop: () => _handleStop(editorNotifier, playbackNotifier),
            onSeek: (position) => _handleSeek(
              position,
              totalDuration,
              editorNotifier,
              playbackNotifier,
            ),
            onPresetSelected: editorNotifier.applyPreset,
            onTempoChanged: (value) =>
                editorNotifier.updateParameter('tempo', value),
            onPitchChanged: (value) =>
                editorNotifier.updateParameter('pitch', value),
            onReverbChanged: (value) =>
                editorNotifier.updateParameter('reverbAmount', value),
            onEchoChanged: (value) =>
                editorNotifier.updateParameter('echoAmount', value),
            onEqWarmthChanged: (value) =>
                editorNotifier.updateParameter('eqWarmth', value),
          )
        : _StackedEditorLayout(
            waveformPosition: waveformPosition,
            currentPosition: currentPosition,
            totalDuration: totalDuration,
            isPlaying: isPlaying,
            isLoading: state.isLoading,
            effectValues: effectValues,
            selectedPreset: state.selectedPreset,
            onPlayPause: () =>
                _handlePlayPause(editorNotifier, playbackNotifier, audioPlayer),
            onPreview: () => _handlePreview(editorNotifier, playbackNotifier),
            onStop: () => _handleStop(editorNotifier, playbackNotifier),
            onSeek: (position) => _handleSeek(
              position,
              totalDuration,
              editorNotifier,
              playbackNotifier,
            ),
            onPresetSelected: editorNotifier.applyPreset,
            onTempoChanged: (value) =>
                editorNotifier.updateParameter('tempo', value),
            onPitchChanged: (value) =>
                editorNotifier.updateParameter('pitch', value),
            onReverbChanged: (value) =>
                editorNotifier.updateParameter('reverbAmount', value),
            onEchoChanged: (value) =>
                editorNotifier.updateParameter('echoAmount', value),
            onEqWarmthChanged: (value) =>
                editorNotifier.updateParameter('eqWarmth', value),
          );

    return Stack(
      children: [content, if (state.isLoading) const _LoadingOverlay()],
    );
  }

  void _showErrorIfNeeded(
    BuildContext context,
    AudioEditorState state,
    AudioEditorNotifier editorNotifier,
  ) {
    if (state.error == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          backgroundColor: SlowverbColors.error,
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () => editorNotifier.clearError(),
          ),
        ),
      );
      editorNotifier.clearError();
    });
  }

  Future<void> _openPresetDialog(
    BuildContext context,
    AudioEditorState state,
    AudioEditorNotifier editorNotifier,
  ) async {
    final selectedPreset = await showDialog<EffectPreset>(
      context: context,
      builder: (context) =>
          PresetSelectorDialog(currentPreset: state.selectedPreset),
    );

    if (selectedPreset != null) {
      editorNotifier.applyPreset(selectedPreset);
    }
  }

  Future<void> _handlePlayPause(
    AudioEditorNotifier editorNotifier,
    AudioPlaybackNotifier playbackNotifier,
    AudioPlayer audioPlayer,
  ) async {
    if (audioPlayer.audioSource == null) {
      await _handlePreview(editorNotifier, playbackNotifier);
      return;
    }
    await playbackNotifier.togglePlayPause();
  }

  Future<void> _handlePreview(
    AudioEditorNotifier editorNotifier,
    AudioPlaybackNotifier playbackNotifier,
  ) async {
    final previewUri = await editorNotifier.generatePreview();
    if (previewUri != null && mounted) {
      await playbackNotifier.loadAndPlay(previewUri);
    }
  }

  Future<void> _handleStop(
    AudioEditorNotifier editorNotifier,
    AudioPlaybackNotifier playbackNotifier,
  ) async {
    await playbackNotifier.stop();
    editorNotifier.stop();
  }

  void _handleSeek(
    double position,
    Duration totalDuration,
    AudioEditorNotifier editorNotifier,
    AudioPlaybackNotifier playbackNotifier,
  ) {
    final clamped = position.clamp(0.0, 1.0);
    final target = Duration(
      milliseconds: (clamped * totalDuration.inMilliseconds).toInt(),
    );
    playbackNotifier.seek(target);
    editorNotifier.seek(clamped);
  }
}

class _EditorTitleBar extends StatelessWidget {
  final String presetName;
  final VoidCallback onBack;
  final VoidCallback onOpenPresets;
  final VoidCallback onExport;
  final VisualizerPreset? visualizerPreset;
  final ValueChanged<VisualizerPreset>? onVisualizerPresetChanged;
  final VoidCallback? onToggleFullscreen;

  const _EditorTitleBar({
    required this.presetName,
    required this.onBack,
    required this.onOpenPresets,
    required this.onExport,
    this.visualizerPreset,
    this.onVisualizerPresetChanged,
    this.onToggleFullscreen,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: SlowverbTokens.spacingSm),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
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
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: SlowverbTokens.spacingSm,
      runSpacing: SlowverbTokens.spacingSm,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Visualizer preset selector
        if (onVisualizerPresetChanged != null) ...[
          _VisualizerPresetDropdown(
            selectedPreset: visualizerPreset ?? VisualizerPresets.wmpRetro,
            onChanged: onVisualizerPresetChanged!,
          ),
          if (onToggleFullscreen != null)
            IconButton(
              onPressed: onToggleFullscreen,
              icon: const Icon(Icons.fullscreen, color: Colors.white70),
              tooltip: 'Fullscreen Visualizer',
              iconSize: 20,
            ),
          const SizedBox(width: SlowverbTokens.spacingSm),
        ],
        OutlinedButton.icon(
          onPressed: onOpenPresets,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70),
            padding: const EdgeInsets.symmetric(
              horizontal: SlowverbTokens.spacingMd,
              vertical: SlowverbTokens.spacingSm,
            ),
          ),
          icon: const Icon(Icons.tune),
          label: const Text('Preset Browser'),
        ),
        ElevatedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.download),
          label: const Text('Export'),
        ),
      ],
    );
  }
}

class _VisualizerPresetDropdown extends StatelessWidget {
  final VisualizerPreset selectedPreset;
  final ValueChanged<VisualizerPreset> onChanged;

  const _VisualizerPresetDropdown({
    required this.selectedPreset,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.memory, size: 16, color: SlowverbColors.neonCyan),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<VisualizerPreset>(
              value: selectedPreset,
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Colors.white70,
                size: 18,
              ),
              isDense: true,
              dropdownColor: SlowverbColors.surface,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: VisualizerPresets.all.map((preset) {
                return DropdownMenuItem<VisualizerPreset>(
                  value: preset,
                  child: Text(preset.name),
                );
              }).toList(),
              onChanged: (preset) {
                if (preset != null) onChanged(preset);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FileInfoBanner extends StatelessWidget {
  final String fileName;
  final AudioMetadata? metadata;
  final VoidCallback onChangeFile;

  const _FileInfoBanner({
    required this.fileName,
    required this.metadata,
    required this.onChangeFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
      decoration: BoxDecoration(
        color: SlowverbColors.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
        boxShadow: [SlowverbTokens.shadowCard],
        border: Border.all(color: SlowverbColors.accentPink.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.audio_file, color: SlowverbColors.accentPink),
          const SizedBox(width: SlowverbTokens.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metadata != null)
                  Text(
                    'Duration: ${metadata!.duration != null ? _formatDuration(metadata!.duration!) : 'Unknown'} · ${metadata!.sampleRate}Hz · ${metadata!.channels}ch',
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

class _WideEditorLayout extends StatelessWidget {
  final double waveformPosition;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlaying;
  final bool isLoading;
  final _EffectValues effectValues;
  final EffectPreset selectedPreset;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onPreview;
  final Future<void> Function() onStop;
  final ValueChanged<double> onSeek;
  final ValueChanged<EffectPreset> onPresetSelected;
  final ValueChanged<double> onTempoChanged;
  final ValueChanged<double> onPitchChanged;
  final ValueChanged<double> onReverbChanged;
  final ValueChanged<double> onEchoChanged;
  final ValueChanged<double> onEqWarmthChanged;

  const _WideEditorLayout({
    required this.waveformPosition,
    required this.currentPosition,
    required this.totalDuration,
    required this.isPlaying,
    this.isLoading = false,
    required this.effectValues,
    required this.selectedPreset,
    required this.onPlayPause,
    required this.onPreview,
    required this.onStop,
    required this.onSeek,
    required this.onPresetSelected,
    required this.onTempoChanged,
    required this.onPitchChanged,
    required this.onReverbChanged,
    required this.onEchoChanged,
    required this.onEqWarmthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _WaveformTransportCard(
            waveformPosition: waveformPosition,
            currentPosition: currentPosition,
            totalDuration: totalDuration,
            isPlaying: isPlaying,
            isLoading: isLoading,
            onPlayPause: onPlayPause,
            onPreview: onPreview,
            onStop: onStop,
            onSeek: onSeek,
          ),
        ),
        const SizedBox(width: SlowverbTokens.spacingLg),
        Expanded(
          flex: 2,
          child: _EffectColumn(
            effectValues: effectValues,
            selectedPreset: selectedPreset,
            onPresetSelected: onPresetSelected,
            onTempoChanged: onTempoChanged,
            onPitchChanged: onPitchChanged,
            onReverbChanged: onReverbChanged,
            onEchoChanged: onEchoChanged,
            onEqWarmthChanged: onEqWarmthChanged,
          ),
        ),
      ],
    );
  }
}

class _StackedEditorLayout extends StatelessWidget {
  final double waveformPosition;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlaying;
  final bool isLoading;
  final _EffectValues effectValues;
  final EffectPreset selectedPreset;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onPreview;
  final Future<void> Function() onStop;
  final ValueChanged<double> onSeek;
  final ValueChanged<EffectPreset> onPresetSelected;
  final ValueChanged<double> onTempoChanged;
  final ValueChanged<double> onPitchChanged;
  final ValueChanged<double> onReverbChanged;
  final ValueChanged<double> onEchoChanged;
  final ValueChanged<double> onEqWarmthChanged;

  const _StackedEditorLayout({
    required this.waveformPosition,
    required this.currentPosition,
    required this.totalDuration,
    required this.isPlaying,
    this.isLoading = false,
    required this.effectValues,
    required this.selectedPreset,
    required this.onPlayPause,
    required this.onPreview,
    required this.onStop,
    required this.onSeek,
    required this.onPresetSelected,
    required this.onTempoChanged,
    required this.onPitchChanged,
    required this.onReverbChanged,
    required this.onEchoChanged,
    required this.onEqWarmthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _WaveformTransportCard(
            waveformPosition: waveformPosition,
            currentPosition: currentPosition,
            totalDuration: totalDuration,
            isPlaying: isPlaying,
            isLoading: isLoading,
            onPlayPause: onPlayPause,
            onPreview: onPreview,
            onStop: onStop,
            onSeek: onSeek,
          ),
          const SizedBox(height: SlowverbTokens.spacingLg),
          _EffectColumn(
            effectValues: effectValues,
            selectedPreset: selectedPreset,
            onPresetSelected: onPresetSelected,
            onTempoChanged: onTempoChanged,
            onPitchChanged: onPitchChanged,
            onReverbChanged: onReverbChanged,
            onEchoChanged: onEchoChanged,
            onEqWarmthChanged: onEqWarmthChanged,
          ),
        ],
      ),
    );
  }
}

class _WaveformTransportCard extends StatelessWidget {
  final double waveformPosition;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlaying;
  final bool isLoading;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onPreview;
  final Future<void> Function() onStop;
  final ValueChanged<double> onSeek;

  const _WaveformTransportCard({
    required this.waveformPosition,
    required this.currentPosition,
    required this.totalDuration,
    required this.isPlaying,
    this.isLoading = false,
    required this.onPlayPause,
    required this.onPreview,
    required this.onStop,
    required this.onSeek,
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
        children: [
          SizedBox(
            height: 220,
            child: WaveformPanel(
              playbackPosition: waveformPosition,
              onSeek: onSeek,
            ),
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),
          TransportBar(
            isPlaying: isPlaying,
            isLoading: isLoading,
            currentTime: currentPosition,
            totalTime: totalDuration,
            onPlayPause: onPlayPause,
            onStop: onStop,
            onPreview: onPreview,
            onSeek: (position) => onSeek(
              position.inMilliseconds /
                  (totalDuration.inMilliseconds == 0
                      ? 1
                      : totalDuration.inMilliseconds),
            ),
          ),
        ],
      ),
    );
  }
}

class _EffectColumn extends StatelessWidget {
  final _EffectValues effectValues;
  final EffectPreset selectedPreset;
  final ValueChanged<EffectPreset> onPresetSelected;
  final ValueChanged<double> onTempoChanged;
  final ValueChanged<double> onPitchChanged;
  final ValueChanged<double> onReverbChanged;
  final ValueChanged<double> onEchoChanged;
  final ValueChanged<double> onEqWarmthChanged;

  const _EffectColumn({
    required this.effectValues,
    required this.selectedPreset,
    required this.onPresetSelected,
    required this.onTempoChanged,
    required this.onPitchChanged,
    required this.onReverbChanged,
    required this.onEchoChanged,
    required this.onEqWarmthChanged,
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
          _PresetQuickSwitch(
            selectedPreset: selectedPreset,
            onPresetSelected: onPresetSelected,
          ),
          const SizedBox(height: SlowverbTokens.spacingMd),
          EffectControls(
            tempo: effectValues.tempo,
            pitch: effectValues.pitch,
            reverbAmount: effectValues.reverbAmount,
            echoAmount: effectValues.echoAmount,
            eqWarmth: effectValues.eqWarmth,
            onTempoChanged: onTempoChanged,
            onPitchChanged: onPitchChanged,
            onReverbChanged: onReverbChanged,
            onEchoChanged: onEchoChanged,
            onEqWarmthChanged: onEqWarmthChanged,
          ),
        ],
      ),
    );
  }
}

class _PresetQuickSwitch extends StatelessWidget {
  final EffectPreset selectedPreset;
  final ValueChanged<EffectPreset> onPresetSelected;

  const _PresetQuickSwitch({
    required this.selectedPreset,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Presets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: SlowverbTokens.spacingSm),
        Wrap(
          spacing: SlowverbTokens.spacingSm,
          runSpacing: SlowverbTokens.spacingSm,
          children: Presets.all.map((preset) {
            final isSelected = preset.id == selectedPreset.id;
            return ChoiceChip(
              label: Text(preset.name),
              selected: isSelected,
              onSelected: (_) => onPresetSelected(preset),
              selectedColor: SlowverbColors.accentPink.withOpacity(0.2),
              backgroundColor: SlowverbColors.surfaceVariant,
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? SlowverbColors.accentPink
                    : SlowverbColors.textPrimary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
                side: BorderSide(
                  color: isSelected
                      ? SlowverbColors.accentPink
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

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.45)),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: SlowverbColors.accentPink),
              SizedBox(height: SlowverbTokens.spacingSm),
              Text('Processing audio...'),
            ],
          ),
        ),
      ),
    );
  }
}

// _EditorBackdrop removed - now using VisualizerPanel as background

class _EffectValues {
  final double tempo;
  final double pitch;
  final double reverbAmount;
  final double echoAmount;
  final double eqWarmth;

  const _EffectValues({
    required this.tempo,
    required this.pitch,
    required this.reverbAmount,
    required this.echoAmount,
    required this.eqWarmth,
  });
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
