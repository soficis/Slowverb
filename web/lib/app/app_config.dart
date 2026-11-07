/// Application configuration and feature flags
abstract final class AppConfig {
  /// Shown in Settings and About. Keep in sync with `version:` in pubspec.yaml
  /// and `version` in package.json.
  static const String version = '2.2.0';

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
