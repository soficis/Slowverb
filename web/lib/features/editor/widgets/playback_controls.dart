import 'package:flutter/material.dart';
import 'package:slowverb_web/app/colors.dart';

class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final bool isProcessing;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onLoop;

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.isProcessing,
    required this.onPlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onLoop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onLoop,
          icon: const Icon(Icons.repeat),
          color: SlowverbColors.textSecondary,
          tooltip: 'Loop (Coming soon)',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSeekBackward,
          icon: const Icon(Icons.replay_10),
          color: Colors.white,
          iconSize: 28,
          tooltip: 'Rewind 10s',
        ),
        const SizedBox(width: 16),
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SlowverbColors.accentGradient,
            boxShadow: [
              BoxShadow(
                color: SlowverbColors.neonCyan,
                blurRadius: 12,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: isProcessing ? null : onPlayPause,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: isProcessing
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: onSeekForward,
          icon: const Icon(Icons.forward_10),
          color: Colors.white,
          iconSize: 28,
          tooltip: 'Skip 10s',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {}, // Shuffle placeholder
          icon: const Icon(Icons.shuffle),
          color: SlowverbColors.textSecondary,
          tooltip: 'Shuffle',
        ),
      ],
    );
  }
}
