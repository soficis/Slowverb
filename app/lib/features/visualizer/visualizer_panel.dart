import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb/app/colors.dart';
import 'package:slowverb/app/slowverb_design_tokens.dart';
import 'package:slowverb/domain/entities/visualizer_preset.dart';
import 'package:slowverb/features/visualizer/visualizer_controller.dart';

/// Provides loaded shaders
final shaderProvider = FutureProvider<Map<String, ui.FragmentProgram>>((
  ref,
) async {
  final wmpRetro = await ui.FragmentProgram.fromAsset('shaders/wmp_retro.frag');
  final starfield = await ui.FragmentProgram.fromAsset(
    'shaders/starfield.frag',
  );
  final pipes3d = await ui.FragmentProgram.fromAsset('shaders/pipes_3d.frag');
  final maze3d = await ui.FragmentProgram.fromAsset('shaders/maze_3d.frag');

  return {
    'wmp_retro': wmpRetro,
    'starfield': starfield,
    'pipes_3d': pipes3d,
    'maze_3d': maze3d,
  };
});

enum VisualizerMode { card, background }

class VisualizerPanel extends ConsumerWidget {
  final double? height;
  final VisualizerMode mode;
  final VoidCallback? onDoubleTap;

  const VisualizerPanel({
    super.key,
    this.height,
    this.mode = VisualizerMode.card,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visualizerProvider);
    final controller = ref.read(visualizerProvider.notifier);
    final shadersAsync = ref.watch(shaderProvider);

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        height: mode == VisualizerMode.card ? (height ?? 180) : null,
        decoration: mode == VisualizerMode.card
            ? BoxDecoration(
                color: const Color(0xFF101018),
                borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
                border: Border.all(
                  color: SlowverbColors.neonCyan.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SlowverbColors.neonCyan.withOpacity(0.1),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              )
            : null,
        child: Stack(
          children: [
            // The Visualization
            ClipRRect(
              borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
              child: shadersAsync.when(
                data: (shaders) {
                  final shader = shaders[state.activePreset.id];
                  if (shader == null) {
                    return _buildFallbackVisualizer(state);
                  }
                  return CustomPaint(
                    painter: GpuVisualizerPainter(
                      shader: shader,
                      presetType: state.activePreset.type,
                      frame: state.currentFrame,
                      time: controller.currentTime,
                    ),
                    size: Size.infinite,
                    isComplex: true,
                    willChange: true,
                    child: Container(),
                  );
                },
                loading: () => _buildLoadingView(),
                error: (_, __) => _buildFallbackVisualizer(state),
              ),
            ),

            // Loading indicator
            if (state.isLoading)
              Positioned(
                top: 8,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(
                      SlowverbTokens.radiusSm,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            SlowverbColors.neonCyan,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Analyzing...',
                        style: TextStyle(
                          color: SlowverbColors.neonCyan,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Preset Selector removed (moved to EditorScreen title bar)

            // Label
            Positioned(
              bottom: 8,
              left: 12,
              child: Row(
                children: [
                  const Icon(
                    Icons.memory,
                    size: 12,
                    color: SlowverbColors.neonCyan,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'GPU · ${state.activePreset.name.toUpperCase()}',
                    style: const TextStyle(
                      color: SlowverbColors.neonCyan,
                      fontSize: 10,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: SlowverbColors.neonCyan, blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: const Color(0xFF101018),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(SlowverbColors.neonCyan),
            ),
            SizedBox(height: 8),
            Text(
              'Loading shaders...',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackVisualizer(VisualizerState state) {
    // Simple canvas fallback if shaders fail
    return Container(
      color: const Color(0xFF101018),
      child: const Center(
        child: Text(
          'Visualization (Shaders unavailable)',
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}

/// GPU-accelerated painter using FragmentShader
class GpuVisualizerPainter extends CustomPainter {
  final ui.FragmentProgram shader;
  final VisualizerType presetType;
  final AudioAnalysisFrame frame;
  final double time;

  GpuVisualizerPainter({
    required this.shader,
    required this.presetType,
    required this.frame,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fragmentShader = shader.fragmentShader();

    // Simple 4-float uniform interface matching shaders:
    // uniform float uTime;
    // uniform float uResolutionX;
    // uniform float uResolutionY;
    // uniform float uLevel;
    fragmentShader.setFloat(0, time);
    fragmentShader.setFloat(1, size.width);
    fragmentShader.setFloat(2, size.height);
    fragmentShader.setFloat(3, frame.level.clamp(0.0, 1.0));

    final paint = Paint()..shader = fragmentShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant GpuVisualizerPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.frame.level != frame.level ||
        oldDelegate.presetType != presetType;
  }
}
