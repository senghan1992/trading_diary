// Widget smoke test: the MaterialApp-level theme wiring reacts to
// ThemeProvider.themeMode exactly like main.dart binds it — light theme by
// default (system), and a dark scaffold background when the mode switches
// to dark.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_diary/l10n/app_localizations.dart';
import 'package:trading_diary/providers/language_provider.dart';
import 'package:trading_diary/providers/theme_provider.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/screens/settings_screen.dart';
import 'package:trading_diary/theme/app_theme.dart';

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Text('bg:${bg.toARGB32()}', textDirection: TextDirection.ltr);
  }
}

Widget _app(ThemeProvider provider) {
  return MultiProvider(
    providers: [ChangeNotifierProvider<ThemeProvider>.value(value: provider)],
    child: Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode,
        themeAnimationDuration: Duration.zero,
        builder: (context, child) {
          AppColors.setBrightness(Theme.of(context).brightness);
          return child!;
        },
        home: const Scaffold(body: _Probe()),
      ),
    ),
  );
}

Future<String> _probeBackground(WidgetTester tester) async {
  await tester.pumpAndSettle();
  return tester.widget<Text>(find.byType(Text)).data!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('system mode on a light platform paints the light palette', (
    tester,
  ) async {
    final provider = ThemeProvider();
    await tester.pumpWidget(_app(provider));
    final data = await _probeBackground(tester);
    expect(
      data,
      'bg:${AppTheme.lightTheme.scaffoldBackgroundColor.toARGB32()}',
    );
  });

  testWidgets('switching to dark repaints with the dark palette', (
    tester,
  ) async {
    final provider = ThemeProvider();
    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    await provider.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    final data = await _probeBackground(tester);
    expect(
      data,
      'bg:${AppTheme.darkTheme.scaffoldBackgroundColor.toARGB32()}',
    );
    expect(data, 'bg:${AppColorsDark.bg.toARGB32()}');

    await provider.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    final light = await _probeBackground(tester);
    expect(
      light,
      'bg:${AppTheme.lightTheme.scaffoldBackgroundColor.toARGB32()}',
    );
  });

  testWidgets(
    'SettingsScreen immediately updates to dark palette without tab switch',
    (tester) async {
      final themeProvider = ThemeProvider();
      final languageProvider = LanguageProvider();
      final tradeProvider = TradeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
            ChangeNotifierProvider<LanguageProvider>.value(
              value: languageProvider,
            ),
            ChangeNotifierProvider<TradeProvider>.value(value: tradeProvider),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, theme, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: theme.themeMode,
              themeAnimationDuration: Duration.zero,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('ko'),
              builder: (context, child) {
                AppColors.setBrightness(Theme.of(context).brightness);
                return child!;
              },
              home: const SettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial state: Light mode
      expect(AppColors.isDark, isFalse);
      var scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColorsLight.bg);

      // Tap "다크" mode button
      await tester.tap(find.text('다크'));
      await tester.pumpAndSettle();

      // Verify SettingsScreen immediately changed to dark mode without navigating away
      expect(AppColors.isDark, isTrue);
      scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColorsDark.bg);

      // Tap "라이트" mode button
      await tester.tap(find.text('라이트'));
      await tester.pumpAndSettle();

      // Verify SettingsScreen immediately changed back to light mode
      expect(AppColors.isDark, isFalse);
      scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColorsLight.bg);
    },
  );
}
