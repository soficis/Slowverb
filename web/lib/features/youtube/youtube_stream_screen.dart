import 'dart:async';
import 'dart:math' show sin;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/engine/youtube_player_interop.dart';
import 'package:web/web.dart' as web;

/// YouTube streaming screen with embedded player and visualizer sync
/// Note: Audio effects cannot be applied due to CORS/DRM restrictions
class YouTubeStreamScreen extends StatefulWidget {
  const YouTubeStreamScreen({super.key});

  @override
  State<YouTubeStreamScreen> createState() => _YouTubeStreamScreenState();
}

class _YouTubeStreamScreenState extends State<YouTubeStreamScreen> {
  final _urlController = TextEditingController();
  String? _videoId;
  String? _error;
  bool _isLoading = false;
  bool _playerReady = false;
  double _currentTime = 0;
  double _duration = 0;
  bool _isPlaying = false;
  StreamSubscription? _timeSubscription;

  @override
  void initState() {
    super.initState();
    YouTubePlayerInterop.initialize();

    _timeSubscription = YouTubePlayerInterop.timeUpdates.listen((update) {
      if (mounted) {
        setState(() {
          _currentTime = update.currentTime;
          _duration = update.duration;
          _isPlaying = update.isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    _timeSubscription?.cancel();
    YouTubePlayerInterop.destroy();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Stream'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          // Experimental badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SlowverbColors.neonCyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: SlowverbColors.neonCyan, width: 1),
            ),
            child: const Text(
              'EXPERIMENTAL',
              style: TextStyle(
                color: SlowverbColors.neonCyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // Warning banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withOpacity(0.15),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Visualizer only mode. Audio effects cannot be applied to YouTube streams.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // URL input section
            if (!_playerReady) ...[
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_outline,
                          size: 64,
                          color: SlowverbColors.neonCyan,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Stream from YouTube',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter a YouTube URL to watch with synced visualizers',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'YouTube URL',
                            hintText: 'https://www.youtube.com/watch?v=...',
                            prefixIcon: Icon(Icons.link),
                          ),
                          onSubmitted: (_) => _loadVideo(),
                        ),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _loadVideo,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: Text(
                              _isLoading ? 'Loading...' : 'Load Video',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Player section
              Expanded(
                child: Column(
                  children: [
                    // YouTube player container
                    Expanded(
                      flex: 3,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(
                            SlowverbTokens.radiusMd,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: SlowverbColors.neonCyan.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            SlowverbTokens.radiusMd,
                          ),
                          child: HtmlElementView(
                            viewType: 'youtube-player-$_videoId',
                            onPlatformViewCreated: (_) {
                              // Player is created via JS
                            },
                          ),
                        ),
                      ),
                    ),

                    // Simple visualizer (time-based)
                    Container(
                      height: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: SlowverbColors.surface,
                        borderRadius: BorderRadius.circular(
                          SlowverbTokens.radiusSm,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _SimpleVisualizerPainter(
                          time: _currentTime,
                          isPlaying: _isPlaying,
                          progress: _duration > 0
                              ? _currentTime / _duration
                              : 0,
                        ),
                        size: const Size(double.infinity, 80),
                      ),
                    ),

                    // Playback controls
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () =>
                                YouTubePlayerInterop.seek(_currentTime - 10),
                            icon: const Icon(Icons.replay_10),
                            iconSize: 32,
                            color: SlowverbColors.neonCyan,
                          ),
                          const SizedBox(width: 24),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SlowverbColors.vaporwaveSunset,
                              boxShadow: [
                                BoxShadow(
                                  color: SlowverbColors.hotPink.withOpacity(
                                    0.5,
                                  ),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () {
                                if (_isPlaying) {
                                  YouTubePlayerInterop.pause();
                                } else {
                                  YouTubePlayerInterop.play();
                                }
                              },
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 32,
                              ),
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            onPressed: () =>
                                YouTubePlayerInterop.seek(_currentTime + 10),
                            icon: const Icon(Icons.forward_10),
                            iconSize: 32,
                            color: SlowverbColors.neonCyan,
                          ),
                        ],
                      ),
                    ),

                    // Time display
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '${_formatTime(_currentTime)} / ${_formatTime(_duration)}',
                        style: const TextStyle(
                          color: SlowverbColors.neonCyan,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadVideo() async {
    final urlText = _urlController.text.trim();
    if (urlText.isEmpty) {
      setState(() => _error = 'Please enter a YouTube URL');
      return;
    }

    final videoId = YouTubePlayerInterop.parseVideoId(urlText);
    if (videoId == null) {
      setState(() => _error = 'Invalid YouTube URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Register the platform view
      _registerYouTubeView(videoId);

      setState(() {
        _videoId = videoId;
        _playerReady = true;
        _isLoading = false;
      });

      // Initialize player after a short delay to let view render
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          final duration = await YouTubePlayerInterop.initPlayer(
            videoId,
            'youtube-player-container',
          );
          if (mounted) {
            setState(() => _duration = duration);
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = 'Failed to load video: $e';
              _playerReady = false;
            });
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _registerYouTubeView(String videoId) {
    // Create a div for the YouTube player
    final container = web.document.createElement('div') as web.HTMLDivElement;
    container.id = 'youtube-player-container';
    container.style.width = '100%';
    container.style.height = '100%';

    // Register platform view factory
    // Note: This uses dart:ui_web which should be available in web builds
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Simple time-based visualizer painter
class _SimpleVisualizerPainter extends CustomPainter {
  final double time;
  final bool isPlaying;
  final double progress;

  _SimpleVisualizerPainter({
    required this.time,
    required this.isPlaying,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw progress bar background
    paint.color = Colors.white.withOpacity(0.1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height - 4, size.width, 4),
        const Radius.circular(2),
      ),
      paint,
    );

    // Draw progress
    paint.color = SlowverbColors.neonCyan;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height - 4, size.width * progress, 4),
        const Radius.circular(2),
      ),
      paint,
    );

    // Draw animated bars based on time
    if (isPlaying) {
      final barCount = 32;
      final barWidth = size.width / barCount - 2;

      for (var i = 0; i < barCount; i++) {
        // Generate pseudo-random height based on time and position
        final phase = i * 0.3 + time * 2;
        final height =
            (0.3 + 0.7 * ((sin(phase) + 1) / 2)) * (size.height - 10);

        final gradient = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [SlowverbColors.hotPink, SlowverbColors.neonCyan],
        );

        paint.shader = gradient.createShader(
          Rect.fromLTWH(
            i * (barWidth + 2),
            size.height - 10 - height,
            barWidth,
            height,
          ),
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              i * (barWidth + 2),
              size.height - 10 - height,
              barWidth,
              height,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleVisualizerPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.progress != progress;
  }
}
