// Widget tests for TradeVisualizerCard — the input-data-only
// visualization card that replaced the external-API candlestick chart in
// the trade detail screen.
//
// What we exercise:
//   • Winning trade → gauge fill uses upColor, positive P/L badge texts
//   • Losing trade  → gauge fill uses downColor, negative P/L badge texts
//   • Open position → no gauge, '—' placeholders, holding-days chip still
//     rendered from entry date → now
//   • Holding-period phrase (heldForDaysFormat) with exact day counts
//
// The card is pure: it reads only its constructor arguments plus l10n, so
// no Hive / SharedPreferences / network mocking is required.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/l10n/app_localizations.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/models/stock.dart';
import 'package:trading_diary/widgets/trade_detail_screen.dart';

const _up = Color(0xFF16A34A);
const _down = Color(0xFFDC2626);

TradeEntry _trade({
  double entry = 100,
  double? exit,
  int qty = 100,
  bool closed = false,
  DateTime? entryDate,
  DateTime? exitDate,
  String? accountTag,
}) {
  return TradeEntry(
    id: 't1',
    stockSymbol: 'AAPL',
    stockName: 'Apple',
    type: TradeType.real,
    direction: TradeDirection.buy,
    entryPrice: entry,
    exitPrice: exit,
    quantity: qty,
    entryDate: entryDate ?? DateTime(2026, 1, 1),
    exitDate: exitDate,
    isClosed: closed,
    market: MarketType.nasdaq,
    accountTag: accountTag,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Future<void> _pump(
  WidgetTester tester,
  TradeEntry trade, {
  String? accountTag,
  Color? accountColor,
}) async {
  await tester.pumpWidget(
    _wrap(
      TradeVisualizerCard(
        trade: trade,
        upColor: _up,
        downColor: _down,
        accountTag: accountTag,
        accountColor: accountColor,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _gaugeFillColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byKey(const ValueKey('visualizer_gauge_fill')),
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('Winning trade fills gauge with upColor and shows positive P/L', (
    tester,
  ) async {
    // Buy 100 @ $100, sell @ $125 → +$2,500 (+25.00%).
    await _pump(
      tester,
      _trade(
        entry: 100,
        exit: 125,
        closed: true,
        entryDate: DateTime(2026, 1, 1),
        exitDate: DateTime(2026, 1, 11),
      ),
      accountTag: '키움 메인',
      accountColor: const Color(0xFF02A9EA),
    );

    expect(find.byKey(const ValueKey('visualizer_gauge_fill')), findsOneWidget);
    expect(
      _gaugeFillColor(tester),
      _up,
      reason: 'a profitable trade must fill the gauge with upColor',
    );

    expect(find.text(r'+$2,500.00'), findsOneWidget);
    expect(find.text('+25.00%'), findsOneWidget);

    // Invested capital vs recovered amount.
    expect(find.text(r'$10,000.00'), findsOneWidget); // 100 × 100
    expect(find.text(r'$12,500.00'), findsOneWidget); // 125 × 100

    // Price labels for both ends of the movement.
    expect(find.text(r'$100.00'), findsOneWidget);
    expect(find.text(r'$125.00'), findsOneWidget);

    // Held exactly 10 days (Jan 1 → Jan 11).
    expect(find.text('Held for 10 days'), findsOneWidget);

    // Account tag badge with the brand color dot.
    expect(find.text('키움 메인'), findsOneWidget);
    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('visualizer_account_dot')),
    );
    expect((dot.decoration as BoxDecoration).color, const Color(0xFF02A9EA));
  });

  testWidgets(
    'Losing trade fills gauge with downColor and shows negative P/L',
    (tester) async {
      // Buy 100 @ $120, sell @ $90 → -$3,000 (-25.00%).
      await _pump(
        tester,
        _trade(
          entry: 120,
          exit: 90,
          closed: true,
          entryDate: DateTime(2026, 2, 1),
          exitDate: DateTime(2026, 2, 21),
        ),
      );

      expect(
        _gaugeFillColor(tester),
        _down,
        reason: 'a losing trade must fill the gauge with downColor',
      );

      expect(find.text(r'-$3,000.00'), findsOneWidget);
      expect(find.text('-25.00%'), findsOneWidget);

      // Recovered amount is below invested capital.
      expect(find.text(r'$12,000.00'), findsOneWidget); // 120 × 100 invested
      expect(find.text(r'$9,000.00'), findsOneWidget); // 90 × 100 recovered
    },
  );

  testWidgets(
    'Open position renders entry-only view with em-dash placeholders',
    (tester) async {
      await _pump(
        tester,
        _trade(entry: 100, closed: false, entryDate: DateTime.now()),
      );

      // No price-movement gauge for an open position.
      expect(find.byKey(const ValueKey('visualizer_gauge_fill')), findsNothing);

      // Recovered amount and unrealized P/L collapse to '—'.
      expect(find.text('—'), findsNWidgets(2));

      // Holding-days chip is still present (counted from entry to now).
      expect(find.textContaining('Held for'), findsOneWidget);
    },
  );
}
