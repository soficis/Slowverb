import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/router.dart';
import 'package:slowverb_web/app/theme.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';

/// Root application widget with engine initialization
class SlowverbApp extends StatelessWidget {
  const SlowverbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          final engineInit = ref.watch(engineInitProvider);

          return engineInit.when(
            data: (_) => MaterialApp.router(
              title: 'Slowverb',
              debugShowCheckedModeBanner: false,
              theme: SlowverbTheme.darkTheme,
              routerConfig: appRouter,
            ),
            loading: () => MaterialApp(
              home: Scaffold(
                backgroundColor: SlowverbColors.backgroundDark,
                body: Container(
                  decoration: const BoxDecoration(
                    gradient: SlowverbColors.backgroundGradient,
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: SlowverbColors.primaryPurple,
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Initializing audio engine...',
                          style: TextStyle(
                            color: SlowverbColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            error: (error, stack) => MaterialApp(
              home: Scaffold(
                backgroundColor: SlowverbColors.backgroundDark,
                body: Container(
                  decoration: const BoxDecoration(
                    gradient: SlowverbColors.backgroundGradient,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: SlowverbColors.error,
                            size: 64,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Failed to initialize audio engine',
                            style: TextStyle(
                              color: SlowverbColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            style: const TextStyle(
                              color: SlowverbColors.textSecondary,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
