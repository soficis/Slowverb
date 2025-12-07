import 'package:flutter/material.dart';
import 'package:slowverb/app/router.dart';
import 'package:slowverb/app/theme.dart';

/// Root application widget for Slowverb
///
/// Configures theming, routing, and global app settings.
class SlowverbApp extends StatelessWidget {
  const SlowverbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Slowverb',
      debugShowCheckedModeBanner: false,
      theme: SlowverbTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
