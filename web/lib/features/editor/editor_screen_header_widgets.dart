part of 'editor_screen.dart';

class _EditorTitleBar extends StatelessWidget {
  final String presetName;
  final bool masteringEnabled;
  final bool previewMasteringApplied;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onExport;
  final VoidCallback onFullscreen;
  final VoidCallback onForceStop;

  const _EditorTitleBar({
    required this.presetName,
    required this.masteringEnabled,
    required this.previewMasteringApplied,
    this.isLoading = false,
    required this.onBack,
    required this.onExport,
    required this.onFullscreen,
    required this.onForceStop,
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
          // Left: Back button
          _ChromeButton(icon: Icons.arrow_back, onTap: onBack),
          const SizedBox(width: SlowverbTokens.spacingSm),

          // Left: Fullscreen button (prominent position)
          _ChromeButton(icon: Icons.fullscreen, onTap: onFullscreen),
          const SizedBox(width: SlowverbTokens.spacingMd),

          // Left: Compact visualizer selector
          const _VisualizerSelector(),

          // Center: Slowverb title with Roboto font
          Expanded(
            child: Center(
              child: Text(
                'Slowverb',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: isNarrow ? 20 : 28,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right: Preset badge (if not narrow)
          if (!isNarrow) ...[
            _PresetBadge(presetName: presetName),
            const SizedBox(width: SlowverbTokens.spacingMd),
          ],

          // Show mastering indicator only if preview was rendered with mastering
          if (previewMasteringApplied) ...[
            Icon(
              Icons.auto_awesome,
              // Gray out if mastering was applied but is now disabled
              color: masteringEnabled
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.3),
              size: 18,
            ),
            if (!isNarrow) ...[
              const SizedBox(width: 6),
              Text(
                'Mastering On',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  // Gray out if mastering was applied but is now disabled
                  color: masteringEnabled
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
            const SizedBox(width: SlowverbTokens.spacingSm),
          ],

          // Right: Force Stop button (visible only when loading)
          if (isLoading) ...[
            // Processing progress indicator with time estimate
            const ProcessingIndicator(),
            const SizedBox(width: SlowverbTokens.spacingSm),
            ElevatedButton.icon(
              onPressed: onForceStop,
              icon: const Icon(Icons.stop_circle, size: 20),
              label: const Text('FORCE STOP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                side: BorderSide(color: Colors.red.shade400, width: 2),
                elevation: 4,
              ),
            ),
            const SizedBox(width: SlowverbTokens.spacingSm),
          ],

          // Right: Export button
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
  final bool masteringEnabled;
  final bool previewMasteringApplied;
  final bool hasGeneratedPreview;
  final VoidCallback onPlayPause;
  final void Function(bool resumeAtPosition) onRegenerate;
  final ValueChanged<int> onSeek;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;

  const _WaveformTransportCard({
    required this.projectName,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isGeneratingPreview,
    required this.masteringEnabled,
    required this.previewMasteringApplied,
    required this.hasGeneratedPreview,
    required this.onPlayPause,
    required this.onRegenerate,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  projectName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              // Show mastering indicator only if preview was rendered with mastering
              if (previewMasteringApplied)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    // Gray out background if mastering was applied but is now disabled
                    color: masteringEnabled
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(
                      SlowverbTokens.radiusPill,
                    ),
                    border: Border.all(
                      color: masteringEnabled
                          ? Colors.white24
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        // Gray out if mastering was applied but is now disabled
                        color: masteringEnabled
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Mastering On',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          // Gray out if mastering was applied but is now disabled
                          color: masteringEnabled
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlaybackControls(
                    isPlaying: isPlaying,
                    onPlayPause: onPlayPause,
                    onSeekBackward: onSeekBackward,
                    onSeekForward: onSeekForward,
                    onLoop: () {},
                    isProcessing: isGeneratingPreview,
                  ),
                  if (hasGeneratedPreview) ...[
                    const SizedBox(width: 16),
                    _RegenerateButton(
                      onRegenerate: onRegenerate,
                      isProcessing: isGeneratingPreview,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Button to regenerate the audio preview with current settings.
/// Only visible after initial preview has been generated.
/// Includes a checkbox to resume playback at previous position.
class _RegenerateButton extends StatefulWidget {
  final void Function(bool resumeAtPosition) onRegenerate;
  final bool isProcessing;

  const _RegenerateButton({
    required this.onRegenerate,
    required this.isProcessing,
  });

  @override
  State<_RegenerateButton> createState() => _RegenerateButtonState();
}

class _RegenerateButtonState extends State<_RegenerateButton> {
  bool _resumeAtPosition = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: 'Regenerate with current settings',
          child: ElevatedButton.icon(
            onPressed: widget.isProcessing
                ? null
                : () => widget.onRegenerate(_resumeAtPosition),
            style: ElevatedButton.styleFrom(
              backgroundColor: SlowverbColors.neonCyan.withValues(alpha: 0.2),
              foregroundColor: SlowverbColors.neonCyan,
              padding: const EdgeInsets.symmetric(
                horizontal: SlowverbTokens.spacingMd,
                vertical: SlowverbTokens.spacingSm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SlowverbTokens.radiusPill),
                side: BorderSide(
                  color: SlowverbColors.neonCyan.withValues(alpha: 0.5),
                ),
              ),
            ),
            icon: widget.isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SlowverbColors.neonCyan,
                    ),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(widget.isProcessing ? 'Generating...' : 'Regenerate'),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: _resumeAtPosition,
                onChanged: widget.isProcessing
                    ? null
                    : (value) {
                        setState(() => _resumeAtPosition = value ?? false);
                      },
                activeColor: SlowverbColors.neonCyan,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Resume at position',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SlowverbColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
