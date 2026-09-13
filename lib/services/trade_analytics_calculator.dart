import '../models/trade_analytics.dart';
import '../models/trade_entry.dart';
import '../providers/trade_provider.dart' show TradeFilter;

/// Sentinel used to bucket trades that have no [TradeEntry.strategy]
/// set. Kept private to this file so the UI doesn't have to know the
/// underlying magic string — see [StrategyPerformanceSummary.strategyName].
const String _kUncategorisedStrategy = '(미분류)';

/// Sentinel bucket key for trades that have no [TradeEntry.accountTag].
/// Public so the UI can render a localized "미지정" label for it.
const String kUnassignedAccount = '(미지정)';

/// Pure-functional aggregation engine for the analytics screen.
///
/// Every public method is `static`, takes a [List<TradeEntry>] and a
/// [TradeAnalyticsFilter], and returns either a primitive KPI snapshot or
/// a pre-sorted list of dimension rows. No state lives on the calculator
/// so the UI can call into it from any `build` method without worrying
/// about lifecycle.
///
/// All methods share the same [applyFilter] pipeline so behaviour is
/// identical across KPIs, charts, and rankings — a chart can never
/// disagree with the KPI cards.
class TradeAnalyticsCalculator {
  /// Cap applied to division-by-zero metrics. Used both for
  /// [TradeAnalyticsSummary.profitFactor] and `payoffRatio` so the UI
  /// never has to handle `double.infinity`.
  static const double _maxRatio = 99.9;

  /// Resolves the lower bound (inclusive) for a period filter against
  /// the supplied "now". Exposed so tests can pin the window without
  /// monkey-patching the clock.
  static DateTime? periodStart(TimePeriodFilter period, DateTime now) {
    switch (period) {
      case TimePeriodFilter.all:
        return null;
      case TimePeriodFilter.year1:
        return now.subtract(const Duration(days: 365));
      case TimePeriodFilter.month6:
        return now.subtract(const Duration(days: 182));
      case TimePeriodFilter.month1:
        return now.subtract(const Duration(days: 30));
      case TimePeriodFilter.week1:
        return now.subtract(const Duration(days: 7));
    }
  }

  /// Applies the [filter] to [trades]. Trade-type filter is applied
  /// first, then period (using the trade's exit date when present, else
  /// entry date), then market (when supplied).
  ///
  /// Open positions are kept in a separate list because some KPIs (like
  /// [TradeAnalyticsSummary.openPositionsCount]) need them, while the
  /// P&L aggregation only operates on closed trades.
  static ({List<TradeEntry> closedInScope, List<TradeEntry> openInScope})
  applyFilter(List<TradeEntry> trades, TradeAnalyticsFilter filter) {
    final now = DateTime.now();
    final start = periodStart(filter.period, now);

    final closed = <TradeEntry>[];
    final open = <TradeEntry>[];
    for (final t in trades) {
      if (!_matchesTradeType(t, filter.tradeType)) continue;
      if (filter.market != null && t.market != filter.market) continue;
      if (filter.accountTag != null && t.accountTag != filter.accountTag) {
        continue;
      }

      if (!t.isClosed || t.exitDate == null) {
        // Open position — date-window applies to its entry date so the
        // user doesn't see "phantom" open positions created within the
        // window but with an entry date far outside it.
        final ref = t.entryDate;
        if (start != null && ref.isBefore(start)) continue;
        open.add(t);
        continue;
      }

      // Closed trade — window anchored on exit date so realised P&L
      // counts towards the bucket in which it actually happened.
      if (start != null && t.exitDate!.isBefore(start)) continue;
      closed.add(t);
    }
    return (closedInScope: closed, openInScope: open);
  }

  static bool _matchesTradeType(TradeEntry t, TradeFilter type) {
    switch (type) {
      case TradeFilter.all:
        return true;
      case TradeFilter.real:
        return t.type == TradeType.real;
      case TradeFilter.virtual:
        return t.type == TradeType.virtual;
    }
  }

