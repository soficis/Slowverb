import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:slowverb_web/app/colors.dart';

/// About screen with app information and credits
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SlowverbColors.backgroundDark,
      appBar: AppBar(title: const Text('ABOUT')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: SlowverbColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          SlowverbColors.primaryGradient.createShader(bounds),
                      child: Text(
                        'SLOWVERB',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w200,
                              letterSpacing: 8.0,
                            ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: Text(
                      'Slowed + Reverb Audio Editor',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: SlowverbColors.textSecondary,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  _buildSection(
                    context,
                    icon: Icons.info_outline,
                    title: 'About',
                    content:
                        'Slowverb is a browser-based audio editor for creating dreamy slowed + reverb and vaporwave effects. All audio processing happens locally in your browser using WebAssembly.',
                  ),

                  const SizedBox(height: 24),

                  _buildSection(
                    context,
                    icon: Icons.security,
                    title: 'Privacy First',
                    content:
                        'Your audio files NEVER leave your device. Everything is processed locally using FFmpeg.wasm. No uploads, no tracking, no data collection.',
                  ),

                  const SizedBox(height: 24),

                  _buildSection(
                    context,
                    icon: Icons.music_note,
                    title: 'Supported Formats',
                    content:
                        'Input: MP3, WAV, AAC, M4A, OGG, FLAC\n'
                        'Output: MP3 (128-320 kbps), WAV (lossless), FLAC (lossless)',
                  ),

                  const SizedBox(height: 24),

                  _buildSection(
                    context,
                    icon: Icons.tune,
                    title: 'Features',
                    content:
                        '• 12 professional effect presets\n'
                        '• Custom parameter control (tempo, pitch, reverb, echo, warmth)\n'
                        '• Interactive waveform visualization\n'
                        '• Real-time audio preview\n'
                        '• High-quality FLAC export',
                  ),

                  const SizedBox(height: 24),

                  _buildSection(
                    context,
                    icon: Icons.code,
                    title: 'Built With',
                    content:
                        '• Flutter Web for the UI\n'
                        '• FFmpeg.wasm for audio processing\n'
                        '• Web Workers for background processing\n'
                        '• Material Design 3 with custom vaporwave theme',
                  ),

                  const SizedBox(height: 24),

                  _buildSection(
                    context,
                    icon: Icons.copyright,
                    title: 'License',
                    content:
                        'Slowverb is free and open-source software licensed under the GNU General Public License v3.0 (GPLv3).\n\n'
                        'Copyright © 2025 Slowverb\n\n'
                        'This program comes with ABSOLUTELY NO WARRANTY.',
                  ),

                  const SizedBox(height: 32),

                  // Version
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: SlowverbColors.backgroundLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Version 1.0.0-beta',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SlowverbColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // GitHub Link
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(
                          'https://github.com/soficis/Slowverb',
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('View Source on GitHub'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SlowverbColors.accentCyan,
                        side: const BorderSide(
                          color: SlowverbColors.accentCyan,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: SlowverbColors.accentCyan),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: SlowverbColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: SlowverbColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
