import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// App-wide up/down color convention AND light/dark theme mode.
///
/// [ThemeMode] (system / light / dark) is persisted under `app_theme_mode`
/// and consumed by `MaterialApp.themeMode` in main.dart. The Korean
/// (red-up/blue-down) vs Western (green-up/red-down) price color mode is
/// essential for Korean investors and is kept alongside it.
class ThemeProvider extends ChangeNotifier {
  static const String _colorKey = 'app_color_mode';
  static const String _themeModeKey = 'app_theme_mode';
  ThemeMode _themeMode = ThemeMode.system;
  bool _useKoreanColors = _detectKoreanFromLocale();

  ThemeMode get themeMode => _themeMode;
  bool get useKoreanColors => _useKoreanColors;
  bool get isWesternColors => !_useKoreanColors;
  Color get upColor => _useKoreanColors ? AppColors.red : AppColors.green;
  Color get downColor => _useKoreanColors ? AppColors.blue : AppColors.red;
  Color get upBg => _useKoreanColors ? AppColors.redBg : AppColors.greenBg;
  Color get downBg => _useKoreanColors ? AppColors.blueBg : AppColors.redBg;

  /// Resolves the effective brightness for the current [themeMode].
  Brightness get resolvedBrightness {
    switch (_themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    // Synchronously update AppColors brightness BEFORE notifying listeners so
    // widgets rebuilding on this notification immediately read the new palette.
    AppColors.setBrightness(resolvedBrightness);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  ThemeProvider() {
    AppColors.setBrightness(resolvedBrightness);
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
    // Only overwrite if the user has explicitly chosen before. A `null`
    // value means "first launch on this device" — keep the locale-derived
    // default so a Korean device first-launches in Korean colors, an
    // English one in Western.
    final savedColor = prefs.getBool(_colorKey);
    if (savedColor != null) {
      _useKoreanColors = savedColor;
    }
    final savedMode = prefs.getString(_themeModeKey);
    if (savedMode != null) {
      _themeMode = switch (savedMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      AppColors.setBrightness(resolvedBrightness);
    }
    notifyListeners();
  }

  Future<void> setKoreanColors(bool value) async {
    _useKoreanColors = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_colorKey, value);
    notifyListeners();
  }
}
