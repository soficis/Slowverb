import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:slowverb_web/app/app_config.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

/// About screen with app information and credits
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: 1.5);
    final linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: SlowverbTokens.vfdCyan,
      decoration: TextDecoration.underline,
      height: 1.5,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('ABOUT')),
      body: RetroDesktop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padding = EdgeInsets.all(
                constraints.maxWidth < 600
                    ? SlowverbTokens.spacingMd
                    : SlowverbTokens.spacingLg,
              );
              return SingleChildScrollView(
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo and subtitle
                        Center(child: SlowverbWordmark(size: narrow ? 30 : 44)),
                        const SizedBox(height: SlowverbTokens.spacingSm),
                        Center(
                          child: Text(
                            'Slowed + Reverb Audio Editor',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),

                        const SizedBox(height: SlowverbTokens.spacingLg),

                        RetroWindow(
                          title: 'About',
                          child: Text(
                            'Slowverb is a browser-based audio editor for creating dreamy slowed + reverb effects. All audio processing happens locally in your browser using WebAssembly.',
                            style: bodyStyle,
                          ),
                        ),
                        const SizedBox(height: SlowverbTokens.spacingMd),

                        RetroWindow(
                          title: 'Supported Formats',
                          child: Text(
                            'Input: MP3, WAV, AAC, M4A, OGG, FLAC\n'
                            'Output: MP3 (128-320 kbps), WAV (lossless), FLAC (lossless), AAC',
                            style: bodyStyle,
                          ),
                        ),
                        const SizedBox(height: SlowverbTokens.spacingMd),

                        RetroWindow(
                          title: 'Features',
                          child: Text(
                            '• 18 built-in presets, plus your own\n'
                            '• Tempo, pitch, reverb, echo, warmth, phaser and bass controls\n'
                            '• Playback devices: car speakers, gramophone, cassette\n'
                            '• Reverb types including a plate and a hotel bathroom\n'
                            '• Retro audio visualizers\n'
                            '• PhaseLimiter mastering for loudness & clarity\n'
                            '• Batch export, including lossless FLAC',
                            style: bodyStyle,
                          ),
                        ),
                        const SizedBox(height: SlowverbTokens.spacingMd),

                        RetroWindow(
                          title: 'Mastering',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Professional mastering powered by PhaseLimiter',
                                style: bodyStyle,
                              ),
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.parse(
                                    'https://github.com/ai-mastering/phaselimiter',
                                  );
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                                child: Text(
                                  'https://github.com/ai-mastering/phaselimiter',
                                  style: linkStyle,
                                ),
                              ),
                              const SizedBox(height: SlowverbTokens.spacingSm),
                              Text(
                                'PhaseLimiter is MIT licensed. This implementation is released under GPLv3.',
                                style: bodyStyle,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: SlowverbTokens.spacingMd),

                        RetroWindow(
                          title: 'Impulse Responses',
                          child: Text(
                            'Playback devices (car, gramophone, cassette), the plate and the hotel bathroom reverb use '
                            'impulse responses from the IR Library by Conner (github.com/itsmusician/IR-Library), '
                            'Copyright © 2022 Conner, MIT License. The full licence text is shipped at '
                            'irs/LICENSE-itsmusician-IR-Library.md.\n\n'
                            'Fonts: Rajdhani, DotGothic16, DSEG and Roboto (SIL Open Font License). '
                            'ZIP export: JSZip (MIT).',
                            style: bodyStyle,
                          ),
                        ),
                        const SizedBox(height: SlowverbTokens.spacingMd),

                        RetroWindow(
                          title: 'License',
                          child: Text(
                            'Slowverb is free and open-source software licensed under the GNU General Public License v3.0 (GPLv3).\n\n'
                            'Copyright © 2025 Slowverb\n\n'
                            'This program comes with ABSOLUTELY NO WARRANTY.',
                            style: bodyStyle,
                          ),
                        ),

                        const SizedBox(height: SlowverbTokens.spacingLg),

                        // GitHub link
                        Center(
                          child: HwKey(
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
                            icon: Icons.code,
                            label: 'View Source on GitHub',
                          ),
                        ),

                        const SizedBox(height: SlowverbTokens.spacingMd),

                        // My First Rodeo link
                        Center(
                          child: HwKey(
                            onPressed: () async {
                              final uri = Uri.parse('https://nihilist.rodeo');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            label: 'My First Rodeo',
                          ),
                        ),

                        const SizedBox(height: SlowverbTokens.spacingLg),

                        // Version
                        const Center(
                          child: VfdText('Version ${AppConfig.version}', size: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
