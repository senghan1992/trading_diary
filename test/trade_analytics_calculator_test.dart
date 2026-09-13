// Unit tests for the pure-functional aggregation engine
// (TradeAnalyticsCalculator).
//
// What we exercise:
//   • Empty input: every KPI collapses to a safe zero/null
//   • Mixed wins + losses: KPI math is correct
//   • Breakeven trades count in the win-rate denominator but NOT the
//     numerator (preserves the contract documented in
//     TradeAnalyticsCalculator)
//   • Period filtering: 1y/6m/1m/1w buckets correctly drop older trades
//   • Per-stock aggregation: per-symbol totals and win rates are right
//   • Per-weekday / per-month: bucketing logic matches entry/exit date
//
// These tests do not spin up a widget tree; they call into the
// static functions directly with hand-built TradeEntry fixtures.

import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/models/stock.dart';
import 'package:trading_diary/models/trade_analytics.dart';
import 'package:trading_diary/models/trade_entry.dart';
import 'package:trading_diary/providers/trade_provider.dart' show TradeFilter;
import 'package:trading_diary/services/trade_analytics_calculator.dart';

TradeEntry _trade({
  required String id,
  required String symbol,
  required TradeResult result,
  required double entryPrice,
  required double exitPrice,
  required TradeDirection direction,
  required DateTime entryDate,
  required DateTime exitDate,
  int quantity = 1,
  MarketType market = MarketType.kospi,
  TradeType type = TradeType.real,
  String? strategy,
  String? accountTag,
}) {
  return TradeEntry(
    id: id,
    stockSymbol: symbol,
    stockName: symbol,
    market: market,
    type: type,
    direction: direction,
    entryPrice: entryPrice,
    exitPrice: exitPrice,
    quantity: quantity,
    entryDate: entryDate,
    exitDate: exitDate,
    strategy: strategy,
    accountTag: accountTag,
    result: result,
    isClosed: true,
  );
}

TradeEntry _open({
  required String id,
  required String symbol,
  required DateTime entryDate,
  double entryPrice = 100,
  int quantity = 1,
}) {
  return TradeEntry(
    id: id,
    stockSymbol: symbol,
    stockName: symbol,
    market: MarketType.kospi,
    type: TradeType.real,
    direction: TradeDirection.buy,
    entryPrice: entryPrice,
    exitPrice: null,
    quantity: quantity,
    entryDate: entryDate,
    exitDate: null,
    result: TradeResult.pending,
    isClosed: false,
  );
}

