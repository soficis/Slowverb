import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/router.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/parameter_definitions.dart';
import 'package:slowverb_web/domain/entities/project.dart';
import 'package:slowverb_web/features/editor/widgets/effect_slider.dart';
import 'package:slowverb_web/features/editor/widgets/processing_indicator.dart';
import 'package:slowverb_web/features/visualizer/visualizer_controller.dart';
import 'package:slowverb_web/features/visualizer/visualizer_panel.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';
import 'package:slowverb_web/providers/audio_playback_provider.dart';
import 'package:slowverb_web/providers/preset_repository_provider.dart';
import 'package:slowverb_web/providers/settings_provider.dart';
import 'package:uuid/uuid.dart';

part 'editor_screen_deck.dart';
part 'editor_screen_sound.dart';
part 'editor_screen_helpers.dart';

/// The editor: a visualizer "desktop" with two windows on it — the Deck
/// (transport + VFD readouts) and Sound (presets and effects). Wide screens
/// place them side by side; narrow screens stack them in one scroll.
class EditorScreen extends ConsumerStatefulWidget {
  final AudioFileData? fileData;
  final Project? project;

  const EditorScreen({super.key, this.fileData, this.project});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

/// Tracks at least this long get a memory/time warning when loaded.
/// See KNOWN_LIMITS.md.
const _longTrackWarning = Duration(minutes: 10);

/// Files at least this big get the same warning, for when the probe reports
/// no duration (seen with very long lossless files). ~10 min of 16-bit WAV.
const _largeFileWarningBytes = 100 * 1024 * 1024;

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _deckCollapsed = false;
  bool _soundCollapsed = false;
  bool _fullscreenVisualizer = false;
  bool _longTrackWarned = false;

  void _showLongTrackWarning(String what) {
    if (_longTrackWarned || !mounted) return;
    _longTrackWarned = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(
          '$what. Rendering it takes a lot of memory and may fail on phones; '
          'mastering can take a long time or run out of memory. Export in a '
          'desktop browser, or turn mastering off, if it does.',
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.fileData != null) {
        final bytes = widget.fileData!.bytes.length;
        if (bytes >= _largeFileWarningBytes) {
          _showLongTrackWarning(
            'Large file (${(bytes / (1024 * 1024)).round()} MB)',
          );
        }
        ref
            .read(audioEditorProvider.notifier)
            .loadAudioFile(widget.fileData!, project: widget.project);
      }
    });
  }

  void _goHome() {
    ref.read(audioEditorProvider.notifier).stop();
    context.go(AppRoutes.import_);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioEditorProvider);
    final notifier = ref.read(audioEditorProvider.notifier);

    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        notifier.clearError();
      });
    }

    ref.listen(audioEditorProvider.select((s) => s.isPlaying), (_, isPlaying) {
      ref.read(visualizerProvider.notifier).setPlaying(isPlaying);
    });

    // Long tracks are decoded to 32-bit float several times over while
    // rendering (~210 MB per copy for 10 min of stereo), which can exhaust a
    // phone's browser memory. Warn once per loaded track.
    ref.listen(audioEditorProvider.select((s) => s.audioDuration), (
      prev,
      next,
    ) {
      if (next == null || next == prev || next < _longTrackWarning) return;
      _showLongTrackWarning('Long track (${next.inMinutes} min)');
    });

    final hasProject = state.fileId != null || state.audioFileName != null;
    if (!hasProject && !state.isLoading) {
      return Scaffold(
        body: RetroDesktop(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: RetroWindow(
                title: 'No track loaded',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open a song from the start screen to begin.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: SlowverbTokens.spacingMd),
                    HwKey(
                      onPressed: () => context.go(AppRoutes.import_),
                      label: 'Go to start',
                      style: HwKeyStyle.primary,
                      isDefault: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final projectId = state.projectId ?? 'temp';
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): () {
            if (!state.isLoading) notifier.togglePlayback();
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_fullscreenVisualizer) {
              setState(() => _fullscreenVisualizer = false);
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: RetroDesktop(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final vis = ref.watch(visualizerProvider);
                      final panel = VisualizerPanel(
                        preset: vis.activePreset,
                        // Reduced motion: keep the scene still.
                        isPlaying: vis.isPlaying && !reduceMotion,
                        analysisStream: null,
                        isFullscreen: true,
                      );
                      return _fullscreenVisualizer
                          ? VisualizerScrim(strength: 0.9, child: panel)
                          : VisualizerScrim(child: panel);
                    },
                  ),
                ),
                SafeArea(
                  child: _fullscreenVisualizer
                      ? _FullscreenOverlay(
                          onExit: () =>
                              setState(() => _fullscreenVisualizer = false),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _EditorMenuBar(
                              isLoading: state.isLoading,
                              onBack: _goHome,
                              onExport: () => context.push(
                                AppRoutes.export,
                                extra: projectId,
                              ),
                              onFullscreen: () =>
                                  setState(() => _fullscreenVisualizer = true),
                              onForceStop: notifier.forceStop,
                            ),
                            Expanded(child: _buildWindows(context)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWindows(BuildContext context) {
    final deck = _DeckWindow(
      collapsed: _deckCollapsed,
      onCollapse: () => setState(() => _deckCollapsed = !_deckCollapsed),
    );
    final sound = _SoundWindow(
      collapsed: _soundCollapsed,
      onCollapse: () => setState(() => _soundCollapsed = !_soundCollapsed),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 600
            ? SlowverbTokens.spacingSm
            : SlowverbTokens.spacingLg;
        if (constraints.maxWidth >= 900) {
          return Padding(
            padding: EdgeInsets.all(pad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: SingleChildScrollView(child: deck)),
                SizedBox(width: pad),
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 4, right: 4),
                    child: sound,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.all(pad),
          children: [
            deck,
            SizedBox(height: pad),
            sound,
          ],
        );
      },
    );
  }
}

class _FullscreenOverlay extends StatelessWidget {
  final VoidCallback onExit;
  const _FullscreenOverlay({required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
        child: HwKey(
          onPressed: onExit,
          icon: Icons.fullscreen_exit,
          label: 'Exit (Esc)',
        ),
      ),
    );
  }
}
