// Tests for the calendar day-entries mapper and marker color helper
// extracted from `review_screen.dart`.
//
// What we exercise:
//   • Entry-only (open position) trades DO contribute to their entry day
//   • Closed trades contribute to BOTH the entry day and exit day, so the
//     user sees the calendar "lit up" on both days (not just the close)
//   • Marker color follows the documented win/loss/neutral rules
//
// Why this matters: the previous bug report was "복습 캘린더에 작성한 내용이
// 안 보인다" — only exit dates were mapped. The entries list below the
// calendar was technically populated, but the marker dots on the calendar
// yet closed.

import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/models/stock.dart';
import 'package:trading_diary/screens/review_screen.dart';
import 'package:trading_diary/theme/app_theme.dart';

TradeEntry _open({
  required String id,
  required DateTime entryDate,
  double entryPrice = 100,
  int quantity = 1,
}) {
  return TradeEntry(
    id: id,
    stockSymbol: 'TEST',
    stockName: 'Test',
    market: MarketType.kospi,
    type: TradeType.real,
    direction: TradeDirection.buy,
    entryPrice: entryPrice,
    exitPrice: null,
    quantity: quantity,
    entryDate: entryDate,
    exitDate: null,
    reason: null,
    strategy: null,
    result: TradeResult.pending,
    isClosed: false,
  );
}

TradeEntry _closed({
  required String id,
  required DateTime entryDate,
  required DateTime exitDate,
  required double entryPrice,
  required double exitPrice,
  int quantity = 1,
}) {
  return TradeEntry(
    id: id,
    stockSymbol: 'TEST',
    stockName: 'Test',
    market: MarketType.kospi,
    type: TradeType.real,
    direction: TradeDirection.buy,
    entryPrice: entryPrice,
    exitPrice: exitPrice,
    quantity: quantity,
    entryDate: entryDate,
    exitDate: exitDate,
    reason: null,
    strategy: null,
    result: exitPrice >= entryPrice ? TradeResult.success : TradeResult.failure,
    isClosed: true,
  );
}

void main() {
  group('buildDayEntriesMapForReview — date mapping', () {
    test('an entry-only (open) trade appears on its ENTRY day', () {
      final entryDate = DateTime(2025, 3, 10, 14, 30);
      final trades = [_open(id: 'o1', entryDate: entryDate)];
      final map = buildDayEntriesMapForReview(trades);
      // The map should have an entry for the day-of-entry, time-zeroed.
      final day = DateTime(2025, 3, 10);
      expect(
        map.containsKey(day),
        isTrue,
        reason:
            'open position should map to its entry day so the '
            'review calendar shows the marker',
      );
      expect(map[day]!.length, 1);
      expect(map[day]!.first.id, 'o1');
    });

    test('a closed trade appears on BOTH entry and exit day', () {
      // Monday entry, Friday exit — different days.
      final monday = DateTime(2025, 3, 10);
      final friday = DateTime(2025, 3, 14);
      final trades = [
        _closed(
          id: 'c1',
          entryDate: monday,
          exitDate: friday,
          entryPrice: 100,
          exitPrice: 110,
        ),
      ];
      final map = buildDayEntriesMapForReview(trades);
      expect(
        map[DateTime(2025, 3, 10)]!.length,
        1,
        reason: 'closed trade should also light up the entry day',
      );
      expect(
        map[DateTime(2025, 3, 14)]!.length,
        1,
        reason: 'closed trade should light up the exit day',
      );
      expect(map[DateTime(2025, 3, 10)]!.first.id, 'c1');
      expect(map[DateTime(2025, 3, 14)]!.first.id, 'c1');
    });

    test(
      'intra-day trade (entered and exited on the same day) is mapped once',
      () {
        final day = DateTime(2025, 3, 10);
        final trades = [
          _closed(
            id: 'd1',
            entryDate: day.add(const Duration(hours: 9, minutes: 30)),
            exitDate: day.add(const Duration(hours: 15, minutes: 0)),
            entryPrice: 100,
            exitPrice: 105,
          ),
        ];
        final map = buildDayEntriesMapForReview(trades);
        expect(
          map[day]!.length,
          1,
          reason:
              'intra-day trade should not double-count on the same '
              'calendar day — the original double-counting bug produced '
              'a marker that flicked between green and red on the same '
              'day and confused the win-rate aggregate',
        );
      },
    );

    test('empty input produces empty map', () {
      final map = buildDayEntriesMapForReview(const []);
      expect(map, isEmpty);
    });
  });

  group('reviewDayMarkerColor — coloring rules', () {
    test('no entries → null marker (no dot on calendar)', () {
      expect(reviewDayMarkerColor(const []), isNull);
    });

    test('only open/pending trades → indigo "neutral" marker', () {
      final dayEntries = [_open(id: 'p1', entryDate: DateTime(2025, 3, 10))];
      expect(
        reviewDayMarkerColor(dayEntries),
        AppColors.markerNeutral,
        reason:
            'pending positions are intentionally not coloured as win/'
            'loss — they read as "open / in progress" instead',
      );
    });

    test('closed trade with positive P&L → markerWin (emerald)', () {
      final dayEntries = [
        _closed(
          id: 'w1',
          entryDate: DateTime(2025, 3, 10),
          exitDate: DateTime(2025, 3, 14),
          entryPrice: 100,
          exitPrice: 120, // +20%
        ),
      ];
      expect(reviewDayMarkerColor(dayEntries), AppColors.markerWin);
    });

    test('closed trade with negative P&L → markerLoss (rose)', () {
      final dayEntries = [
        _closed(
          id: 'l1',
          entryDate: DateTime(2025, 3, 10),
          exitDate: DateTime(2025, 3, 14),
          entryPrice: 100,
          exitPrice: 80, // -20%
        ),
      ];
      expect(reviewDayMarkerColor(dayEntries), AppColors.markerLoss);
    });

    test('mix of profit and loss → net positive wins (markerWin)', () {
      // Day has both; the marker reflects net direction, not count.
      final dayEntries = [
        _closed(
          id: 'w',
          entryDate: DateTime(2025, 3, 10),
          exitDate: DateTime(2025, 3, 14),
          entryPrice: 100,
          exitPrice: 150,
        ),
        _closed(
          id: 'l',
          entryDate: DateTime(2025, 3, 10),
          exitDate: DateTime(2025, 3, 14),
          entryPrice: 100,
          exitPrice: 90,
        ),
      ];
      expect(reviewDayMarkerColor(dayEntries), AppColors.markerWin);
    });

    test('breakeven closed trade (PnL == 0) → markerNeutral', () {
      final dayEntries = [
        _closed(
          id: 'b',
          entryDate: DateTime(2025, 3, 10),
          exitDate: DateTime(2025, 3, 14),
          entryPrice: 100,
          exitPrice: 100,
        ),
      ];
      expect(reviewDayMarkerColor(dayEntries), AppColors.markerNeutral);
    });
  });
}