void main() {
  group('TradeAnalyticsCalculator.computeSummary', () {
    test('empty list produces safe zeros and null best/worst', () {
      final s = TradeAnalyticsCalculator.computeSummary(
        const [],
        const TradeAnalyticsFilter(),
      );
      expect(s.totalTrades, 0);
      expect(s.winningTrades, 0);
      expect(s.losingTrades, 0);
      expect(s.breakevenTrades, 0);
      expect(s.winRate, 0);
      expect(s.totalProfitLoss, 0);
      expect(s.profitFactor, 0);
      expect(s.payoffRatio, 0);
      expect(s.averageHoldingDays, 0);
      expect(s.longestWinStreak, 0);
      expect(s.longestLossStreak, 0);
      expect(s.bestTrade, isNull);
      expect(s.worstTrade, isNull);
      expect(s.openPositionsCount, 0);
      expect(s.totalInvested, 0);
    });

    test('mixed wins/losses produce correct KPIs', () {
      final now = DateTime.now();
      final t1 = _trade(
        id: 't1',
        symbol: 'AAPL',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 150,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 10)),
        exitDate: now.subtract(const Duration(days: 5)),
        quantity: 10,
      );
      final t2 = _trade(
        id: 't2',
        symbol: 'AAPL',
        result: TradeResult.failure,
        entryPrice: 200,
        exitPrice: 150,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 8)),
        exitDate: now.subtract(const Duration(days: 3)),
        quantity: 5,
      );

      final s = TradeAnalyticsCalculator.computeSummary([
        t1,
        t2,
      ], const TradeAnalyticsFilter());

      expect(s.totalTrades, 2);
      expect(s.winningTrades, 1);
      expect(s.losingTrades, 1);
      // 1 win out of 2 closed = 50%.
      expect(s.winRate, 50);
      expect(s.totalProfitLoss, closeTo(500 + -250, 0.001));
      // grossWins=500, grossLosses=-250 → averageWin=500, averageLoss=250 → payoffRatio=2.0
      expect(s.payoffRatio, closeTo(2.0, 0.001));
      expect(s.averageWin, closeTo(500, 0.001));
      expect(s.averageLoss, closeTo(250, 0.001));
      // 1000 invested (t1) + 1000 invested (t2) = 2000, profit 250 → 12.5%.
      expect(s.totalReturnPercent, closeTo(12.5, 0.001));
      expect(s.bestTrade?.id, 't1');
      expect(s.worstTrade?.id, 't2');
    });

    test('breakeven counts in denominator only', () {
      final now = DateTime.now();
      final tWin = _trade(
        id: 'win',
        symbol: 'A',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: now,
        exitDate: now,
      );
      final tBreakeven = _trade(
        id: 'be',
        symbol: 'B',
        result: TradeResult.breakeven,
        entryPrice: 100,
        exitPrice: 100,
        direction: TradeDirection.buy,
        entryDate: now,
        exitDate: now,
      );
      final s = TradeAnalyticsCalculator.computeSummary([
        tWin,
        tBreakeven,
      ], const TradeAnalyticsFilter());
      expect(s.totalTrades, 2);
      expect(s.winningTrades, 1);
      expect(s.breakevenTrades, 1);
      expect(s.winRate, 50);
    });

    test('profitFactor caps at max ratio when wins without losses', () {
      final now = DateTime.now();
      final t1 = _trade(
        id: 't1',
        symbol: 'A',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: now,
        exitDate: now,
      );
      final s = TradeAnalyticsCalculator.computeSummary([
        t1,
      ], const TradeAnalyticsFilter());
      expect(s.profitFactor, 99.9);
    });

    test('open positions are counted separately and excluded from P&L', () {
      final now = DateTime.now();
      final closed = _trade(
        id: 'c',
        symbol: 'A',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 5)),
        exitDate: now.subtract(const Duration(days: 2)),
      );
      final open = _open(
        id: 'o',
        symbol: 'B',
        entryDate: now.subtract(const Duration(days: 1)),
        entryPrice: 100,
        quantity: 3,
      );
      final s = TradeAnalyticsCalculator.computeSummary([
        closed,
        open,
      ], const TradeAnalyticsFilter());
      expect(s.totalTrades, 1);
      expect(s.openPositionsCount, 1);
      // 100 (closed) + 300 (open) = 400 invested.
      expect(s.totalInvested, closeTo(400, 0.001));
    });
  });

  group('TradeAnalyticsCalculator.applyFilter', () {
    test('1-week filter drops trades exited more than 7 days ago', () {
      final now = DateTime.now();
      final old = _trade(
        id: 'old',
        symbol: 'A',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 30)),
        exitDate: now.subtract(const Duration(days: 25)),
      );
      final recent = _trade(
        id: 'recent',
        symbol: 'B',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 4)),
        exitDate: now.subtract(const Duration(days: 1)),
      );
      final scope = TradeAnalyticsCalculator.applyFilter([
        old,
        recent,
      ], const TradeAnalyticsFilter(period: TimePeriodFilter.week1));
      expect(scope.closedInScope.length, 1);
      expect(scope.closedInScope.single.id, 'recent');
    });

    test('market filter scopes to the requested market only', () {
      final now = DateTime.now();
      final kr = _trade(
        id: 'kr',
        symbol: '005930',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 1)),
        exitDate: now,
        market: MarketType.kospi,
      );
      final us = _trade(
        id: 'us',
        symbol: 'AAPL',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 1)),
        exitDate: now,
        market: MarketType.nasdaq,
      );
      final scope = TradeAnalyticsCalculator.applyFilter([
        kr,
        us,
      ], const TradeAnalyticsFilter(market: MarketType.kospi));
      expect(scope.closedInScope.length, 1);
      expect(scope.closedInScope.single.id, 'kr');
    });

    test('account-type filter scopes real vs virtual', () {
      final now = DateTime.now();
      final real = _trade(
        id: 'real',
        symbol: 'A',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: now,
        exitDate: now,
        type: TradeType.real,
      );
      final virt = _trade(
        id: 'virt',
        symbol: 'B',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: now,
        exitDate: now,
        type: TradeType.virtual,
      );
      final scope = TradeAnalyticsCalculator.applyFilter([
        real,
        virt,
      ], const TradeAnalyticsFilter(tradeType: TradeFilter.virtual));
      expect(scope.closedInScope.length, 1);
      expect(scope.closedInScope.single.id, 'virt');
    });
  });

  group('TradeAnalyticsCalculator.computeStockPerformance', () {
    test('aggregates per-symbol totals sorted by P&L descending', () {
      final now = DateTime.now();
      // Two wins for AAPL → big profit; one loss for TSLA → loss.
      final a1 = _trade(
        id: 'a1',
        symbol: 'AAPL',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 120,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 3)),
        exitDate: now.subtract(const Duration(days: 1)),
        quantity: 5,
      );
      final a2 = _trade(
        id: 'a2',
        symbol: 'AAPL',
        result: TradeResult.success,
        entryPrice: 200,
        exitPrice: 250,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 4)),
        exitDate: now.subtract(const Duration(days: 2)),
        quantity: 2,
      );
      final t1 = _trade(
        id: 't1',
        symbol: 'TSLA',
        result: TradeResult.failure,
        entryPrice: 300,
        exitPrice: 200,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 3)),
        exitDate: now.subtract(const Duration(days: 1)),
      );
      final rows = TradeAnalyticsCalculator.computeStockPerformance([
        a1,
        a2,
        t1,
      ], const TradeAnalyticsFilter());
      expect(rows.length, 2);
      expect(rows.first.stockSymbol, 'AAPL');
      expect(rows.first.tradeCount, 2);
      expect(rows.first.winCount, 2);
      expect(rows.first.totalProfitLoss, closeTo(200, 0.001));
      expect(rows.last.stockSymbol, 'TSLA');
    });
  });

  group('TradeAnalyticsCalculator.computeWeekdayPerformance', () {
    test('returns 7 rows even when some days are empty', () {
      final rows = TradeAnalyticsCalculator.computeWeekdayPerformance(
        const [],
        const TradeAnalyticsFilter(),
      );
      expect(rows.length, 7);
      for (final r in rows) {
        expect(r.tradeCount, 0);
      }
    });

    test('trades bucket under exit weekday', () {
      // Pick a known Monday: 2024-01-01 was a Monday.
      final mondayExit = DateTime(2024, 1, 1);
      final t = _trade(
        id: 'mon',
        symbol: 'A',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: DateTime(2023, 12, 29),
        exitDate: mondayExit,
      );
      final rows = TradeAnalyticsCalculator.computeWeekdayPerformance([
        t,
      ], const TradeAnalyticsFilter(period: TimePeriodFilter.all));
      final monday = rows.firstWhere((r) => r.weekday == DateTime.monday);
      expect(monday.tradeCount, 1);
      expect(monday.totalProfitLoss, closeTo(10, 0.001));
    });
  });

  group('TradeAnalyticsCalculator.computeMonthlyPnL', () {
    test('groups by exit (year, month) and orders chronologically', () {
      final t1 = _trade(
        id: '1',
        symbol: 'A',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: DateTime(2024, 1, 15),
        exitDate: DateTime(2024, 1, 20),
      );
      final t2 = _trade(
        id: '2',
        symbol: 'A',
        result: TradeResult.failure,
        entryPrice: 100,
        exitPrice: 90,
        direction: TradeDirection.buy,
        entryDate: DateTime(2024, 2, 1),
        exitDate: DateTime(2024, 2, 5),
      );
      final t3 = _trade(
        id: '3',
        symbol: 'A',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 105,
        direction: TradeDirection.buy,
        entryDate: DateTime(2024, 1, 10),
        exitDate: DateTime(2024, 1, 25),
      );
      final rows = TradeAnalyticsCalculator.computeMonthlyPnL([
        t1,
        t2,
        t3,
      ], const TradeAnalyticsFilter());
      expect(rows.length, 2);
      expect(rows[0].year, 2024);
      expect(rows[0].month, 1);
      expect(rows[0].profitLoss, closeTo(15, 0.001));
      expect(rows[0].tradeCount, 2);
      expect(rows[1].month, 2);
      expect(rows[1].profitLoss, closeTo(-10, 0.001));
    });
  });

  group('TradeAnalyticsCalculator.computeCumulativePnL', () {
    test('cumulative running total reflects chronological order', () {
      final t1 = _trade(
        id: '1',
        symbol: 'A',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: DateTime(2024, 1, 10),
        exitDate: DateTime(2024, 1, 10),
      );
      final t2 = _trade(
        id: '2',
        symbol: 'B',
        result: TradeResult.failure,
        entryPrice: 100,
        exitPrice: 90,
        direction: TradeDirection.buy,
        entryDate: DateTime(2024, 1, 15),
        exitDate: DateTime(2024, 1, 15),
      );
      final pts = TradeAnalyticsCalculator.computeCumulativePnL([
        t1,
        t2,
      ], const TradeAnalyticsFilter());
      expect(pts.length, 2);
      expect(pts[0].cumulativePnL, closeTo(10, 0.001));
      expect(pts[1].cumulativePnL, closeTo(0, 0.001));
    });
  });

  group('TradeAnalyticsCalculator.computeStrategyPerformance', () {
    test('null strategies bucket under the sentinel and count rows', () {
      final now = DateTime.now();
      final t1 = _trade(
        id: '1',
        symbol: 'A',
        result: TradeResult.success,
        entryPrice: 100,
        exitPrice: 110,
        direction: TradeDirection.buy,
        entryDate: now,
        exitDate: now,
        strategy: 'swing',
      );
      final t2 = _trade(
        id: '2',
        symbol: 'B',
        result: TradeResult.failure,
        entryPrice: 100,
        exitPrice: 90,
        direction: TradeDirection.buy,
        entryDate: now,
        exitDate: now,
        // strategy omitted → null
      );
      final rows = TradeAnalyticsCalculator.computeStrategyPerformance([
        t1,
        t2,
      ], const TradeAnalyticsFilter());
      expect(rows.length, 2);
      expect(
        rows.map((r) => r.strategyName).toSet(),
        containsAll(['swing', '(미분류)']),
      );
    });
  });

  group('computeAccountPerformance', () {
    final now = DateTime.now();
    TradeEntry closed({
      required String id,
      required double entry,
      required double exit,
      String? tag,
    }) {
      return _trade(
        id: id,
        symbol: 'TEST$id',
        result: exit > entry ? TradeResult.success : TradeResult.failure,
        entryPrice: entry,
        exitPrice: exit,
        direction: TradeDirection.buy,
        entryDate: now.subtract(const Duration(days: 5)),
        exitDate: now.subtract(const Duration(days: 1)),
        quantity: 10,
        accountTag: tag,
      );
    }

    test('groups trades by account tag with correct P&L and win rate', () {
      final aWin = closed(id: 'a1', entry: 100, exit: 120, tag: '키움');
      final aLoss = closed(id: 'a2', entry: 100, exit: 90, tag: '키움');
      final bWin = closed(id: 'b1', entry: 100, exit: 130, tag: '토스');

      final rows = TradeAnalyticsCalculator.computeAccountPerformance([
        aWin,
        aLoss,
        bWin,
      ], const TradeAnalyticsFilter());

      expect(rows.length, 2);
      // Sorted by totalProfitLoss descending.
      expect(rows.first.accountName, '토스');
      expect(rows.first.totalProfitLoss, 300);
      expect(rows.first.winRate, 100);
      final kiwoom = rows.last;
      expect(kiwoom.accountName, '키움');
      expect(kiwoom.totalProfitLoss, 100);
      expect(kiwoom.tradeCount, 2);
      expect(kiwoom.winCount, 1);
      expect(kiwoom.lossCount, 1);
      expect(kiwoom.winRate, closeTo(50, 0.001));
      expect(kiwoom.bestTrade!.id, 'a1');
      expect(kiwoom.worstTrade!.id, 'a2');
    });

    test('unassigned trades are bucketed under the sentinel, not dropped', () {
      final tagged = closed(id: 't1', entry: 100, exit: 110, tag: '키움');
      final orphan = closed(id: 'o1', entry: 100, exit: 105, tag: null);

      final rows = TradeAnalyticsCalculator.computeAccountPerformance([
        tagged,
        orphan,
      ], const TradeAnalyticsFilter());

      expect(rows.length, 2);
      expect(
        rows.map((r) => r.accountName),
        containsAll(['키움', kUnassignedAccount]),
      );
    });

    test('accountTag filter narrows to exactly one bucket', () {
      final t1 = closed(id: 'x1', entry: 100, exit: 120, tag: '키움');
      final t2 = closed(id: 'x2', entry: 100, exit: 80, tag: '토스');

      final rows = TradeAnalyticsCalculator.computeAccountPerformance([
        t1,
        t2,
      ], const TradeAnalyticsFilter(accountTag: '키움'));

      expect(rows.length, 1);
      expect(rows.single.accountName, '키움');
      expect(rows.single.totalProfitLoss, 200);
    });

    test('open positions count per account and count towards invested', () {
      final openA = _open(
        id: 'oa',
        symbol: 'OPENA',
        entryDate: now.subtract(const Duration(days: 1)),
        quantity: 2,
      );
      final openTagged = _open(
        id: 'ob',
        symbol: 'OPENB',
        entryDate: now.subtract(const Duration(days: 1)),
        quantity: 3,
      ).withAccountTag('키움');

      final rows = TradeAnalyticsCalculator.computeAccountPerformance([
        closed(id: 'c1', entry: 100, exit: 110, tag: '키움'),
        openA,
        openTagged,
      ], const TradeAnalyticsFilter());

      final unassigned = rows
          .where((r) => r.accountName == kUnassignedAccount)
          .single;
      expect(unassigned.openPositionCount, 1);
      final kiwoom = rows.where((r) => r.accountName == '키움').single;
      expect(kiwoom.openPositionCount, 1);
      // Open position capital counts towards invested but not realised P&L.
      expect(unassigned.totalInvested, 200);
      expect(unassigned.totalProfitLoss, 0);
    });
  });
}
