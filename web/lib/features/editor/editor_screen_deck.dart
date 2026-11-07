part of 'editor_screen.dart';

/// Top menu bar: back, wordmark, Visualizer menu, status, Export.
class _EditorMenuBar extends ConsumerWidget {
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onExport;
  final VoidCallback onFullscreen;
  final VoidCallback onForceStop;

  const _EditorMenuBar({
    required this.isLoading,
    required this.onBack,
    required this.onExport,
    required this.onFullscreen,
    required this.onForceStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final vis = ref.watch(visualizerProvider);
    final active = vis.activePreset;
    Widget check(bool on) => SizedBox(
      width: 18,
      child: on
          ? const Icon(Icons.check, size: 16, color: SlowverbTokens.vfdCyan)
          : null,
    );

    return RetroMenuBar(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HwKey(
            onPressed: onBack,
            icon: Icons.arrow_back,
            tooltip: 'Back to start',
            size: 32,
          ),
          const SizedBox(width: 12),
          if (!narrow) ...[
            const SlowverbWordmark(size: 16),
            const SizedBox(width: 12),
          ],
        ],
      ),
      menus: [
        RetroMenu(
          title: narrow ? '' : 'Visualizer',
          icon: Icons.auto_awesome,
          items: [
            MenuItemButton(
              leadingIcon: const Icon(Icons.fullscreen, size: 18),
              onPressed: onFullscreen,
              child: const Text('Full screen'),
            ),
            const Divider(height: 1),
            MenuItemButton(
              leadingIcon: check(vis.shuffle),
              trailingIcon: const Icon(Icons.shuffle, size: 16),
              onPressed: () =>
                  ref.read(visualizerProvider.notifier).selectShuffle(),
              child: const Text('Shuffle'),
            ),
            const Divider(height: 1),
            for (final preset in VisualizerController.presets)
              MenuItemButton(
                // With shuffle on, the current scene is shown but not ticked.
                leadingIcon: check(!vis.shuffle && preset.id == active.id),
                onPressed: () => ref
                    .read(visualizerProvider.notifier)
                    .selectPreset(preset.id),
                child: Text(preset.name),
              ),
          ],
        ),
      ],
      trailing: [
        if (isLoading) ...[
          const ProcessingIndicator(),
          const SizedBox(width: 8),
          HwKey(
            onPressed: onForceStop,
            icon: Icons.stop,
            label: narrow ? null : 'Stop',
            tooltip: 'Force stop rendering',
            style: HwKeyStyle.danger,
            size: narrow ? 32 : null,
          ),
          const SizedBox(width: 8),
        ],
        HwKey(
          onPressed: onExport,
          icon: Icons.download,
          label: narrow ? null : 'Export',
          tooltip: 'Export the full song',
          style: HwKeyStyle.primary,
          isDefault: !narrow,
          size: narrow ? 32 : null,
        ),
      ],
    );
  }
}

/// The Deck: VFD readouts, seek bar and transport keys.
class _DeckWindow extends ConsumerWidget {
  final bool collapsed;
  final VoidCallback onCollapse;

