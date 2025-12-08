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
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/features/editor/widgets/waveform_panel.dart';
import 'package:slowverb_web/features/editor/widgets/transport_bar.dart';
import 'package:slowverb_web/features/editor/widgets/effect_controls.dart';
import 'package:slowverb_web/features/presets/preset_selector_dialog.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';
import 'package:slowverb_web/providers/audio_playback_provider.dart';

/// Main audio editor screen
class EditorScreen extends ConsumerStatefulWidget {
  final AudioFileData? fileData;

  const EditorScreen({super.key, this.fileData});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  @override
  void initState() {
    super.initState();

    // Load audio file on mount
    if (widget.fileData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(audioEditorProvider.notifier).loadAudioFile(widget.fileData!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(audioEditorProvider);
    final editorNotifier = ref.read(audioEditorProvider.notifier);
    final playbackNotifier = ref.read(audioPlaybackProvider.notifier);
    final isPlaying = ref.watch(audioPlaybackProvider);
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
    final audioPlayer = ref.watch(audioPlayerProvider);

    // Show error snackbar if there's an error
    if (editorState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(editorState.error!),
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

    return Scaffold(
      backgroundColor: SlowverbColors.backgroundDark,
      appBar: AppBar(
        title: const Text('SLOWVERB'),
        actions: [
          // Preset selector
          TextButton.icon(
            onPressed: () async {
              final selectedPreset = await showDialog(
                context: context,
                builder: (context) => PresetSelectorDialog(
                  currentPreset: editorState.selectedPreset,
                ),
              );

              if (selectedPreset != null) {
                editorNotifier.applyPreset(selectedPreset);
              }
            },
            icon: const Icon(Icons.tune),
            label: Text(editorState.selectedPreset.name.toUpperCase()),
          ),
          const SizedBox(width: 8),

          // Export button
          ElevatedButton.icon(
            onPressed: () {
              context.push('/export');
            },
            icon: const Icon(Icons.download),
            label: const Text('EXPORT'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: editorState.isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: SlowverbColors.primaryPurple,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Processing audio...',
                      style: TextStyle(color: SlowverbColors.textSecondary),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  const SizedBox(height: 16),

                  // File info banner
                  if (editorState.audioFileName != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SlowverbColors.surface.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.audio_file,
                            color: SlowverbColors.accentPink,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  editorState.audioFileName!,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (editorState.metadata != null)
                                  Text(
                                    'Duration: ${_formatDuration(editorState.metadata!.duration)} • ${editorState.metadata!.sampleRate}Hz • ${editorState.metadata!.channels}ch',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              context.go('/');
                            },
                            icon: const Icon(Icons.close),
                            tooltip: 'Change file',
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Waveform panel
                  Expanded(
                    flex: 2,
                    child: WaveformPanel(
                      playbackPosition: waveformPosition,
                      onSeek: (position) {
                        final target = Duration(
                          milliseconds: (position * waveformTotalMs).toInt(),
                        );
                        playbackNotifier.seek(target);
                        editorNotifier.seek(position);
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Transport bar
                  TransportBar(
                    isPlaying: isPlaying,
                    currentTime: currentPosition,
                    totalTime: totalDuration,
                    onPlayPause: () async {
                      if (audioPlayer.audioSource == null) {
                        final previewUri = await editorNotifier
                            .generatePreview();
                        if (previewUri != null && mounted) {
                          await playbackNotifier.loadAndPlay(previewUri);
                        }
                        return;
                      }
                      await playbackNotifier.togglePlayPause();
                    },
                    onStop: () async {
                      await playbackNotifier.stop();
                    },
                    onPreview: () async {
                      final previewUri = await editorNotifier.generatePreview();
                      if (previewUri != null && mounted) {
                        await playbackNotifier.loadAndPlay(previewUri);
                      }
                    },
                    onSeek: (position) async {
                      await playbackNotifier.seek(position);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Effect controls
                  Expanded(
                    flex: 3,
                    child: EffectControls(
                      tempo: editorState.currentParameters['tempo'] ?? 1.0,
                      pitch: editorState.currentParameters['pitch'] ?? 0.0,
                      reverbAmount:
                          editorState.currentParameters['reverbAmount'] ?? 0.0,
                      echoAmount:
                          editorState.currentParameters['echoAmount'] ?? 0.0,
                      eqWarmth:
                          editorState.currentParameters['eqWarmth'] ?? 0.5,
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
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
