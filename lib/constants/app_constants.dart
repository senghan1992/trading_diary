/// Compile-time configuration that is intentionally NOT a runtime persisted
/// preference. Pass via --dart-define at build time so production values stay
/// out of source control. Defaults are placeholders for local development.
class AppConstants {
  AppConstants._();

  /// URL of the application's privacy policy. Both the Apple App Store and
  /// Google Play Store require this URL in their listing metadata, and Apple
  /// reviewers expect to find it in the app itself (typically on a Settings
  /// page). Pass the real hosted URL at build time:
  ///
  ///   flutter build apk --release --dart-define=PRIVACY_POLICY_URL=https://yourcompany.com/privacy
  ///   flutter build ios --release --dart-define=PRIVACY_POLICY_URL=https://yourcompany.com/privacy
  ///
  /// The placeholder below is the IETF example domain — replace before any
  /// release build.
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://example.com/privacy-policy',
  );
}