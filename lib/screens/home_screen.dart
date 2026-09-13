import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/account_tag.dart';
// Reuses the shell's tab-switch notifier so an account-card tap can land the
// user on the Journal tab pre-filtered to that account. `show` keeps the
// circular import (main.dart owns HomeScreen) down to a single symbol.
import '../main.dart' show MainTabRouter;
import '../providers/trade_provider.dart';
import '../providers/theme_provider.dart';
import '../models/trade_entry.dart';
import '../models/stock.dart';
import '../models/trade_analytics.dart';
import '../services/trade_analytics_calculator.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/responsive.dart';
import '../widgets/responsive_layout.dart';
import 'account_management_screen.dart';
import 'add_trade_screen.dart';
import '../services/excel_export_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tradeProvider = context.watch<TradeProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: l10n.accountManagement,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AccountManagementScreen(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          tradeProvider.loadTrades();
        },
        child: ResponsiveContainer(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl + 32,
            ),
            children: [
              _buildPortfolioHero(context, tradeProvider),
              const SizedBox(height: AppSpacing.xl),
              _buildAccountsStrip(context, tradeProvider, themeProvider),
              const SizedBox(height: AppSpacing.xl),
              _buildQuickActions(context, tradeProvider),
              const SizedBox(height: AppSpacing.xl),
              if (tradeProvider.trades.isEmpty)
                _buildFirstRunCard(context)
              else ...[
                _buildStatsGrid(context, tradeProvider),
                const SizedBox(height: AppSpacing.xl),
                _buildOpenPositions(context, tradeProvider),
                const SizedBox(height: AppSpacing.xl),
                _buildRecentTrades(context, tradeProvider, themeProvider),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  /// Deep slate→indigo gradient hero showing aggregate realized P&L across
  /// every account, the return against total invested capital, and a quick
  /// position-count / invested-capital summary.
  Widget _buildPortfolioHero(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final isProfit = provider.totalProfitLoss >= 0;

    // Portfolio totals may mix KRW and USD trades. Pick the dominant market
    // (KRW if any Korean trade exists, else USD) so the symbol doesn't lie
    // about the unit. Falls back to inferring from the first trade's symbol
    // for legacy data that pre-dates the persisted market field.
    final closed = provider.closedPositions;
    MarketType? portfolioMarket;
    if (closed.any(
      (t) => t.market == MarketType.kospi || t.market == MarketType.kosdaq,
    )) {
      portfolioMarket = MarketType.kospi;
    } else if (closed.any((t) => t.market == MarketType.nasdaq)) {
      portfolioMarket = MarketType.nasdaq;
    } else if (closed.isNotEmpty) {
      portfolioMarket = inferMarketFromSymbol(closed.first.stockSymbol);
    }

    final totalInvested = provider.trades.fold<double>(
      0.0,
      (sum, t) => sum + t.entryPrice * t.quantity,
    );
    final returnPct = totalInvested > 0
        ? provider.totalProfitLoss / totalInvested * 100
        : 0.0;

    final textPrimary = Colors.white;
    final textSecondary = Colors.white.withValues(alpha: 0.7);

    // High contrast profit/loss indicator colors on deep gradient.
    final statusColor = isProfit
        ? const Color(0xFF34D399)
        : const Color(0xFFF87171);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient:  LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.heroGradientEnd.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.portfolioSummary,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${isProfit ? '+' : ''}${formatTradeMoney(provider.totalProfitLoss, portfolioMarket)}',
              maxLines: 1,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.8,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isProfit
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${returnPct >= 0 ? '+' : ''}${returnPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${l10n.totalInvested} ${formatTradeMoney(totalInvested, portfolioMarket)}',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${l10n.winRate} ${provider.winRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                l10n.completedTradesCount(provider.closedPositions.length),
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                l10n.openPositionsCount(provider.openPositionCount),
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// First-run invitation card shown instead of the metrics sections when
  /// the journal is still empty. Guides the new user to the single most
  /// valuable action — logging their first trade — instead of staring at
  /// a wall of zeros.
  Widget _buildFirstRunCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accentStrong],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentStrong.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.edit_note_rounded,
            size: 34,
            color: AppColors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.noTradesYet,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AddTradeScreen(),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(l10n.addTrade),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.accentStrong,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _accountInvested(TradeProvider provider, String name) {
    return provider.trades
        .where((t) => t.accountTag == name)
        .fold(0.0, (sum, t) => sum + t.entryPrice * t.quantity);
  }

  void _openJournalTab() {
    MainTabRouter.jumpToJournal();
  }

  double _accountRealizedPnL(TradeProvider provider, String name) {
    return provider.trades
        .where((t) => t.accountTag == name && t.isClosed)
        .fold(0.0, (sum, t) => sum + t.profitLoss);
  }

  int _accountOpenCount(TradeProvider provider, String name) {
    return provider.trades
        .where((t) => t.accountTag == name && !t.isClosed)
        .length;
  }

  Color? _colorForTag(TradeProvider provider, String? tag) {
    if (tag == null) return null;
    for (final a in provider.accounts) {
      if (a.name == tag && a.colorValue != null) return Color(a.colorValue!);
    }
    return null;
  }

  /// Horizontal quick-filter carousel: all-accounts chip, one card per
  /// registered account, and an inline "add account" action.
  Widget _buildAccountsStrip(
    BuildContext context,
    TradeProvider provider,
    ThemeProvider themeProvider,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            l10n.myAccounts,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 116,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildAllAccountsCard(context, provider),
              ...provider.accounts.map(
                (a) => _buildAccountCard(context, provider, themeProvider, a),
              ),
              _buildAddAccountCard(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllAccountsCard(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final isProfit = provider.totalProfitLoss >= 0;
    final pnlColor = isProfit
        ? const Color(0xFF34D399)
        : const Color(0xFFF87171);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        provider.setSelectedAccountTagFilter(null);
        _openJournalTab();
      },
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient:  LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, AppColors.accentStrong],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                 Icon(
                  Icons.public_rounded,
                  size: 14,
                  color: AppColors.white,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.allAccounts,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:  TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${provider.totalProfitLoss >= 0 ? '+' : ''}${NumberFormat('#,###').format(provider.totalProfitLoss)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: pnlColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.openPositionsCount(provider.openPositionCount),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    TradeProvider provider,
    ThemeProvider themeProvider,
    AccountTag account,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final dotColor = account.colorValue != null
        ? Color(account.colorValue!)
        : AppColors.textMuted;
    final pnl = _accountRealizedPnL(provider, account.name);
    final openCount = _accountOpenCount(provider, account.name);
    final pnlColor = pnl > 0
        ? themeProvider.upColor
        : pnl < 0
        ? themeProvider.downColor
        : AppColors.textMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        provider.setSelectedAccountTagFilter(account.name);
        _openJournalTab();
      },
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:  TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${pnl >= 0 ? '+' : ''}${NumberFormat('#,###').format(pnl)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: pnlColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.openPositionsCount(openCount),
              style:  TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${l10n.investedCapital} ${NumberFormat('#,###').format(_accountInvested(provider, account.name))}',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAccountCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const AccountManagementScreen(),
        ),
      ),
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(
              Icons.add_circle_outline_rounded,
              size: 20,
              color: AppColors.accent,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.addAccount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:  TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One-tap action bar: record a trade, export the whole journal to
  /// Excel-compatible CSV, or open the account registry. Mirrors the
  /// "what would I do in my spreadsheet" flow: add a row, send the sheet,
  /// or reorganize the workbook tabs.
  Widget _buildQuickActions(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;

    Widget action({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        action(
          icon: Icons.add_chart_rounded,
          label: l10n.quickRecordTrade,
          color: AppColors.accent,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddTradeScreen()),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        action(
          icon: Icons.table_view_rounded,
          label: l10n.exportToExcel,
          color: AppColors.green,
          onTap: () =>
              ExcelExportService.showExportDialog(context, provider.trades),
        ),
        const SizedBox(width: AppSpacing.sm),
        action(
          icon: Icons.account_balance_rounded,
          label: l10n.manageAccounts,
          color: AppColors.royalBlue,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AccountManagementScreen(),
            ),
          ),
        ),
      ],
    );
  }

  /// 2x2 quick metrics grid: trade count, win rate, profit factor (from the
  /// shared analytics calculator) and average holding period.
  Widget _buildStatsGrid(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final summary = TradeAnalyticsCalculator.computeSummary(
      provider.trades,
      const TradeAnalyticsFilter(),
    );

    final stats = [
      _StatData(
        l10n.totalTrades,
        '${provider.totalTrades}',
        AppColors.text,
        Icons.receipt_long_rounded,
      ),
      _StatData(
        l10n.winRate,
        '${provider.winRate.toStringAsFixed(1)}%',
        AppColors.blue,
        Icons.percent_rounded,
      ),
      _StatData(
        l10n.profitFactor,
        summary.profitFactor.toStringAsFixed(2),
        AppColors.accent,
        Icons.compare_arrows_rounded,
      ),
      _StatData(
        l10n.avgHoldingPeriod,
        l10n.daysUnit(summary.averageHoldingDays.round()),
        AppColors.orange,
        Icons.schedule_rounded,
      ),
    ];

    Widget buildStatTile(_StatData stat) {
      return Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            Icon(stat.icon, size: 16, color: stat.color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                stat.value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: stat.color,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stat.label,
              style:  TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Always two columns → a compact 2x2 metrics grid.
        final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: stats
              .map(
                (stat) =>
                    SizedBox(width: itemWidth, child: buildStatTile(stat)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildOpenPositions(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final positions = provider.openPositions;
    if (positions.isEmpty) return const SizedBox();

    final isTablet = context.isExpandedOrUp;

    final items = positions
        .take(isTablet ? 6 : 3)
        .map((trade) => _buildPositionRow(context, provider, trade))
        .toList();

    return _buildSectionCard(
      context,
      title: l10n.openPosition,
      count: positions.length,
      child: isTablet
          ? LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: items
                      .map((item) => SizedBox(width: itemWidth, child: item))
                      .toList(),
                );
              },
            )
          : Column(children: items),
    );
  }

  Widget _buildPositionRow(
    BuildContext context,
    TradeProvider provider,
    TradeEntry trade,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final market = trade.market ?? inferMarketFromSymbol(trade.stockSymbol);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (trade.direction == TradeDirection.buy
                  ? AppColors.greenBg
                  : AppColors.redBg),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              trade.direction == TradeDirection.buy
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 16,
              color: trade.direction == TradeDirection.buy
                  ? AppColors.green
                  : AppColors.red,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trade.stockName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: _buildAccountBadge(
                        context,
                        provider,
                        trade.accountTag,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${formatTradeMoney(trade.entryPrice, market)} \u00d7 ${trade.quantity}${l10n.sharesUnit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:  TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatTradeMoney(trade.entryPrice * trade.quantity, market),
                maxLines: 1,
                style:  TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrades(
    BuildContext context,
    TradeProvider provider,
    ThemeProvider themeProvider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final recent = provider.closedPositions.take(5).toList();
    final isTablet = context.isExpandedOrUp;

    return _buildSectionCard(
      context,
      title: l10n.recentTrades,
      child: recent.isEmpty
          ? _buildInlineEmpty(l10n.noTradesYet, AppColors.textMuted)
          : isTablet
          ? LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: recent
                      .map(
                        (trade) => SizedBox(
                          width: itemWidth,
                          child: _buildTradeRow(
                            context,
                            provider,
                            trade,
                            themeProvider,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            )
          : Column(
              children: recent
                  .map(
                    (trade) =>
                        _buildTradeRow(context, provider, trade, themeProvider),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildTradeRow(
    BuildContext context,
    TradeProvider provider,
    TradeEntry trade,
    ThemeProvider themeProvider,
  ) {
    final dateFormat = DateFormat('MM/dd');
    final isWin = trade.result == TradeResult.success;
    final resultColor = isWin ? themeProvider.upColor : themeProvider.downColor;
    final market = trade.market ?? inferMarketFromSymbol(trade.stockSymbol);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trade.stockName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: _buildAccountBadge(
                        context,
                        provider,
                        trade.accountTag,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        dateFormat.format(trade.exitDate ?? trade.entryDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:  TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${trade.profitLoss >= 0 ? '+' : ''}${formatTradeMoney(trade.profitLoss, market)}',
                    maxLines: 1,
                    style: TextStyle(
                      color: resultColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${trade.profitLossPercent >= 0 ? '+' : ''}${trade.profitLossPercent.toStringAsFixed(2)}%',
                    maxLines: 1,
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Small pill badge identifying the account a trade belongs to. Shows the
  /// account's own color dot when set; falls back to muted styling for
  /// unassigned trades.
  Widget _buildAccountBadge(
    BuildContext context,
    TradeProvider provider,
    String? tag,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final dotColor = _colorForTag(provider, tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor ?? AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              tag ?? l10n.unassignedAccount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    int? count,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (count != null && count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$count',
                    style:  TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  /// Centered inline message used inside section cards when the section's
  /// content list is empty (e.g., recent trades).
  Widget _buildInlineEmpty(String message, Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: subColor, height: 1.5),
        ),
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  _StatData(this.label, this.value, this.color, this.icon);
}
