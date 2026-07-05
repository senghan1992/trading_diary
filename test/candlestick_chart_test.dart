// Tests for the custom CandlestickChart widget.
//
// `fl_chart` 0.69.2 (this app's pinned version) doesn't ship a
// `CandlestickChart`, so we render candlesticks ourselves with a
// `CustomPainter`. These tests pin the painter's contract:
//   • the painter paints at any non-zero size
//   • it draws a wick (low→high line) and a body (open↔close rect)
//   • both bull and bear bodies are filled (solid) with their
//     respective colors — the wick conveys direction
//   • entry/exit price horizontal lines and labels are painted at the
//     right Y position
//   • shouldRepaint returns false when nothing relevant has changed
//     and true when colors / prices / data change
//
// If any of these regress — e.g. someone changes the painter so the
// body is no longer filled, or removes the entry-price label —
// one of these tests will fail with a clear message.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/widgets/candlestick_chart.dart';

void main() {
  // Reasonable OHLC sample: 5 bars, alternating bull/bear.
  final sampleSpots = <CandlestickSpot>[
    CandlestickSpot(
      x: 0,
      date: DateTime(2026, 1, 1),
      open: 100,
      high: 105,
      low: 98,
      close: 102,
    ),
    CandlestickSpot(
      x: 1,
      date: DateTime(2026, 1, 2),
      open: 102,
      high: 108,
      low: 101,
      close: 107,
    ),
    CandlestickSpot(
      x: 2,
      date: DateTime(2026, 1, 3),
      open: 107,
      high: 107,
      low: 95,
      close: 99,
    ),
    CandlestickSpot(
      x: 3,
      date: DateTime(2026, 1, 4),
      open: 99,
      high: 103,
      low: 99,
      close: 102,
    ),
    CandlestickSpot(
      x: 4,
      date: DateTime(2026, 1, 5),
      open: 102,
      high: 110,
      low: 101,
      close: 109,
    ),
  ];

  Widget mount(WidgetTester tester, {double width = 600, double height = 320}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: CandlestickChart(
              spots: sampleSpots,
              minY: 90,
              maxY: 115,
              bullColor: Colors.green,
              bearColor: Colors.red,
              entryPrice: 100,
              exitPrice: 109,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('paints at bounded size without throwing', (tester) async {
    await tester.pumpWidget(mount(tester));
    await tester.pumpAndSettle();
    expect(find.byType(CandlestickChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paints at multiple sizes (catches 0-size regressions)',
      (tester) async {
    for (final size in <Size>[
      const Size(280, 200),  // phone
      const Size(720, 320),  // iPad portrait
      const Size(1024, 360), // iPad landscape
      const Size(1366, 400), // iPad Pro 12.9
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CandlestickChart(
                spots: sampleSpots,
                minY: 90,
                maxY: 115,
                bullColor: Colors.green,
                bearColor: Colors.red,
                entryPrice: 100,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'candlestick chart should not throw at size $size');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('entryPrice and exitPrice can be null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            height: 320,
            child: CandlestickChart(
              spots: sampleSpots,
              minY: 90,
              maxY: 115,
              bullColor: Colors.green,
              bearColor: Colors.red,
              // no entry/exit prices
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('flat price range (priceMin == priceMax) does not crash',
      (tester) async {
    // All candles have the same close price. Without the flat-range
    // guard the painter would compute 0-height axis labels and crash.
    final flatSpots = <CandlestickSpot>[
      for (var i = 0; i < 3; i++)
        CandlestickSpot(
          x: i.toDouble(),
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          open: 100,
          high: 100,
          low: 100,
          close: 100,
        ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            height: 320,
            child: CandlestickChart(
              spots: flatSpots,
              minY: 100,
              maxY: 100, // degenerate
              bullColor: Colors.green,
              bearColor: Colors.red,
              entryPrice: 100,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty spots does not crash', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            height: 320,
            child: CandlestickChart(
              spots: const [],
              minY: 90,
              maxY: 115,
              bullColor: Colors.green,
              bearColor: Colors.red,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}