  const _DeckWindow({required this.collapsed, required this.onCollapse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioEditorProvider);
    final notifier = ref.read(audioEditorProvider.notifier);
    final mastering = ref.watch(masteringSettingsProvider);

    final playbackDuration = ref.watch(playbackDurationProvider).value;
    final duration = playbackDuration ?? state.audioDuration ?? Duration.zero;
    final totalMs = duration.inMilliseconds;
    final position = Duration(
      milliseconds: (state.playbackPosition * totalMs).toInt(),
    );
    final title = state.projectName ?? state.audioFileName ?? 'Untitled';
    final params = state.currentParameters;
    final tempo = params['tempo'] ?? 1.0;
    final pitch = params['pitch'] ?? 0.0;
    final hasPreview = state.currentPreviewUri != null;
    final busy = state.isLoading;

    void seekBy(int deltaMs) {
      if (totalMs <= 0) return;
      final target = (position.inMilliseconds + deltaMs).clamp(0, totalMs);
      notifier.seek(target / totalMs);
    }

    return RetroWindow(
      title: 'Deck',
      collapsed: collapsed,
      onCollapse: onCollapse,
      child: Faceplate(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VfdPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            VfdText(title, size: 17),
                            const SizedBox(height: 2),
                            VfdText(
                              state.selectedPreset.name,
                              size: 13,
                              color: SlowverbTokens.sunsetPink,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SegmentReadout(
                        _formatDuration(position),
                        size: 30,
                        semanticsLabel:
                            'Position ${_formatDuration(position)} of '
                            '${_formatDuration(duration)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MiniReadout(
                        label: 'TEMPO',
                        value: '${(tempo * 100).round()}',
                        unit: '%',
                      ),
                      _MiniReadout(
                        label: 'PITCH',
                        value: pitch.toStringAsFixed(1),
                        unit: 'ST',
                      ),
                      Annunciator('PREVIEW', lit: hasPreview),
                      Annunciator('MASTER', lit: mastering.masteringEnabled),
                      Annunciator(
                        busy ? 'RENDERING' : 'CHANGED',
                        lit: busy || (hasPreview && state.isPreviewDirty),
                        color: SlowverbTokens.vfdAmber,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Seek',
              child: Slider(
                value: totalMs > 0 ? state.playbackPosition.clamp(0.0, 1.0) : 0,
                onChanged: totalMs > 0 ? notifier.seek : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PlateLabel(_formatDuration(position)),
                  PlateLabel(_formatDuration(duration)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              spacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HwKey(
                      onPressed: () => seekBy(-seekStepMs),
                      icon: Icons.replay_10,
                      tooltip: 'Back 10 seconds',
                      size: 44,
                    ),
                    const SizedBox(width: 8),
                    HwKey(
                      onPressed: notifier.togglePlayback,
                      icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
                      tooltip: state.isPlaying
                          ? 'Pause (Space)'
                          : 'Play (Space)',
                      style: HwKeyStyle.primary,
                      loading: busy,
                      size: 56,
                    ),
                    const SizedBox(width: 8),
                    HwKey(
                      onPressed: () => seekBy(seekStepMs),
                      icon: Icons.forward_10,
                      tooltip: 'Forward 10 seconds',
                      size: 44,
                    ),
                  ],
                ),
                if (hasPreview) _RegenerateControl(busy: busy),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniReadout extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _MiniReadout({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Annunciator(label, lit: true, color: SlowverbTokens.textHint),
        const SizedBox(width: 6),
        SegmentReadout(value, size: 15, semanticsLabel: '$label $value $unit'),
        const SizedBox(width: 3),
        Annunciator(unit, lit: true),
      ],
    );
  }
}

/// Re-render the preview with the current settings; lit when settings have
/// changed since the last render.
class _RegenerateControl extends ConsumerStatefulWidget {
  final bool busy;
  const _RegenerateControl({required this.busy});

  @override
  ConsumerState<_RegenerateControl> createState() => _RegenerateControlState();
}

class _RegenerateControlState extends ConsumerState<_RegenerateControl> {
  bool _resumeAtPosition = true;

  @override
  Widget build(BuildContext context) {
    final dirty = ref.watch(
      audioEditorProvider.select((s) => s.isPreviewDirty),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _resumeAtPosition,
                onChanged: widget.busy
                    ? null
                    : (v) => setState(() => _resumeAtPosition = v ?? false),
                semanticLabel: 'Keep playback position when re-rendering',
              ),
            ),
            const SizedBox(width: 4),
            const ExcludeSemantics(child: PlateLabel('Keep position')),
          ],
        ),
        const SizedBox(width: 10),
        HwKey(
          onPressed: widget.busy
              ? null
              : () => ref
                    .read(audioEditorProvider.notifier)
                    .regenerate(resumeAtPosition: _resumeAtPosition),
          icon: Icons.refresh,
          label: 'Re-render',
          tooltip: 'Render the preview again with the current settings',
          lit: dirty,
        ),
      ],
    );
  }
}