  /// Computes the headline KPI snapshot. All derived metrics are
  /// recomputed from the filtered set so the snapshot is consistent
  /// with the dimension rows below.
  static TradeAnalyticsSummary computeSummary(
    List<TradeEntry> trades,
    TradeAnalyticsFilter filter,
  ) {
    final scope = applyFilter(trades, filter);
    final closed = scope.closedInScope;

    if (closed.isEmpty) {
      return TradeAnalyticsSummary(
        totalTrades: 0,
        winningTrades: 0,
        losingTrades: 0,
        breakevenTrades: 0,
        winRate: 0,
        totalProfitLoss: 0,
        totalReturnPercent: 0,
        profitFactor: 0,
        averageWin: 0,
        averageLoss: 0,
        payoffRatio: 0,
        averageHoldingDays: 0,
        longestWinStreak: 0,
        longestLossStreak: 0,
        bestTrade: null,
        worstTrade: null,
        openPositionsCount: scope.openInScope.length,
        totalInvested: _totalInvested(scope),
      );
    }

    var wins = 0;
    var losses = 0;
    var breakeven = 0;
    var grossWins = 0.0;
    var grossLosses = 0.0;
    TradeEntry? best;
    TradeEntry? worst;
    var totalHoldingDays = 0;
    var holdingCount = 0;

    for (final t in closed) {
      final pnl = t.profitLoss;
      if (pnl > 0) {
        wins++;
        grossWins += pnl;
      } else if (pnl < 0) {
        losses++;
        grossLosses += pnl; // negative
      } else {
        breakeven++;
      }

      if (best == null || pnl > best.profitLoss) best = t;
      if (worst == null || pnl < worst.profitLoss) worst = t;

      final exit = t.exitDate;
      if (exit != null) {
        final days = exit.difference(t.entryDate).inDays;
        // Clamp negative spans (entry > exit, which the provider
        // already sanitises but legacy data may not) to 0.
        totalHoldingDays += days < 0 ? 0 : days;
        holdingCount++;
      }
    }

    final totalTrades = closed.length;
    final winRate = totalTrades == 0 ? 0.0 : (wins / totalTrades) * 100;
    final totalInvested = _totalInvested(scope);
    final totalProfitLoss = grossWins + grossLosses;
    final returnPct = totalInvested == 0
        ? 0.0
        : (totalProfitLoss / totalInvested) * 100;

    final profitFactor = _safeRatio(grossWins, grossLosses);
    final payoffRatio = _safeRatio(
      wins == 0 ? 0.0 : grossWins / wins,
      losses == 0 ? 0.0 : (-grossLosses) / losses,
    );
    final avgWin = wins == 0 ? 0.0 : grossWins / wins;
    final avgLoss = losses == 0 ? 0.0 : (-grossLosses) / losses;
    final avgHolding = holdingCount == 0
        ? 0.0
        : totalHoldingDays / holdingCount;

    return TradeAnalyticsSummary(
      totalTrades: totalTrades,
      winningTrades: wins,
      losingTrades: losses,
      breakevenTrades: breakeven,
      winRate: winRate,
      totalProfitLoss: totalProfitLoss,
      totalReturnPercent: returnPct,
      profitFactor: profitFactor,
      averageWin: avgWin,
      averageLoss: avgLoss,
      payoffRatio: payoffRatio,
      averageHoldingDays: avgHolding,
      longestWinStreak: _longestStreak(closed, TradeResult.success),
      longestLossStreak: _longestStreak(closed, TradeResult.failure),
      bestTrade: best,
      worstTrade: worst,
      openPositionsCount: scope.openInScope.length,
      totalInvested: totalInvested,
    );
  }

  static double _totalInvested(
    ({List<TradeEntry> closedInScope, List<TradeEntry> openInScope}) scope,
  ) {
    var sum = 0.0;
    for (final t in scope.closedInScope) {
      sum += t.entryPrice * t.quantity;
    }
    for (final t in scope.openInScope) {
      sum += t.entryPrice * t.quantity;
    }
    return sum;
  }

