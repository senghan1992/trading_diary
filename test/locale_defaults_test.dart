// Unit tests for the locale-driven first-launch defaults in ThemeProvider
// and LanguageProvider.
//
// Both providers used to ship with hard-coded defaults (`useKoreanColors
// = false`, `Locale('ko')`) so a Korean device first-launching the app
// saw the wrong UI until the user manually toggled. The new behavior:
//
//   • device locale `ko_*`  → Korean colors + Korean language
//   • device locale `en_*`  → Western colors + English language
//   • any locale after the user has explicitly toggled in Settings →
//     the saved preference wins
//
// The defaults are computed synchronously at construction from
// `WidgetsBinding.instance.platformDispatcher.locale`, so the first
// frame already paints with the correct settings. [_loadPrefs] may
// overwrite later if the user has a saved preference.

import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_diary/providers/language_provider.dart';
import 'package:trading_diary/providers/theme_provider.dart';
import 'package:trading_diary/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Sets the platform locale synchronously — the providers read it
  /// at construction time, before any `pumpAndSettle`, so we have to
  /// override it via the binding (not via the WidgetsApp pipeline).
  void setLocale(Locale locale) {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.localeTestValue = locale;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.clearLocaleTestValue();
  });

  group('ThemeProvider — first-launch defaults from device locale', () {
    test('Korean device (ko_KR) → Korean colors by default', () {
      setLocale(const Locale('ko', 'KR'));
      final provider = ThemeProvider();
      expect(provider.useKoreanColors, isTrue,
          reason: 'Korean device should pick KOSPI-style red/blue colors');
      expect(provider.upColor, AppColors.red);
      expect(provider.downColor, AppColors.blue);
    });

    test('English device (en_US) → Western colors by default', () {
      setLocale(const Locale('en', 'US'));
      final provider = ThemeProvider();
      expect(provider.useKoreanColors, isFalse,
          reason: 'English device should pick NASDAQ-style green/red');
      expect(provider.upColor, AppColors.green);
      expect(provider.downColor, AppColors.red);
    });

    test('Unknown locale (ja_JP) → falls back to Western', () {
      setLocale(const Locale('ja', 'JP'));
      final provider = ThemeProvider();
      expect(provider.useKoreanColors, isFalse);
    });

    test('saved user preference overrides the device-locale default',
        () async {
      // User previously chose Korean colors on an English device.
      SharedPreferences.setMockInitialValues({'app_color_mode': true});
      setLocale(const Locale('en', 'US'));
      final provider = ThemeProvider();
      // _loadPrefs is fire-and-forget; wait one microtask for it to land.
      await Future<void>.delayed(Duration.zero);
      expect(provider.useKoreanColors, isTrue,
          reason: 'Saved user choice should win over the device default');
    });
  });

  group('LanguageProvider — first-launch defaults from device locale', () {
    test('Korean device → Korean locale', () {
      setLocale(const Locale('ko'));
      final provider = LanguageProvider();
      expect(provider.locale.languageCode, 'ko');
      expect(provider.isKorean, isTrue);
    });

    test('English device → English locale', () {
      setLocale(const Locale('en'));
      final provider = LanguageProvider();
      expect(provider.locale.languageCode, 'en');
      expect(provider.isEnglish, isTrue);
    });

    test('Unknown locale (ja) → falls back to English', () {
      setLocale(const Locale('ja'));
      final provider = LanguageProvider();
      expect(provider.locale.languageCode, 'en',
          reason: 'Unsupported locales fall back to English — the only '
              'other entry in `supportedLocales`');
    });

    test('saved user preference overrides the device-locale default',
        () async {
      SharedPreferences.setMockInitialValues({'app_language': 'en'});
      setLocale(const Locale('ko'));
      final provider = LanguageProvider();
      await Future<void>.delayed(Duration.zero);
      expect(provider.locale.languageCode, 'en',
          reason: 'User chose English once → keeps English even after the '
              'device locale changes to Korean');
    });
  });

  group('Korean device — full Korean defaults (smoke test)', () {
    // Verifies the combination the user described in the request:
    // "나는 지금 한국에서 테스트 해보고 있으니까 캔들 스타일은 한국 스타일,
    //  언어는 한국어." Both providers must agree on the locale so the
    // first frame isn't split (Korean text, Western colors) until the
    // user toggles.
    test('ko_KR → Korean colors AND Korean language', () {
      setLocale(const Locale('ko', 'KR'));
      final themeProvider = ThemeProvider();
      final languageProvider = LanguageProvider();
      expect(themeProvider.useKoreanColors, isTrue);
      expect(languageProvider.locale.languageCode, 'ko');
    });
  });
}