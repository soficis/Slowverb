import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slowverb_web/app/app.dart';
import 'package:slowverb_web/utils/vercel_analytics.dart';

void main() {
  // Fonts are bundled in assets/google_fonts; never hit the network (offline PWA).
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize Vercel Web Analytics
  // This enables client-side analytics tracking for the web application
  trackEvent('app_started', {'timestamp': DateTime.now().toIso8601String()});

  runApp(const SlowverbApp());
}
