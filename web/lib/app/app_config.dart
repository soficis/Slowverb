/// Application configuration and feature flags
abstract final class AppConfig {
  /// Version information
  static const String version = '2.1.0';
  static const String buildNumber = '1';

  /// Feature flags

  /// Show developer/debug options
  static const bool showDevOptions = false;

  /// URLs
  static const String githubUrl = 'https://github.com/soficis/Slowverb';
  static const String privacyUrl = 'https://slowverb.app/privacy';

  /// Default settings
  static const double defaultTempo = 0.95; // 95% speed for slowed effect
  static const double defaultReverbMix = 0.35;
  static const double defaultReverbDecay = 2.5;
}
