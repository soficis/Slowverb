import 'package:flutter/material.dart';
import 'package:slowverb_web/app/app.dart';
import 'package:slowverb_web/utils/vercel_analytics.dart';

void main() {
  // Initialize Vercel Web Analytics
  // This enables client-side analytics tracking for the web application
  trackEvent('app_started', {'timestamp': DateTime.now().toIso8601String()});

  runApp(const SlowverbApp());
}
