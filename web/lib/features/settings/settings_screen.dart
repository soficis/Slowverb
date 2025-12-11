import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/app_config.dart';
import 'package:slowverb_web/providers/settings_provider.dart';

/// Settings screen for configuring experimental features
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(experimentalFeaturesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // App info card
              _buildCard(
                context,
                title: 'About',
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Slowverb'),
                    subtitle: Text('Version ${AppConfig.version}'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Experimental features card
              _buildCard(
                context,
                title: 'Experimental Features',
                children: [
                  // Experimental warning
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Experimental features may not work with all content and can change or be removed.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // YouTube streaming toggle
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SlowverbColors.neonCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: SlowverbColors.neonCyan,
                      ),
                    ),
                    title: const Text('YouTube Streaming Mode'),
                    subtitle: const Text(
                      'Stream YouTube videos with synced visualizers. '
                      'Audio effects cannot be applied due to CORS/DRM restrictions.',
                    ),
                    value: settings.streamingAudioEnabled,
                    onChanged: (value) {
                      ref
                          .read(experimentalFeaturesProvider.notifier)
                          .setStreamingAudioEnabled(value);
                    },
                    activeThumbColor: SlowverbColors.neonCyan,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Legal disclaimer
              _buildCard(
                context,
                title: 'Usage Guidelines',
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Use streaming features only with content you have rights to transform. '
                      'Slowverb respects platform terms of service and does not circumvent '
                      'DRM or content protection measures.',
                      style: TextStyle(
                        color: SlowverbColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SlowverbColors.surface.withOpacity(0.9),
            SlowverbColors.surfaceVariant.withOpacity(0.8),
          ],
        ),
        border: Border.all(
          color: SlowverbColors.primaryPurple.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: SlowverbColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
