import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_diary/l10n/app_localizations.dart';
import 'package:trading_diary/models/account_tag.dart';
import 'package:trading_diary/providers/language_provider.dart';
import 'package:trading_diary/providers/theme_provider.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/screens/account_management_screen.dart';
import 'package:trading_diary/screens/journal_screen.dart';
import 'package:trading_diary/screens/settings_screen.dart';
import 'package:trading_diary/services/local_storage_service.dart';
import 'package:trading_diary/theme/app_theme.dart';

void main() {
  late Directory tempDir;

  const kTradesBox = 'trades';
  const kAccountsBox = 'accounts';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trading_diary_settings_test');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(kTradesBox);
    await Hive.openBox<dynamic>(kAccountsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await Hive.box<dynamic>(kTradesBox).clear();
    await Hive.box<dynamic>(kAccountsBox).clear();
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required ThemeProvider themeProvider,
    required LanguageProvider languageProvider,
    required TradeProvider tradeProvider,
    required Widget child,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<TradeProvider>.value(value: tradeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: theme.themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: child,
        ),
      ),
    );
  }

  testWidgets('SettingsScreen displays compact segmented controls and toggles options', (
    tester,
  ) async {
    final themeProvider = ThemeProvider();
    final languageProvider = LanguageProvider();
    final tradeProvider = TradeProvider();

    await tester.pumpWidget(
      buildTestApp(
        themeProvider: themeProvider,
        languageProvider: languageProvider,
        tradeProvider: tradeProvider,
        child: const SettingsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Theme Mode segments exist: 시스템, 라이트, 다크
    expect(find.text('시스템'), findsOneWidget);
    expect(find.text('라이트'), findsOneWidget);
    expect(find.text('다크'), findsOneWidget);

    // Tap '다크' segment
    await tester.tap(find.text('다크'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(themeProvider.themeMode, ThemeMode.dark);

    // Tap '라이트' segment
    await tester.tap(find.text('라이트'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(themeProvider.themeMode, ThemeMode.light);

    // Verify Price Color segments exist: 한국식, 서양식
    expect(find.text('한국식'), findsOneWidget);
    expect(find.text('서양식'), findsOneWidget);

    // Tap '서양식'
    await tester.tap(find.text('서양식'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(themeProvider.useKoreanColors, isFalse);

    // Tap '한국식'
    await tester.tap(find.text('한국식'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(themeProvider.useKoreanColors, isTrue);

    // Verify Account & Tag Management item navigates to AccountManagementScreen
    expect(find.text('계좌 및 태그 관리'), findsOneWidget);
    await tester.tap(find.text('계좌 및 태그 관리'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AccountManagementScreen), findsOneWidget);

    // Go back
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Scroll to Language section and test
    await tester.scrollUntilVisible(find.text('English'), 200);
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(languageProvider.locale.languageCode, 'en');

    await tester.tap(find.text('한국어'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(languageProvider.locale.languageCode, 'ko');
  });

  testWidgets('SettingsScreen shows registered account count', (tester) async {
    await tester.runAsync(
      () => LocalStorageService.saveAccount(
        AccountTag(
          id: 'acc1',
          name: '토스증권 ISA',
          colorValue: 0xFF0064FF,
          createdAt: DateTime(2026, 1, 1),
        ),
      ),
    );

    final tradeProvider = TradeProvider();
    tradeProvider.loadAccounts();

    final themeProvider = ThemeProvider();
    final languageProvider = LanguageProvider();
    await languageProvider.setLocale(const Locale('ko'));

    await tester.pumpWidget(
      buildTestApp(
        themeProvider: themeProvider,
        languageProvider: languageProvider,
        tradeProvider: tradeProvider,
        child: const SettingsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1개 계좌 등록됨'), findsOneWidget);
  });

  testWidgets('JournalScreen does NOT contain accountManagement buttons in AppBar or filter bar', (
    tester,
  ) async {
    final themeProvider = ThemeProvider();
    final languageProvider = LanguageProvider();
    final tradeProvider = TradeProvider();

    await tester.pumpWidget(
      buildTestApp(
        themeProvider: themeProvider,
        languageProvider: languageProvider,
        tradeProvider: tradeProvider,
        child: const JournalScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify '계좌 및 태그 관리' text is nowhere in JournalScreen
    expect(find.text('계좌 및 태그 관리'), findsNothing);
    // Verify Settings button in AppBar is gone (only table_view export is present)
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });
}