  /// Returns `a / |b|` capped at [_maxRatio]. Handles the four corner
  /// cases (zero wins, zero losses, both zero, infinite) by collapsing
  /// to a UI-safe value.
  ///
  ///   - both zero       → 0 (no signal)
  ///   - wins only       → capped at _maxRatio ("∞" badge in UI)
  ///   - losses only     → 0 (no upside to compare)
  ///   - both positive   → raw ratio capped
  static double _safeRatio(double a, double b) {
    if (a == 0 && b == 0) return 0;
    if (b == 0) {
      // Infinite ratio; if a > 0 we have wins without losses, otherwise
      // we have losses without wins which is 0 from the upside angle.
      return a > 0 ? _maxRatio : 0;
    }
    final r = a / b.abs();
    if (r.isNaN || r.isInfinite) return a > 0 ? _maxRatio : 0;
    if (r > _maxRatio) return _maxRatio;
    return r;
  }

  /// Computes the longest consecutive run of trades whose result matches
  /// [target]. Streaks are computed in exit-date order so a "5-연승"
  /// really means 5 wins in a row *as they happened*, not as they were
  /// entered.
  static int _longestStreak(List<TradeEntry> trades, TradeResult target) {
    if (trades.isEmpty) return 0;
    final ordered = [...trades]
      ..sort((a, b) {
        final aDate = a.exitDate ?? a.entryDate;
        final bDate = b.exitDate ?? b.entryDate;
        return aDate.compareTo(bDate);
      });
    var best = 0;
    var current = 0;
    for (final t in ordered) {
      if (t.result == target) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }

  /// Per-stock performance rows sorted by total P&L descending. Open
  /// positions are excluded because they have no realised P&L to rank;
  /// the user can drill into a specific stock from the UI to see them.
  static List<StockPerformanceSummary> computeStockPerformance(
    List<TradeEntry> trades,
    TradeAnalyticsFilter filter,
  ) {
    final scope = applyFilter(trades, filter);
    final bySymbol = <String, List<TradeEntry>>{};
    for (final t in scope.closedInScope) {
      bySymbol.putIfAbsent(t.stockSymbol, () => []).add(t);
    }
    final rows = <StockPerformanceSummary>[];
    bySymbol.forEach((symbol, list) {
      var wins = 0;
      var losses = 0;
      var pnl = 0.0;
      var volume = 0;
      var returnSum = 0.0;
      for (final t in list) {
        final p = t.profitLoss;
        pnl += p;
        volume += t.quantity;
        returnSum += t.profitLossPercent;
        if (p > 0) {
          wins++;
        } else if (p < 0) {
          losses++;
        }
      }
      final total = list.length;
      final first = list.first;
      rows.add(
        StockPerformanceSummary(
          stockSymbol: symbol,
          stockName: first.stockName,
          market: first.market,
          tradeCount: total,
          winCount: wins,
          lossCount: losses,
          winRate: total == 0 ? 0 : (wins / total) * 100,
          totalProfitLoss: pnl,
          averageReturnPercent: total == 0 ? 0 : returnSum / total,
          totalVolume: volume,
        ),
      );
    });
    rows.sort((a, b) {
      final byPnl = b.totalProfitLoss.compareTo(a.totalProfitLoss);
      if (byPnl != 0) return byPnl;
      return b.tradeCount.compareTo(a.tradeCount);
    });
    return rows;
  }

  /// Per-strategy performance rows sorted by total P&L descending.
  /// `null` strategies are bucketed under [kUncategorisedStrategy] so
  /// the UI can render "미분류" instead of dropping them.
  static List<StrategyPerformanceSummary> computeStrategyPerformance(
    List<TradeEntry> trades,
    TradeAnalyticsFilter filter,
  ) {
    final scope = applyFilter(trades, filter);
    final byStrategy = <String, List<TradeEntry>>{};
    for (final t in scope.closedInScope) {
      final key = (t.strategy == null || t.strategy!.isEmpty)
          ? _kUncategorisedStrategy
          : t.strategy!;
      byStrategy.putIfAbsent(key, () => []).add(t);
    }
    final rows = <StrategyPerformanceSummary>[];
    byStrategy.forEach((name, list) {
      var wins = 0;
      var pnl = 0.0;
      var returnSum = 0.0;
      for (final t in list) {
        final p = t.profitLoss;
        pnl += p;
        returnSum += t.profitLossPercent;
        if (p > 0) wins++;
      }
      final total = list.length;
      rows.add(
        StrategyPerformanceSummary(
          strategyName: name,
          tradeCount: total,
          winRate: total == 0 ? 0 : (wins / total) * 100,
          totalProfitLoss: pnl,
          averageReturnPercent: total == 0 ? 0 : returnSum / total,
        ),
      );
    });
    rows.sort((a, b) => b.totalProfitLoss.compareTo(a.totalProfitLoss));
    return rows;
  }

  /// Per-weekday performance rows. Always returns 7 rows (Mon..Sun) even
  /// if some days have zero trades — keeps the chart x-axis stable. Day
  /// ordering matches Dart's [DateTime.weekday] (1=Mon, 7=Sun).
  static List<WeekdayPerformanceSummary> computeWeekdayPerformance(
    List<TradeEntry> trades,
    TradeAnalyticsFilter filter,
  ) {
    final scope = applyFilter(trades, filter);
    final buckets = List.generate(8, (_) => <TradeEntry>[]);
    for (final t in scope.closedInScope) {
      final ref = t.exitDate ?? t.entryDate;
      buckets[ref.weekday].add(t);
    }
    final rows = <WeekdayPerformanceSummary>[];
    for (var d = 1; d <= 7; d++) {
      final list = buckets[d];
      var wins = 0;
      var pnl = 0.0;
      for (final t in list) {
        final p = t.profitLoss;
        pnl += p;
        if (p > 0) wins++;
      }
      final total = list.length;
      rows.add(
        WeekdayPerformanceSummary(
          weekday: d,
          tradeCount: total,
          winRate: total == 0 ? 0 : (wins / total) * 100,
          totalProfitLoss: pnl,
          averageProfitLoss: total == 0 ? 0 : pnl / total,
        ),
      );
    }
    return rows;
  }

  /// Monthly P&L bars sorted chronologically (oldest first). Each row is
  /// keyed by (year, month) so multi-year histories keep order across
  /// the December/January boundary. Returns one row per month that has
  /// at least one closed trade in scope.
  static List<MonthlyPnLSummary> computeMonthlyPnL(
    List<TradeEntry> trades,
    TradeAnalyticsFilter filter,
  ) {
    final scope = applyFilter(trades, filter);
    final bucket = <String, _MonthBucket>{};
    for (final t in scope.closedInScope) {
      final exit = t.exitDate;
      if (exit == null) continue;
      final key = '${exit.year}-${exit.month.toString().padLeft(2, '0')}';
      final b = bucket.putIfAbsent(
        key,
        () => _MonthBucket(year: exit.year, month: exit.month),
      );
      b.profitLoss += t.profitLoss;
      b.tradeCount += 1;
      if (t.profitLoss > 0) b.wins += 1;
    }
    final rows = bucket.values
        .map(
          (b) => MonthlyPnLSummary(
            year: b.year,
            month: b.month,
            profitLoss: b.profitLoss,
            tradeCount: b.tradeCount,
            winRate: b.tradeCount == 0 ? 0 : (b.wins / b.tradeCount) * 100,
          ),
        )
        .toList();
    rows.sort((a, b) {
      final y = a.year.compareTo(b.year);
      if (y != 0) return y;
      return a.month.compareTo(b.month);
    });
    return rows;
  }

  /// Cumulative realised P&L line points, oldest first. The line starts
  /// at the first exit date with the realised P&L of that day; each
  /// subsequent point is the previous cumulative + the day's P&L.
  static List<CumulativePnLPoint> computeCumulativePnL(
    List<TradeEntry> trades,
    TradeAnalyticsFilter filter,
  ) {
    final scope = applyFilter(trades, filter);
    final daily = <DateTime, _DayBucket>{};
    for (final t in scope.closedInScope) {
      final exit = t.exitDate;
      if (exit == null) continue;
      final dayKey = DateTime(exit.year, exit.month, exit.day);
      final b = daily.putIfAbsent(dayKey, () => _DayBucket());
      b.dailyPnL += t.profitLoss;
      b.tradeCount += 1;
    }
    final keys = daily.keys.toList()..sort();
    final points = <CumulativePnLPoint>[];
    var cumulative = 0.0;
    for (final k in keys) {
      final b = daily[k]!;
      cumulative += b.dailyPnL;
      points.add(
        CumulativePnLPoint(
          date: k,
          dailyPnL: b.dailyPnL,
          cumulativePnL: cumulative,
          tradeCount: b.tradeCount,
        ),
      );
    }
    return points;
  }

  /// Per-account performance rows sorted by total realised P&L
  /// descending. Trades without an account tag are bucketed under
  /// [kUnassignedAccount] so nothing is silently dropped.
  ///
  /// When [filter.accountTag] is set, applyFilter already narrows to that
  /// single account, so exactly one row comes back — useful for drill-in
  /// views. `accountColors` maps tag name → ARGB color; unknown names get
  /// null and the UI falls back to theme colors.
  static List<AccountPerformanceSummary> computeAccountPerformance(
    List<TradeEntry> trades,
    TradeAnalyticsFilter filter, {
    Map<String, int> accountColors = const {},
  }) {
    final scope = applyFilter(trades, filter);
    final byAccount = <String, List<TradeEntry>>{};
    for (final t in scope.closedInScope) {
      final key = (t.accountTag == null || t.accountTag!.isEmpty)
          ? kUnassignedAccount
          : t.accountTag!;
      byAccount.putIfAbsent(key, () => []).add(t);
    }
    // Open positions must also seed a bucket — an account whose trades
    // are all still open would otherwise be invisible on the dashboard.
    for (final t in scope.openInScope) {
      final key = (t.accountTag == null || t.accountTag!.isEmpty)
          ? kUnassignedAccount
          : t.accountTag!;
      byAccount.putIfAbsent(key, () => []);
    }

    final rows = <AccountPerformanceSummary>[];
    byAccount.forEach((name, list) {
      var wins = 0;
      var losses = 0;
      var breakeven = 0;
      var grossWins = 0.0;
      var grossLosses = 0.0;
      var pnl = 0.0;
      var returnSum = 0.0;
      TradeEntry? best;
      TradeEntry? worst;
      for (final t in list) {
        final p = t.profitLoss;
        pnl += p;
        returnSum += t.profitLossPercent;
        if (p > 0) {
          wins++;
          grossWins += p;
        } else if (p < 0) {
          losses++;
          grossLosses += p;
        } else {
          breakeven++;
        }
        if (best == null || p > best.profitLoss) best = t;
        if (worst == null || p < worst.profitLoss) worst = t;
      }
      final total = list.length;
      final matchedOpen = scope.openInScope
          .where(
            (t) =>
                ((t.accountTag == null || t.accountTag!.isEmpty)
                    ? kUnassignedAccount
                    : t.accountTag!) ==
                name,
          )
          .toList();
      var invested = 0.0;
      for (final t in list) {
        invested += t.entryPrice * t.quantity;
      }
      for (final t in matchedOpen) {
        invested += t.entryPrice * t.quantity;
      }
      rows.add(
        AccountPerformanceSummary(
          accountName: name,
          colorValue: accountColors[name],
          tradeCount: total,
          openPositionCount: _openCountFor(scope.openInScope, name),
          winCount: wins,
          lossCount: losses,
          breakevenCount: breakeven,
          winRate: total == 0 ? 0 : (wins / total) * 100,
          totalProfitLoss: pnl,
          averageReturnPercent: total == 0 ? 0 : returnSum / total,
          totalInvested: invested,
          profitFactor: _safeRatio(grossWins, grossLosses),
          bestTrade: best,
          worstTrade: worst,
        ),
      );
    });
    rows.sort((a, b) {
      final byPnl = b.totalProfitLoss.compareTo(a.totalProfitLoss);
      if (byPnl != 0) return byPnl;
      return b.tradeCount.compareTo(a.tradeCount);
    });
    return rows;
  }

  static int _openCountFor(List<TradeEntry> open, String accountName) {
    var n = 0;
    for (final t in open) {
      final key = (t.accountTag == null || t.accountTag!.isEmpty)
          ? kUnassignedAccount
          : t.accountTag!;
      if (key == accountName) n++;
    }
    return n;
  }
}

class _MonthBucket {
  _MonthBucket({required this.year, required this.month});
  final int year;
  final int month;
  double profitLoss = 0;
  int tradeCount = 0;
  int wins = 0;
}

class _DayBucket {
  double dailyPnL = 0;
  int tradeCount = 0;
}
