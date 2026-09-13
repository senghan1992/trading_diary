import 'package:flutter/material.dart';
import '../widgets/analytics/account_performance_card.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/stock.dart';
import '../models/trade_analytics.dart';
import '../models/trade_entry.dart';
import '../providers/theme_provider.dart';
import '../providers/trade_provider.dart';
import '../services/trade_analytics_calculator.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/analytics/cumulative_pnl_chart.dart';
import '../widgets/analytics/daily_pnl_bar_chart.dart';
import '../widgets/analytics/monthly_pnl_bar_chart.dart';
import '../widgets/analytics/stock_performance_list.dart';
import '../widgets/analytics/strategy_performance_card.dart';
import '../widgets/analytics/weekday_pattern_card.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/review_calendar_panel.dart';

/// Top-level analytics screen. Two tabs:
///   1. Investment aggregation (default) — KPIs + charts + multi-
///      dimensional ranking tables.
///   2. Trade calendar — embeds [ReviewCalendarPanel] verbatim so the
///      user can keep the legacy calendar review workflow available.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum _TrendChartView { cumulative, daily, monthly }

enum _DeepDiveTab { accounts, strategies, weekdays }

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Active aggregation filter.
  TradeAnalyticsFilter _filter = const TradeAnalyticsFilter();

  /// Toggle for chart view: cumulative vs monthly
  _TrendChartView _chartView = _TrendChartView.cumulative;

  /// Selected tab for deep dive section
  _DeepDiveTab _deepDiveTab = _DeepDiveTab.accounts;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bgColor = AppColors.bg;
    final cardColor = AppColors.card;
    final textColor = AppColors.text;
    final subColor = AppColors.textMuted;
    final borderColor = AppColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          l10n.analytics,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: textColor,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: borderColor),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    color: AppColors.accentSubtle,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: textColor,
                  unselectedLabelColor: subColor,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      height: 48,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bar_chart_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(l10n.tabAnalyticsSummary),
                        ],
                      ),
                    ),
                    Tab(
                      height: 48,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(l10n.tabTradeCalendar),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAggregationTab(
                      cardColor: cardColor,
                      textColor: textColor,
                      subColor: subColor,
                      borderColor: borderColor,
                    ),
                    const ReviewCalendarPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAggregationTab({
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
  }) {
    final tradeProvider = context.watch<TradeProvider>();
    if (tradeProvider.filter != _filter.tradeType) {
      _filter = _filter.copyWith(tradeType: tradeProvider.filter);
    }

    final trades = tradeProvider.trades;
    final summary = TradeAnalyticsCalculator.computeSummary(trades, _filter);
    final stockRows = TradeAnalyticsCalculator.computeStockPerformance(
      trades,
      _filter,
    );
    final strategyRows = TradeAnalyticsCalculator.computeStrategyPerformance(
      trades,
      _filter,
    );
    final weekdayRows = TradeAnalyticsCalculator.computeWeekdayPerformance(
      trades,
      _filter,
    );
    final monthlyRows = TradeAnalyticsCalculator.computeMonthlyPnL(
      trades,
      _filter,
    );
    final accountRows = TradeAnalyticsCalculator.computeAccountPerformance(
      trades,
      _filter,
    );
    final cumulative = TradeAnalyticsCalculator.computeCumulativePnL(
      trades,
      _filter,
    );

    final hasData =
        summary.totalTrades > 0 ||
        summary.openPositionsCount > 0 ||
        monthlyRows.isNotEmpty ||
        cumulative.isNotEmpty;

    final themeProvider = context.watch<ThemeProvider>();
    final upColor = themeProvider.upColor;
    final downColor = themeProvider.downColor;

    if (!hasData) {
      return _buildEmptyState(subColor);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      children: [
        // 1. Smart Filter Bar (Period + Market)
        _buildFilterBar(textColor, subColor, borderColor),
        const SizedBox(height: AppSpacing.md),

        // 2. Hero Performance Dashboard (Realized P&L + 3-Factor Strip)
        _buildHeroSummaryCard(
          summary: summary,
          upColor: upColor,
          downColor: downColor,
          cardColor: cardColor,
          textColor: textColor,
          subColor: subColor,
          borderColor: borderColor,
        ),
        const SizedBox(height: AppSpacing.lg),

        // 3. Interactive Trend Chart (Cumulative Line vs Monthly Bar)
        _buildTrendChartCard(
          cumulative: cumulative,
          monthly: monthlyRows,
          upColor: upColor,
          downColor: downColor,
          cardColor: cardColor,
          textColor: textColor,
          subColor: subColor,
          borderColor: borderColor,
        ),
        const SizedBox(height: AppSpacing.lg),

        // 4. Best & Worst Trade Highlights
        if (summary.bestTrade != null || summary.worstTrade != null) ...[
          _buildTradeHighlights(
            summary: summary,
            upColor: upColor,
            downColor: downColor,
            cardColor: cardColor,
            textColor: textColor,
            subColor: subColor,
            borderColor: borderColor,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // 5. Stock Performance Rankings
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: StockPerformanceList(
            rows: stockRows,
            upColor: upColor,
            downColor: downColor,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 6. Deep Dive Analysis (Accounts / Strategies / Weekday Patterns)
        _buildDeepDiveSection(
          accountRows: accountRows,
          strategyRows: strategyRows,
          weekdayRows: weekdayRows,
          upColor: upColor,
          downColor: downColor,
          cardColor: cardColor,
          textColor: textColor,
          subColor: subColor,
          borderColor: borderColor,
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color subColor) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, size: 56, color: subColor),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.emptyAnalyticsTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: subColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.emptyAnalyticsSubtitle,
              style: TextStyle(fontSize: 13, color: subColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(Color textColor, Color subColor, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PeriodChipRow(
            current: _filter.period,
            textColor: textColor,
            subColor: subColor,
            onSelected: (v) =>
                setState(() => _filter = _filter.copyWith(period: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MarketChipRow(
            current: _filter.market,
            textColor: textColor,
            subColor: subColor,
            onSelected: (m) => setState(
              () =>
                  _filter = _filter.copyWith(market: m, clearMarket: m == null),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Hero Performance Dashboard:
  /// Combines total realized P&L, return rate, and key metrics into a single
  /// beautifully crafted card without nested cards.
  Widget _buildHeroSummaryCard({
    required TradeAnalyticsSummary summary,
    required Color upColor,
    required Color downColor,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isPositive = summary.totalProfitLoss >= 0;
    final pnlColor = isPositive ? upColor : downColor;
    final market = _filter.market;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Label & Open positions count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.realizedPL,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: subColor,
                  ),
                ),
                if (summary.openPositionsCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${l10n.openPosition} ${summary.openPositionsCount}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Big P&L Value + Return percentage badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatTradeMoney(summary.totalProfitLoss, market),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: pnlColor,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pnlColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        summary.totalReturnPercent >= 0
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        color: pnlColor,
                        size: 20,
                      ),
                      Text(
                        '${summary.totalReturnPercent >= 0 ? '+' : ''}${summary.totalReturnPercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: pnlColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Divider(color: borderColor, height: 1, thickness: 1),
            const SizedBox(height: AppSpacing.md),

            // 3-Metric Score Strip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Win Rate + Mini Split Bar
                Expanded(
                  child: _buildMetricTile(
                    label: l10n.winRate,
                    mainValue: '${summary.winRate.toStringAsFixed(1)}%',
                    subValue:
                        '${summary.winningTrades}승 ${summary.losingTrades}패',
                    textColor: textColor,
                    subColor: subColor,
                    customBottom: _buildWinLossBar(
                      summary: summary,
                      upColor: upColor,
                      downColor: downColor,
                      neutralColor: subColor.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  color: borderColor,
                ),

                // 2. Profit Factor
                Expanded(
                  child: _buildMetricTile(
                    label: l10n.profitFactor,
                    mainValue: summary.profitFactor >= 99.0
                        ? l10n.infinitySymbol
                        : summary.profitFactor.toStringAsFixed(2),
                    subValue:
                        '익손비 ${(summary.averageLoss == 0 ? 0 : (summary.averageWin / summary.averageLoss)).toStringAsFixed(1)}:1',
                    textColor: textColor,
                    subColor: subColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  color: borderColor,
                ),

                // 3. Trade Activity & Holding
                Expanded(
                  child: _buildMetricTile(
                    label: '총 ${summary.totalTrades}회 거래',
                    mainValue: l10n.daysUnit(summary.averageHoldingDays.round()),
                    subValue: l10n.winStreakFormat(summary.longestWinStreak),
                    textColor: textColor,
                    subColor: subColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String mainValue,
    required String subValue,
    required Color textColor,
    required Color subColor,
    Widget? customBottom,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: subColor,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            mainValue,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 3),
        if (customBottom != null)
          customBottom
        else
          Text(
            subValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: subColor),
          ),
      ],
    );
  }

  /// Horizontal mini proportion bar for win / loss / breakeven trades.
  Widget _buildWinLossBar({
    required TradeAnalyticsSummary summary,
    required Color upColor,
    required Color downColor,
    required Color neutralColor,
  }) {
    final total = summary.totalTrades;
    if (total == 0) {
      return Container(
        height: 5,
        decoration: BoxDecoration(
          color: neutralColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      );
    }

    final winFlex = (summary.winningTrades * 100 ~/ total).clamp(0, 100);
    final lossFlex = (summary.losingTrades * 100 ~/ total).clamp(0, 100);
    final breakFlex = (summary.breakevenTrades * 100 ~/ total).clamp(0, 100);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 5,
        child: Row(
          children: [
            if (winFlex > 0)
              Expanded(
                flex: winFlex,
                child: ColoredBox(color: upColor),
              ),
            if (lossFlex > 0)
              Expanded(
                flex: lossFlex,
                child: ColoredBox(color: downColor),
              ),
            if (breakFlex > 0)
              Expanded(
                flex: breakFlex,
                child: ColoredBox(color: neutralColor),
              ),
          ],
        ),
      ),
    );
  }

  /// 3. Interactive Trend Chart with Segmented Toggle
  Widget _buildTrendChartCard({
    required List<CumulativePnLPoint> cumulative,
    required List<MonthlyPnLSummary> monthly,
    required Color upColor,
    required Color downColor,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart Header: Title & Segmented Toggle Button
            Row(
              children: [
                Expanded(
                  child: Text(
                    switch (_chartView) {
                      _TrendChartView.cumulative => l10n.cumulativePnLChart,
                      _TrendChartView.daily => '일별 실현 손익',
                      _TrendChartView.monthly => l10n.monthlyPnLChart,
                    },
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildChartToggleItem(
                        icon: Icons.show_chart_rounded,
                        label: '누적',
                        isSelected: _chartView == _TrendChartView.cumulative,
                        onTap: () => setState(
                          () => _chartView = _TrendChartView.cumulative,
                        ),
                        textColor: textColor,
                        subColor: subColor,
                      ),
                      _buildChartToggleItem(
                        icon: Icons.candlestick_chart_rounded,
                        label: '일별',
                        isSelected: _chartView == _TrendChartView.daily,
                        onTap: () => setState(
                          () => _chartView = _TrendChartView.daily,
                        ),
                        textColor: textColor,
                        subColor: subColor,
                      ),
                      _buildChartToggleItem(
                        icon: Icons.bar_chart_rounded,
                        label: '월별',
                        isSelected: _chartView == _TrendChartView.monthly,
                        onTap: () => setState(
                          () => _chartView = _TrendChartView.monthly,
                        ),
                        textColor: textColor,
                        subColor: subColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Animated chart body
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (_chartView) {
                _TrendChartView.cumulative => CumulativePnLChart(
                    key: const ValueKey('cumulative_chart'),
                    points: cumulative,
                    upColor: upColor,
                    downColor: downColor,
                    height: 220,
                  ),
                _TrendChartView.daily => DailyPnLBarChart(
                    key: const ValueKey('daily_chart'),
                    points: cumulative,
                    upColor: upColor,
                    downColor: downColor,
                    height: 220,
                  ),
                _TrendChartView.monthly => MonthlyPnLBarChart(
                    key: const ValueKey('monthly_chart'),
                    rows: monthly,
                    upColor: upColor,
                    downColor: downColor,
                    height: 220,
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartToggleItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    required Color subColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm - 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.accent : subColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? textColor : subColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 4. Best & Worst Trade Highlights
  Widget _buildTradeHighlights({
    required TradeAnalyticsSummary summary,
    required Color upColor,
    required Color downColor,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final best = summary.bestTrade;
    final worst = summary.worstTrade;

    Widget cell({
      required TradeEntry? trade,
      required String label,
      required Color color,
      required IconData icon,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: trade == null
              ? Center(
                  child: Text(
                    '-',
                    style: TextStyle(color: subColor, fontSize: 13),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      trade.stockName.isNotEmpty
                          ? trade.stockName
                          : trade.stockSymbol,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatTradeMoney(trade.profitLoss, trade.market),
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '거래 하이라이트',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                cell(
                  trade: best,
                  label: l10n.bestTradeLabel,
                  color: upColor,
                  icon: Icons.arrow_upward_rounded,
                ),
                const SizedBox(width: AppSpacing.md),
                cell(
                  trade: worst,
                  label: l10n.worstTradeLabel,
                  color: downColor,
                  icon: Icons.arrow_downward_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 6. Deep Dive Section (Accounts / Strategies / Weekdays)
  /// Organizes dense dimensional analysis into an intuitive tabbed container
  /// to avoid vertical scroll fatigue.
  Widget _buildDeepDiveSection({
    required List<AccountPerformanceSummary> accountRows,
    required List<StrategyPerformanceSummary> strategyRows,
    required List<WeekdayPerformanceSummary> weekdayRows,
    required Color upColor,
    required Color downColor,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title
            Text(
              '심층 분석',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Deep dive tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDeepDiveTabButton(
                    title: '계좌별 (${accountRows.length})',
                    isSelected: _deepDiveTab == _DeepDiveTab.accounts,
                    onTap: () =>
                        setState(() => _deepDiveTab = _DeepDiveTab.accounts),
                    textColor: textColor,
                    subColor: subColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildDeepDiveTabButton(
                    title: '매매 전략별 (${strategyRows.length})',
                    isSelected: _deepDiveTab == _DeepDiveTab.strategies,
                    onTap: () =>
                        setState(() => _deepDiveTab = _DeepDiveTab.strategies),
                    textColor: textColor,
                    subColor: subColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildDeepDiveTabButton(
                    title: '요일별 패턴',
                    isSelected: _deepDiveTab == _DeepDiveTab.weekdays,
                    onTap: () =>
                        setState(() => _deepDiveTab = _DeepDiveTab.weekdays),
                    textColor: textColor,
                    subColor: subColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Tab Content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (_deepDiveTab) {
                _DeepDiveTab.accounts => _buildAccountContent(
                    accountRows: accountRows,
                    upColor: upColor,
                    downColor: downColor,
                    textColor: textColor,
                    subColor: subColor,
                    borderColor: borderColor,
                    l10n: l10n,
                  ),
                _DeepDiveTab.strategies => _buildStrategyContent(
                    strategyRows: strategyRows,
                    upColor: upColor,
                    downColor: downColor,
                    textColor: textColor,
                    subColor: subColor,
                    l10n: l10n,
                  ),
                _DeepDiveTab.weekdays => WeekdayPatternCard(
                    rows: weekdayRows,
                    upColor: upColor,
                    downColor: downColor,
                    embedded: true,
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeepDiveTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    required Color subColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : subColor.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.accent : subColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountContent({
    required List<AccountPerformanceSummary> accountRows,
    required Color upColor,
    required Color downColor,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
    required AppLocalizations l10n,
  }) {
    if (accountRows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l10n.noClosedTrades,
            style: TextStyle(color: subColor, fontSize: 13),
          ),
        ),
      );
    }

    return AccountPerformanceCard(
      rows: accountRows,
      upColor: upColor,
      downColor: downColor,
      cardColor: Colors.transparent,
      textColor: textColor,
      subColor: subColor,
      borderColor: borderColor,
      embedded: true,
    );
  }

  Widget _buildStrategyContent({
    required List<StrategyPerformanceSummary> strategyRows,
    required Color upColor,
    required Color downColor,
    required Color textColor,
    required Color subColor,
    required AppLocalizations l10n,
  }) {
    if (strategyRows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l10n.noClosedTrades,
            style: TextStyle(color: subColor, fontSize: 13),
          ),
        ),
      );
    }

    return StrategyPerformanceCard(
      rows: strategyRows,
      upColor: upColor,
      downColor: downColor,
      embedded: true,
    );
  }
}

/// Period chip group. Lives outside the main file so it can have its own
/// build helper and stay readable.
class _PeriodChipRow extends StatelessWidget {
  const _PeriodChipRow({
    required this.current,
    required this.textColor,
    required this.subColor,
    required this.onSelected,
  });

  final TimePeriodFilter current;
  final Color textColor;
  final Color subColor;
  final ValueChanged<TimePeriodFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <(TimePeriodFilter, String)>[
      (TimePeriodFilter.all, l10n.periodAll),
      (TimePeriodFilter.year1, l10n.period1Y),
      (TimePeriodFilter.month6, l10n.period6M),
      (TimePeriodFilter.month1, l10n.period1M),
      (TimePeriodFilter.week1, l10n.period1W),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            items
                .map(
                  (i) => _Chip(
                    label: i.$2,
                    isSelected: i.$1 == current,
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () => onSelected(i.$1),
                  ),
                )
                .toList()
                .expand((w) => [w, const SizedBox(width: AppSpacing.sm)])
                .toList()
              ..removeLast(),
      ),
    );
  }
}

/// Market chip group. `null` represents "all markets".
class _MarketChipRow extends StatelessWidget {
  const _MarketChipRow({
    required this.current,
    required this.textColor,
    required this.subColor,
    required this.onSelected,
  });

  final MarketType? current;
  final Color textColor;
  final Color subColor;
  final ValueChanged<MarketType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <(MarketType?, String)>[
      (null, l10n.marketAll),
      (MarketType.kospi, l10n.marketDomestic),
      (MarketType.nasdaq, l10n.marketUS),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            items
                .map(
                  (i) => _Chip(
                    label: i.$2,
                    isSelected: i.$1 == current,
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () => onSelected(i.$1),
                  ),
                )
                .toList()
                .expand((w) => [w, const SizedBox(width: AppSpacing.sm)])
                .toList()
              ..removeLast(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.textColor,
    required this.subColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color textColor;
  final Color subColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : subColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// Importing intl's locale-aware day format is not needed for the
// analytics screen itself; the calendar panel handles its own date
// formatting.
