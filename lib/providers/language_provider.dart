import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  /// Initialized from the device locale at construction time so the very
  /// first frame already renders in the right language. [_loadLocale]
  /// may overwrite it once SharedPreferences has been read.
  Locale _locale = _detectLocaleFromDevice();

  Locale get locale => _locale;

  LanguageProvider() {
    _loadLocale();
  }

  /// Best-effort inference of the user's preferred UI language from the
  /// device locale at first launch.
  ///
  /// Mirrors the logic in [ThemeProvider._detectKoreanFromLocale] — both
  /// providers default from the same locale so the first frame is
  /// internally consistent (Korean device → Korean colors AND Korean
  /// text). Falls back to English for any locale the app doesn't ship
  /// translations for (Korean / English are the only ones in
  /// `supportedLocales`).
  static Locale _detectLocaleFromDevice() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    if (locale.languageCode == 'ko') return const Locale('ko');
    return const Locale('en');
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    // Only overwrite if the user has explicitly chosen before. A `null`
    // value means "first launch on this device" — keep the locale-derived
    // default so a Korean device first-launches in Korean, an English one
    // in English.
    final saved = prefs.getString(_languageKey);
    if (saved != null) {
      _locale = Locale(saved);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
    notifyListeners();
  }

  bool get isKorean => _locale.languageCode == 'ko';
  bool get isEnglish => _locale.languageCode == 'en';
}
