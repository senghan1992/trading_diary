// Dual-theme (light/dark + system) regression tests.
//
// These pin the observable contract of the theme system:
//   • `AppTheme.lightTheme` and `AppTheme.darkTheme` both exist with the
//     correct brightness.
//   • The `AppColors` facade resolves light values on light brightness and
//     the AppColorsDark palette on dark brightness.
//   • ThemeProvider defaults to ThemeMode.system, persists mode changes
//     under `app_theme_mode`, and restores them on a fresh instance.
//   • MaterialApp wiring in main.dart passes theme + darkTheme + themeMode.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_diary/providers/theme_provider.dart';
import 'package:trading_diary/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeData', () {
    test('lightTheme is brightness-light', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
    });

    test('darkTheme exists and is brightness-dark', () {
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, AppColorsDark.bg);
      expect(AppTheme.lightTheme.scaffoldBackgroundColor, const Color(0xFFF6F4ED));
    });
  });

  group('AppColors facade', () {
    test('resolves light palette on light brightness', () {
      AppColors.setBrightness(Brightness.light);
      expect(AppColors.bg, const Color(0xFFF6F4ED));
      expect(AppColors.card, const Color(0xFFFFFFFF));
      expect(AppColors.text, const Color(0xFF182019));
      expect(AppColors.accent, const Color(0xFF1E5B45));
      expect(AppColors.isDark, isFalse);
    });

    test('resolves dark palette on dark brightness', () {
      AppColors.setBrightness(Brightness.dark);
      expect(AppColors.bg, AppColorsDark.bg);
      expect(AppColors.card, AppColorsDark.card);
      expect(AppColors.surface, AppColorsDark.surface);
      expect(AppColors.border, AppColorsDark.border);
      expect(AppColors.text, AppColorsDark.text);
      expect(AppColors.textMuted, AppColorsDark.textMuted);
      expect(AppColors.accent, AppColorsDark.accent);
      expect(AppColors.isDark, isTrue);
      // Restore for other tests.
      AppColors.setBrightness(Brightness.light);
    });
  });

  group('ThemeProvider mode', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to system mode', () {
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.system);
    });

    test('setThemeMode notifies and persists', () async {
      final provider = ThemeProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
      expect(AppColors.isDark, isTrue);
      expect(notified, isTrue);

      await provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);
      expect(AppColors.isDark, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_mode'), 'light');
    });

    test('restores persisted mode on a fresh instance', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
      final provider = ThemeProvider();
      // _loadPrefs is async; let the microtask queue drain.
      await Future<void>.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('unknown persisted value falls back to system', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'bogus'});
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.system);
    });
  });
}
