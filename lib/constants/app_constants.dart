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

  /// URL of the server-driven update configuration JSON. The shape is:
  ///
  /// ```json
  /// {
  ///   "latest_version": "1.0.0",
  ///   "minimum_version": "1.0.0",
  ///   "force_update": false,
  ///   "update_message_ko": "...",
  ///   "update_message_en": "...",
  ///   "store_url_ios": "https://apps.apple.com/app/id...",
  ///   "store_url_android": "https://play.google.com/store/apps/details?id=..."
  /// }
  /// ```
  ///
  /// Host on any static file host (GitHub Pages, Cloudflare R2, S3, Firebase
  /// Hosting). When `force_update` is true OR `minimum_version` exceeds the
  /// installed version, the app blocks startup until the user updates.
  /// Pass at build time:
  ///
  ///   flutter build apk --release --dart-define=APP_CONFIG_URL=https://yourdomain.com/app-config.json
  ///   flutter build ios --release --dart-define=APP_CONFIG_URL=https://yourdomain.com/app-config.json
  ///
  /// If left at the example.com default, the check is skipped entirely so
  /// local development never blocks on a placeholder URL.
  static const String appConfigUrl = String.fromEnvironment(
    'APP_CONFIG_URL',
    defaultValue: 'https://example.com/app-config.json',
  );

  /// Apple App Store numeric ID for the iOS app. Get this from App Store
  /// Connect → App Information → Apple ID once the listing is created.
  /// Leave empty until the App Store Connect entry exists.
  static const String iosAppStoreId = String.fromEnvironment(
    'IOS_APP_STORE_ID',
    defaultValue: '',
  );

  /// Android applicationId / Play Store package name. Defaults to the value
  /// declared in android/app/build.gradle.kts so dev builds open the right
  /// store listing once it's published.
  static const String androidPackageName = String.fromEnvironment(
    'ANDROID_PACKAGE_NAME',
    defaultValue: 'com.yourcompany.tradingdiary',
  );
}
