import '../providers/trade_provider.dart' show TradeFilter;
import 'stock.dart';
import 'trade_entry.dart';

/// Top-level time-period filter for analytics aggregation. Drives the
/// period chip group at the top of the analytics screen. Resolution is
/// performed by the [TradeAnalyticsCalculator] which normalises the
/// window against `DateTime.now()` so all periods remain stable across
/// user sessions.
enum TimePeriodFilter {
  /// All available history. Used by default on first launch.
  all,

  /// The last 12 calendar months. Calculated as
  /// `[today - 365 days, today]` by the calculator.
  year1,

  /// Last 6 calendar months ending today.
  month6,

  /// Last 30 days (rolling window, not "this calendar month").
  month1,

  /// Last 7 days (rolling window, not "this calendar week").
  week1,
}

/// Aggregate filter applied across the analytics screen. Composes the
/// period filter, the [TradeFilter] (real vs virtual vs all) and an
/// optional market cap. Calculator methods accept this struct so future
/// dimension additions only need to plumb through here.
class TradeAnalyticsFilter {
  const TradeAnalyticsFilter({
    this.period = TimePeriodFilter.all,
    this.tradeType = TradeFilter.all,
    this.market,
    this.accountTag,
  });

  /// Time window for the aggregation.
  final TimePeriodFilter period;

  /// Account-type scope. Mirrors [TradeProvider.filter]; the provider's
  /// current value is reused so the analytics screen stays in lock-step
  /// with the journal screen's filter chips.
  final TradeFilter tradeType;

  /// Optional market cap. `null` means "all markets".
  final MarketType? market;

  /// Optional account tag *name* scope. `null` means "all accounts
  /// combined" (the integrated journal view).
  final String? accountTag;

  /// Returns a new filter with the supplied overrides applied. Used by
  /// the screen when a chip is tapped so we don't mutate the active
  /// filter in place.
  TradeAnalyticsFilter copyWith({
    TimePeriodFilter? period,
    TradeFilter? tradeType,
    MarketType? market,
    bool clearMarket = false,
    String? accountTag,
    bool clearAccountTag = false,
  }) {
    return TradeAnalyticsFilter(
      period: period ?? this.period,
      tradeType: tradeType ?? this.tradeType,
      market: clearMarket ? null : (market ?? this.market),
      accountTag: clearAccountTag ? null : (accountTag ?? this.accountTag),
    );
  }
}

/// Aggregate KPI snapshot for the filtered trade list. All monetary
/// values are in the *raw* currency unit of the underlying trade
/// (won for KOSPI/KOSDAQ, USD for NASDAQ) — there is no FX conversion
/// applied at the calculator layer. Display-layer formatting lives in
/// the chart/UI code.
class TradeAnalyticsSummary {
  const TradeAnalyticsSummary({
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.breakevenTrades,
    required this.winRate,
    required this.totalProfitLoss,
    required this.totalReturnPercent,
    required this.profitFactor,
    required this.averageWin,
    required this.averageLoss,
    required this.payoffRatio,
    required this.averageHoldingDays,
    required this.longestWinStreak,
    required this.longestLossStreak,
    required this.bestTrade,
    required this.worstTrade,
    required this.openPositionsCount,
    required this.totalInvested,
  });

  /// Number of closed trades that match the filter. Pending/entry-only
  /// positions do not contribute here — they have no realised P&L yet.
  final int totalTrades;

  /// Closed trades whose [TradeResult] is `success` AND profit > 0.
  final int winningTrades;

  /// Closed trades whose [TradeResult] is `failure` AND profit < 0.
  final int losingTrades;

  /// Closed trades whose P&L is exactly 0 OR result is `breakeven`.
  /// Counted in the win-rate denominator but never in the numerator.
  final int breakevenTrades;

  /// `winningTrades / totalTrades * 100`. Range 0..100; `0` when there
  /// are no closed trades.
  final double winRate;

  /// Sum of [TradeEntry.profitLoss] over the filtered closed trades.
  /// Positive means overall profit.
  final double totalProfitLoss;

  /// `totalProfitLoss / totalInvested * 100`. `0` when no capital has
  /// been deployed (e.g. the filter selected a market with no trades).
  final double totalReturnPercent;

  /// Gross wins / gross losses (absolute). Capped at `99.9` so the
  /// UI can render "∞" or a special marker when there were wins but
  /// no losses; `0.0` when both sides are zero.
  final double profitFactor;

  /// Mean profit across winning trades. `0` when there are no wins.
  final double averageWin;

  /// Mean loss across losing trades (always non-negative — the sign is
  /// already "loss"). `0` when there are no losses.
  final double averageLoss;

  /// `averageWin / averageLoss`. Capped the same way as profit factor.
  final double payoffRatio;

  /// Mean holding period in days. Computed as
  /// `(exitDate - entryDate).inDays` averaged across closed trades;
  /// floored at 0 so same-day round trips count as 0 days.
  final double averageHoldingDays;

  /// Longest run of consecutive winning closes when trades are sorted
  /// by exit date ascending.
  final int longestWinStreak;

  /// Longest run of consecutive losing closes when sorted by exit date.
  final int longestLossStreak;

  /// Best single trade by P&L, or `null` if no closed trades.
  final TradeEntry? bestTrade;

