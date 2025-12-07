import 'package:flutter/material.dart';
import 'package:slowverb/app/colors.dart';
import 'package:slowverb/app/widgets/vaporwave_widgets.dart';

/// Playback control buttons for the editor
class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onLoop;

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onLoop,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Loop button (secondary)
          IconButton(
            onPressed: onLoop,
            icon: const Icon(Icons.repeat),
            iconSize: 24,
            color: SlowverbColors.neonCyan.withOpacity(0.7),
          ),
          const SizedBox(width: 24),
          // Seek backward
          IconButton(
            onPressed: onSeekBackward,
            icon: const Icon(Icons.replay_10),
            iconSize: 32,
            color: SlowverbColors.neonCyan,
            style: IconButton.styleFrom(
              shadowColor: SlowverbColors.neonCyan,
              elevation: 4,
            ),
          ),
          const SizedBox(width: 24),
          // Play/Pause (Primary Neon)
          _buildPlayButton(),
          const SizedBox(width: 24),
          // Seek forward
          IconButton(
            onPressed: onSeekForward,
            icon: const Icon(Icons.forward_10),
            iconSize: 32,
            color: SlowverbColors.neonCyan,
            style: IconButton.styleFrom(
              shadowColor: SlowverbColors.neonCyan,
              elevation: 4,
            ),
          ),
          const SizedBox(width: 24),
          // Placeholder for balance (Loop match)
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.shuffle), // Or another icon
            iconSize: 24,
            color: Colors.transparent, // Invisible
            disabledColor: Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: onPlayPause,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SlowverbColors.vaporwaveSunset,
          boxShadow: [
            BoxShadow(
              color: SlowverbColors.hotPink.withOpacity(0.6),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: SlowverbColors.neonCyan.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 48,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}
