import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/app_config.dart';

/// Settings screen for configuring experimental features
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

              // Legal disclaimer
              _buildCard(
                context,
                title: 'Usage Guidelines',
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Use Slowverb only with content you have rights to transform. '
                      'All processing happens locally in your browser.',
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
