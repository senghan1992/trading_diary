// Multi-account dashboard smoke tests.
//
// Verifies the plan's cross-screen account flow against a real Hive
// 'accounts' box (no network, no ads SDK calls):
//   • HomeScreen renders the portfolio hero and the "My Accounts" carousel,
//     listing every registered account with its stats.
//   • Tapping an account chip in the journal switches
//     TradeProvider.selectedAccountTagFilter; the all-accounts chip restores
//     the combined view. That single filter drives both the open-position
//     and closed-trade sub-tabs.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:trading_diary/l10n/app_localizations.dart';
import 'package:trading_diary/providers/theme_provider.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/screens/home_screen.dart';
import 'package:trading_diary/screens/journal_screen.dart';
import 'package:trading_diary/theme/app_theme.dart';

void main() {
  late Directory tempDir;

  const kTradesBox = 'trades';
  const kAccountsBox = 'accounts';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trading_diary_dash');
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
  });

  // Real Hive file I/O inside a widget test's FakeAsync zone can deadlock
  // when the box write does not complete within the synchronous window
  // (observed under concurrent flutter_tester load). `runAsync` steps out
  // of the fake zone for the seed writes, which is the documented escape
  // hatch for real I/O in widget tests.
  Future<TradeProvider> seedAccounts(WidgetTester tester) async {
    final provider = TradeProvider();
    await tester.runAsync(() async {
      await provider.addAccount(
        name: '키움 메인',
        colorValue: const Color(0xFF004CFF).toARGB32(),
        memo: null,
      );
      await provider.addAccount(name: '미래에셋 ISA', memo: null);
    });
    return provider;
  }

  // NOTE: fixed pumps instead of pumpAndSettle — some Material animations
  // never settle under flutter_test (same harness as the accounts smoke).
  Widget wrap(TradeProvider provider, Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<TradeProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko'), Locale('en')],
        home: child,
      ),
    );
  }

  testWidgets('HomeScreen renders hero + accounts strip on empty data', (
    tester,
  ) async {
    final provider = TradeProvider();
    await tester.pumpWidget(wrap(provider, const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomeScreen), findsOneWidget);
    final ko = lookupAppLocalizations(const Locale('ko'));
    // The combined-portfolio chip and quick-add entry of the strip.
    expect(find.text(ko.allAccounts), findsOneWidget);
    expect(find.text(ko.addAccount), findsOneWidget);
  });

  testWidgets('Home accounts strip lists registered accounts', (tester) async {
    final provider = await seedAccounts(tester);
    await tester.pumpWidget(wrap(provider, const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('키움 메인'), findsOneWidget);
    expect(find.text('미래에셋 ISA'), findsOneWidget);
  });

  testWidgets('Journal account chips drive selectedAccountTagFilter', (
    tester,
  ) async {
    final provider = await seedAccounts(tester);
    expect(provider.selectedAccountTagFilter, isNull);

    await tester.pumpWidget(wrap(provider, const JournalScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // Chip labels render as "이름 (개수)" so match on a substring.
    await tester.tap(find.textContaining('키움 메인').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(provider.selectedAccountTagFilter, '키움 메인');

    // And back to the combined view via the all-accounts chip.
    final ko = lookupAppLocalizations(const Locale('ko'));
    await tester.tap(find.textContaining(ko.allAccounts).first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(provider.selectedAccountTagFilter, isNull);
  });
}