  /// Worst single trade by P&L (largest loss), or `null`.
  final TradeEntry? worstTrade;

  /// Number of currently-open positions (not closed) that match the
  /// period + market filter. Account-type filter still applies.
  final int openPositionsCount;

  /// Sum of `entryPrice * quantity` across all positions (open + closed)
  /// in scope. Used as the denominator for [totalReturnPercent].
  final double totalInvested;
}

/// Aggregated per-account performance summary. One row per distinct
/// [TradeEntry.accountTag] in the filtered window; trades without a tag
/// are bucketed under the `(미지정)` sentinel so they still show up.
class AccountPerformanceSummary {
  const AccountPerformanceSummary({
    required this.accountName,
    this.colorValue,
    required this.tradeCount,
    required this.openPositionCount,
    required this.winCount,
    required this.lossCount,
    required this.breakevenCount,
    required this.winRate,
    required this.totalProfitLoss,
    required this.averageReturnPercent,
    required this.totalInvested,
    required this.profitFactor,
    required this.bestTrade,
    required this.worstTrade,
  });

  /// Account tag name. The sentinel `(미지정)` marks unassigned trades.
  final String accountName;

  /// Display color from the matching [AccountTag]; null when unknown or
  /// unassigned.
  final int? colorValue;

  /// Number of closed trades in this account bucket.
  final int tradeCount;

  /// Number of currently-open positions in this account bucket.
  final int openPositionCount;

  /// Closed trades with realised profit > 0.
  final int winCount;

  /// Closed trades with realised profit < 0.
  final int lossCount;

  /// Closed trades at exactly breakeven.
  final int breakevenCount;

  /// `winCount / tradeCount * 100`. 0 when no closed trades.
  final double winRate;

  /// Sum of [TradeEntry.profitLoss] over the closed trades in scope.
  final double totalProfitLoss;

  /// Mean of [TradeEntry.profitLossPercent] across closed trades.
  final double averageReturnPercent;

  /// Sum of `entryPrice * quantity` over open + closed trades in scope.
  final double totalInvested;

  /// Gross wins / gross losses (absolute), capped at 99.9 like the
  /// headline KPI. 0 when both sides are zero.
  final double profitFactor;

  /// Best single closed trade by P&L; null when none.
  final TradeEntry? bestTrade;

  /// Worst single closed trade by P&L; null when none.
  final TradeEntry? worstTrade;
}

/// Aggregated per-stock performance summary. One row per stock symbol
/// (deduplicated, ignoring market and name casing) that participated in
/// the filtered window.
class StockPerformanceSummary {
  const StockPerformanceSummary({
    required this.stockSymbol,
    required this.stockName,
    required this.market,
    required this.tradeCount,
    required this.winCount,
    required this.lossCount,
    required this.winRate,
    required this.totalProfitLoss,
    required this.averageReturnPercent,
    required this.totalVolume,
  });

  final String stockSymbol;
  final String stockName;
  final MarketType? market;
  final int tradeCount;
  final int winCount;
  final int lossCount;
  final double winRate;
  final double totalProfitLoss;
  final double averageReturnPercent;

  /// Total quantity traded (sum across all closed trades for the stock).
  final int totalVolume;
}

/// Aggregated per-strategy performance summary. Strategies are derived
/// from [TradeEntry.strategy]; `null` strategies are bucketed under a
/// sentinel string so they show up as "미분류" rather than being dropped.
class StrategyPerformanceSummary {
  const StrategyPerformanceSummary({
    required this.strategyName,
    required this.tradeCount,
    required this.winRate,
    required this.totalProfitLoss,
    required this.averageReturnPercent,
  });

  final String strategyName;
  final int tradeCount;
  final double winRate;
  final double totalProfitLoss;
  final double averageReturnPercent;
}

/// Per-weekday performance summary. `weekday` follows Dart's
/// [DateTime.weekday] convention (1 = Monday, 7 = Sunday). Trades without
/// an exit date are bucketed under their entry day.
class WeekdayPerformanceSummary {
  const WeekdayPerformanceSummary({
    required this.weekday,
    required this.tradeCount,
    required this.winRate,
    required this.totalProfitLoss,
    required this.averageProfitLoss,
  });

  final int weekday;
  final int tradeCount;
  final double winRate;
  final double totalProfitLoss;
  final double averageProfitLoss;
}

/// Per-month P&L bar. Bars carry year+month so a multi-year chart can
/// keep chronological order even across the December/January boundary.
class MonthlyPnLSummary {
  const MonthlyPnLSummary({
    required this.year,
    required this.month,
    required this.profitLoss,
    required this.tradeCount,
    required this.winRate,
  });

  final int year;
  final int month;
  final double profitLoss;
  final int tradeCount;
  final double winRate;
}

/// One point on the cumulative realised P&L curve. `cumulativePnL` is
/// the running total in chronological order (oldest first); `dailyPnL`
/// is the realised P&L for that specific day; `tradeCount` is how many
/// trades exited that day.
class CumulativePnLPoint {
  const CumulativePnLPoint({
    required this.date,
    required this.dailyPnL,
    required this.cumulativePnL,
    required this.tradeCount,
  });

  final DateTime date;
  final double dailyPnL;
  final double cumulativePnL;
  final int tradeCount;
}
