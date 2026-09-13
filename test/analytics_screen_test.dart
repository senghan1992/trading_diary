// Widget tests for AnalyticsScreen.
//
// What we exercise:
//   • Renders without throwing given an empty TradeProvider
//   • Renders KPI cards when trades exist
//   • Switches between Overview and Calendar tabs
//
// The screen consumes TradeProvider and ThemeProvider via Provider; we
// inject in-memory instances directly into the widget tree so we don't
// need Hive init or any platform plugin.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trading_diary/l10n/app_localizations.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/providers/theme_provider.dart';
import 'package:trading_diary/providers/trade_provider.dart';
import 'package:trading_diary/screens/analytics_screen.dart';
import 'package:trading_diary/widgets/ad_banner.dart';
import 'package:trading_diary/theme/app_theme.dart';

class _FakeTradeProvider extends TradeProvider {
  _FakeTradeProvider(this._customTrades);
  final List<TradeEntry> _customTrades;

  @override
  List<TradeEntry> get trades => _customTrades;

  @override
  void loadTrades() {}

  @override
  void loadAccounts() {}
}

Widget _wrap(Widget child, [TradeProvider? tradeProvider]) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TradeProvider>(
        create: (_) => tradeProvider ?? TradeProvider(),
      ),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('AnalyticsScreen renders without throwing on empty data', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AnalyticsScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsScreen), findsOneWidget);
  });

  testWidgets('TabBarView exposes Overview + Calendar tabs', (tester) async {
    await tester.pumpWidget(_wrap(const AnalyticsScreen()));
    await tester.pumpAndSettle();
    // Both labels should be in the widget tree, regardless of which tab
    // is currently visible.
    expect(find.textContaining('Overview'), findsWidgets);
    expect(find.textContaining('Calendar'), findsWidgets);
  });

  testWidgets(
    'Advertising is not embedded in the screen — it anchors in the shell footer',
    (tester) async {
      await tester.pumpWidget(_wrap(const AnalyticsScreen()));
      await tester.pumpAndSettle();

      // Ads no longer live inside content screens. They were moved to a
      // single quiet footer slot in MainShell, directly above the
      // bottom navigation bar, so content is never pushed down or
      // interrupted by an ad.
      expect(
        find.byType(AdBanner),
        findsNothing,
        reason: 'AnalyticsScreen must not mount its own AdBanner',
      );

      // Switching tabs keeps it clean too: no ad mounts inside the tab
      // views or the calendar panel.
      await tester.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.textContaining('Calendar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdBanner), findsNothing);
    },
  );

  testWidgets('Smart dashboard renders hero KPIs, toggles charts and deep dive tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final fakeTrades = [
      TradeEntry(
        id: 't1',
        stockSymbol: '005930',
        stockName: '삼성전자',
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 70000,
        exitPrice: 77000,
        quantity: 10,
        entryDate: now.subtract(const Duration(days: 5)),
        exitDate: now.subtract(const Duration(days: 1)),
        result: TradeResult.success,
        isClosed: true,
      ),
      TradeEntry(
        id: 't2',
        stockSymbol: '035420',
        stockName: 'NAVER',
        type: TradeType.real,
        direction: TradeDirection.buy,
        entryPrice: 200000,
        exitPrice: 190000,
        quantity: 5,
        entryDate: now.subtract(const Duration(days: 4)),
        exitDate: now.subtract(const Duration(days: 2)),
        result: TradeResult.failure,
        isClosed: true,
      ),
    ];
    final provider = _FakeTradeProvider(fakeTrades);
    await tester.pumpWidget(_wrap(const AnalyticsScreen(), provider));
    await tester.pumpAndSettle();

    // Verify Highlights and Chart toggle
    expect(find.text('거래 하이라이트'), findsOneWidget);
    expect(find.text('누적'), findsOneWidget);
    expect(find.text('일별'), findsOneWidget);
    expect(find.text('월별'), findsOneWidget);

    // Toggle to daily chart
    await tester.tap(find.text('일별'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily_chart')), findsOneWidget);

    // Toggle to monthly chart
    await tester.tap(find.text('월별'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('monthly_chart')), findsOneWidget);

    // Toggle back to cumulative chart
    await tester.tap(find.text('누적'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cumulative_chart')), findsOneWidget);

    // Deep dive section and tabs
    expect(find.text('심층 분석'), findsOneWidget);
    expect(find.text('요일별 패턴'), findsOneWidget);

    // Switch to Weekday pattern tab
    await tester.tap(find.text('요일별 패턴'));
    await tester.pumpAndSettle();
  });
}
