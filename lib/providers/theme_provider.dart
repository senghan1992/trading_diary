import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  static const String _colorKey = 'app_color_mode';
  bool _isDarkMode = true;
  bool _useKoreanColors = _detectKoreanFromLocale();

  bool get isDarkMode => _isDarkMode;
  bool get useKoreanColors => _useKoreanColors;
  bool get isWesternColors => !_useKoreanColors;

  Color get upColor => _useKoreanColors ? AppColors.red : AppColors.green;
  Color get downColor => _useKoreanColors ? AppColors.blue : AppColors.red;
  Color get upBg => _useKoreanColors ? AppColors.redBg : AppColors.greenBg;
  Color get downBg => _useKoreanColors ? AppColors.blueBg : AppColors.redBg;

  ThemeProvider() {
    _loadPrefs();
  }

  /// Best-effort inference of "is the user in a Korean-speaking market?"
  /// from the device locale at first launch.
  ///
  /// We use `WidgetsBinding.instance.platformDispatcher.locale` because
  /// `Locale.fromSubtags` is the OS's own locale, which on iOS/Android
  /// follows the device region setting (Settings → General → Language).
  /// We don't do IP geo-lookup — that's a network call for marginal value
  /// since the device region is what the user actively configured.
  ///
  /// Returns `true` for any `ko_*` locale, `false` otherwise. Called
  /// synchronously from the constructor so the first frame already
  /// paints with the correct colors; [_loadPrefs] may overwrite the
  /// value once SharedPreferences has been read.
  static bool _detectKoreanFromLocale() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return locale.languageCode == 'ko';
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? true;
    // Only overwrite if the user has explicitly chosen before. A `null`
    // value means "first launch on this device" — keep the locale-derived
    // default so a Korean device first-launches in Korean colors, an
    // English one in Western.
    final savedColor = prefs.getBool(_colorKey);
    if (savedColor != null) {
      _useKoreanColors = savedColor;
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
    notifyListeners();
  }

  Future<void> setKoreanColors(bool value) async {
    _useKoreanColors = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_colorKey, value);
    notifyListeners();
  }
}
