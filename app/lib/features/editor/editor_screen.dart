import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb/app/colors.dart';
import 'package:slowverb/app/router.dart';
import 'package:slowverb/app/widgets/vaporwave_widgets.dart';
import 'package:slowverb/features/editor/editor_provider.dart';
import 'package:slowverb/features/editor/widgets/effect_slider.dart';
import 'package:slowverb/features/editor/widgets/playback_controls.dart';
import 'package:slowverb/features/editor/widgets/track_header.dart';

/// Main editor screen for adjusting audio effects
///
/// Provides playback controls and sliders for tempo, pitch, and reverb.
class EditorScreen extends ConsumerWidget {
  final String projectId;

  const EditorScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider);
    final project = state.currentProject;

    if (project == null) {
      return Scaffold(
        body: Stack(
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                gradient: SlowverbColors.vaporwaveSunset,
              ),
            ),
            const GridPattern(),
            const ScanLines(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: SlowverbColors.onSurfaceMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No project loaded',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go(RoutePaths.home),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: SlowverbColors.vaporwaveSunset,
            ),
          ),
          const GridPattern(),
          const ScanLines(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, ref),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrackHeader(
                          trackName: project.name,
                          artistName: project.sourceArtist ?? 'Unknown Artist',
                          presetName: _getPresetName(
                            state.selectedPresetId ?? project.presetId,
                          ),
                          duration: Duration(milliseconds: project.durationMs),
                        ),
                        const SizedBox(height: 32),
                        _buildProgressBar(context, ref, state),
                        const SizedBox(height: 24),
                        PlaybackControls(
                          isPlaying: state.isPlaying,
                          onPlayPause: () => ref
                              .read(editorProvider.notifier)
                              .togglePlayback(),
                          onSeekBackward: () =>
                              ref.read(editorProvider.notifier).seekBackward(),
                          onSeekForward: () =>
                              ref.read(editorProvider.notifier).seekForward(),
                          onLoop: () {}, // TODO: Implement loop
                        ),
                        const SizedBox(height: 40),
                        _buildEffectControls(context, ref, state),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(context, ref, project.id),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPresetName(String presetId) {
    switch (presetId) {
      case 'slowed_reverb':
        return 'Slowed + Reverb';
      case 'vaporwave_chill':
        return 'Vaporwave Chill';
      case 'nightcore':
        return 'Nightcore';
      case 'echo_slow':
        return 'Echo Slow';
      case 'manual':
        return 'Manual';
      default:
        return 'Custom';
    }
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              ref.read(editorProvider.notifier).stopPlayback();
              context.go(RoutePaths.home);
            },
            icon: const Icon(Icons.arrow_back),
          ),
          const Spacer(),
          Text('Editor', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton(
            onPressed: () =>
                ref.read(editorProvider.notifier).resetToDefaults(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    WidgetRef ref,
    EditorState state,
  ) {
    final position = state.position.inSeconds.toDouble();
    final duration = state.duration.inSeconds.toDouble();
    final maxDuration = duration > 0 ? duration : 1.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: SlowverbColors.hotPink,
            thumbColor: SlowverbColors.hotPink,
            trackHeight: 6,
          ),
          child: Slider(
            value: position.clamp(0, maxDuration),
            min: 0,
            max: maxDuration,
            onChanged: (value) {
              ref
                  .read(editorProvider.notifier)
                  .seekTo(Duration(seconds: value.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(state.position),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                _formatDuration(state.duration),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEffectControls(
    BuildContext context,
    WidgetRef ref,
    EditorState state,
  ) {
    final params = state.parameters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Effect Controls', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        EffectSlider(
          label: 'Tempo',
          value: params['tempo'] ?? 1.0,
          min: 0.5,
          max: 1.5,
          unit: 'x',
          formatValue: (v) => '${v.toStringAsFixed(2)}x',
          onChanged: (value) {
            ref.read(editorProvider.notifier).updateParameter('tempo', value);
          },
        ),
        const SizedBox(height: 20),
        EffectSlider(
          label: 'Pitch',
          value: params['pitch'] ?? 0.0,
          min: -6,
          max: 6,
          unit: 'semi',
          formatValue: (v) =>
              '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)} semi',
          onChanged: (value) {
            ref.read(editorProvider.notifier).updateParameter('pitch', value);
          },
        ),
        const SizedBox(height: 20),
        EffectSlider(
          label: 'Reverb',
          value: params['reverbAmount'] ?? 0.0,
          min: 0,
          max: 1,
          unit: '%',
          formatValue: (v) => '${(v * 100).toInt()}%',
          onChanged: (value) {
            ref
                .read(editorProvider.notifier)
                .updateParameter('reverbAmount', value);
          },
        ),
        const SizedBox(height: 20),
        EffectSlider(
          label: 'Wet/Dry Mix',
          value: params['wetDryMix'] ?? 0.0,
          min: 0,
          max: 1,
          unit: '%',
          formatValue: (v) => '${(v * 100).toInt()}%',
          onChanged: (value) {
            ref
                .read(editorProvider.notifier)
                .updateParameter('wetDryMix', value);
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    String projectId,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Export button only (full width)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(editorProvider.notifier).stopPlayback();
                context.go(RoutePaths.exportWithId(projectId));
              },
              icon: const Icon(Icons.download),
              label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SlowverbColors.hotPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
