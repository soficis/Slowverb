import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/app_config.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

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
          tooltip: 'Back',
          onPressed: () => context.go('/'),
        ),
      ),
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
                        // App info
                        const RetroWindow(
                          title: 'About',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.info_outline),
                            title: Text('Slowverb'),
                            subtitle: Text('Version ${AppConfig.version}'),
                          ),
                        ),
                        const SizedBox(height: SlowverbTokens.spacingMd),

                        // Legal disclaimer
                        RetroWindow(
                          title: 'Usage Guidelines',
                          child: Text(
                            'Use Slowverb only with content you have rights to transform. '
                            'All processing happens locally in your browser.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.5),
                          ),
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
