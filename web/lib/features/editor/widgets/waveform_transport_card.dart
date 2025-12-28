import 'package:flutter/material.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/features/editor/widgets/playback_controls.dart';
import 'package:slowverb_web/features/editor/widgets/regenerate_button.dart';

/// Waveform and transport controls card for desktop/tablet layouts.
///
/// Contains project name, position slider, playback controls, and
/// regenerate button. Displays mastering indicator when enabled.
class WaveformTransportCard extends StatelessWidget {
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

  const WaveformTransportCard({
    super.key,
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
          _buildTitleRow(context),
          const SizedBox(height: SlowverbTokens.spacingMd),
          _buildProgressSlider(progress, totalMs),
          _buildTimeLabels(context),
          const SizedBox(height: SlowverbTokens.spacingSm),
          _buildPlaybackControls(),
        ],
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            projectName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (previewMasteringApplied)
          _MasteringIndicatorBadge(masteringEnabled: masteringEnabled),
      ],
    );
  }

  Widget _buildProgressSlider(double progress, int totalMs) {
    return Slider(
      value: progress.clamp(0.0, 1.0),
      onChanged: (value) => onSeek((value * totalMs).toInt()),
    );
  }

  Widget _buildTimeLabels(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SlowverbTokens.spacingSm),
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
    );
  }

  Widget _buildPlaybackControls() {
    return SingleChildScrollView(
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
              RegenerateButton(
                onRegenerate: onRegenerate,
                isProcessing: isGeneratingPreview,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Mastering indicator badge displayed in transport card title.
class _MasteringIndicatorBadge extends StatelessWidget {
  final bool masteringEnabled;

  const _MasteringIndicatorBadge({required this.masteringEnabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: masteringEnabled
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusPill),
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
            color: masteringEnabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 6),
          Text(
            'Mastering On',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: masteringEnabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
