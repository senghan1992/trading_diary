import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../providers/trade_provider.dart';
import '../providers/market_provider.dart';
import '../providers/theme_provider.dart';
import '../models/trade_entry.dart';
import '../models/stock.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/responsive.dart';
import '../widgets/ad_banner.dart';
import '../widgets/responsive_layout.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tradeProvider = context.watch<TradeProvider>();
    final marketProvider = context.watch<MarketProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upColor = themeProvider.upColor;
    final downColor = themeProvider.downColor;
 
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // M3: previously only market prices were re-fetched, leaving the
          // dashboard stale if a trade was deleted on another device or a
          // direct Hive edit. Refresh both in parallel so the spinner stops
          // only when all data is fresh.
          await marketProvider.refreshPrices();
          tradeProvider.loadTrades();
        },
        child: ResponsiveContainer(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl + 32),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: AdBanner(),
              ),
              _buildPortfolioHero(context, tradeProvider, isDark, upColor, downColor),
              const SizedBox(height: AppSpacing.xl),
              _buildMarketIndices(context, marketProvider, isDark, upColor, downColor),
              const SizedBox(height: AppSpacing.xl),
              _buildStatsGrid(context, tradeProvider, isDark, upColor, downColor),
              const SizedBox(height: AppSpacing.xl),
              _buildOpenPositions(context, tradeProvider, isDark),
              const SizedBox(height: AppSpacing.xl),
              _buildRecentTrades(context, tradeProvider, isDark, upColor, downColor),
              const SizedBox(height: AppSpacing.xl),
              _buildReminders(context, tradeProvider, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioHero(BuildContext context, TradeProvider provider, bool isDark, Color upColor, Color downColor) {
    final l10n = AppLocalizations.of(context)!;
    final isProfit = provider.totalProfitLoss >= 0;
    
    // Portfolio total aggregates across all closed trades — which may mix
    // KRW and USD in pathological cases. Pick the dominant market (KRW if
    // any Korean trade exists, else USD) so the symbol doesn't lie about
    // the unit. Falls back to inferring from the first trade's symbol for
    // legacy data that pre-dates the persisted market field.
    final closed = provider.closedPositions;
    MarketType? portfolioMarket;
    if (closed.any((t) =>
        t.market == MarketType.kospi || t.market == MarketType.kosdaq)) {
      portfolioMarket = MarketType.kospi;
    } else if (closed.any((t) => t.market == MarketType.nasdaq)) {
      portfolioMarket = MarketType.nasdaq;
    } else if (closed.isNotEmpty) {
      portfolioMarket = inferMarketFromSymbol(closed.first.stockSymbol);
    }

    // Modern Deep Gradient Theme
    final List<Color> gradientColors = isDark
        ? [const Color(0xFF2E1A47), const Color(0xFF1E1B4B)] // Deep Violet-Navy
        : [const Color(0xFF6D28D9), const Color(0xFF4F46E5)]; // Rich Violet-Indigo

    final textPrimaryColor = Colors.white;
    final textSecondaryColor = Colors.white.withValues(alpha: 0.7);

    // High contrast profit/loss indicator colors on deep gradient
    final statusColor = isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171); // Light Emerald Green vs Light Soft Red
    final statusBgColor = statusColor.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF4F46E5)).withValues(alpha: isDark ? 0.4 : 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.portfolioSummary.toUpperCase(),
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              // Mirror the +/- prefix convention from the original code:
              // positive gets a leading "+", negatives are carried by
              // formatTradeMoney's own number formatting.
              '${isProfit ? '+' : ''}${formatTradeMoney(provider.totalProfitLoss, portfolioMarket)}',
              maxLines: 1,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: textPrimaryColor,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${provider.winRate.toStringAsFixed(1)}% ${l10n.winRate}',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, TradeProvider provider, bool isDark, Color upColor, Color downColor) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.lightBorder;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;
    final textColor = isDark ? AppColors.white : AppColors.lightText;

    final stats = [
      _StatData(l10n.total, '${provider.totalTrades}', textColor, null),
      _StatData(l10n.win, '${provider.winningTrades}', upColor, Icons.trending_up_rounded),
      _StatData(l10n.loss, '${provider.losingTrades}', downColor, Icons.trending_down_rounded),
      _StatData(l10n.winRate, '${provider.winRate.toStringAsFixed(0)}%', AppColors.purpleLight, Icons.percent_rounded),
    ];

    Widget buildStatTile(_StatData stat) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            if (stat.icon != null) ...[
              Icon(stat.icon, size: 16, color: stat.color),
              const SizedBox(height: 4),
            ] else
              const SizedBox(height: 20),
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
            const SizedBox(height: 2),
            Text(
              stat.label,
              style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMediumOrUp = constraints.maxWidth >= Breakpoints.compact;
        if (isMediumOrUp) {
          final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: stats.map((stat) => SizedBox(
              width: itemWidth,
              child: buildStatTile(stat),
            )).toList(),
          );
        }
        return Row(
          children: stats.map((stat) {
            final isLast = stat == stats.last;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: isLast ? 0 : AppSpacing.sm),
                child: buildStatTile(stat),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOpenPositions(BuildContext context, TradeProvider provider, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final positions = provider.openPositions;
    if (positions.isEmpty) return const SizedBox();

    final formatter = NumberFormat('#,###');
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;
    final isMediumOrUp = context.isMediumOrUp;

    final items = positions.take(isMediumOrUp ? 6 : 3).map((trade) => _buildPositionRow(context, trade, formatter, textColor, subColor)).toList();

    return _buildSectionCard(
      context,
      title: l10n.openPosition,
      count: positions.length,
      isDark: isDark,
      child: isMediumOrUp
        ? LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: items.map((item) => SizedBox(width: itemWidth, child: item)).toList(),
              );
            },
          )
        : Column(children: items),
    );
  }

  Widget _buildPositionRow(BuildContext context, TradeEntry trade, NumberFormat formatter, Color textColor, Color subColor) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (trade.direction == TradeDirection.buy ? AppColors.green : AppColors.red).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              trade.direction == TradeDirection.buy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 16,
              color: trade.direction == TradeDirection.buy ? AppColors.green : AppColors.red,
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
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  // Infer market for legacy trades (market==null) so pre-
                  // field trades still render with the right unit.
                  '${formatTradeMoney(trade.entryPrice, trade.market ?? inferMarketFromSymbol(trade.stockSymbol))} \u00d7 ${trade.quantity}${l10n.sharesUnit}',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              ],
            ),
          ),
          Text(
            formatTradeMoney(trade.entryPrice * trade.quantity, trade.market ?? inferMarketFromSymbol(trade.stockSymbol)),
            maxLines: 1,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrades(BuildContext context, TradeProvider provider, bool isDark, Color upColor, Color downColor) {
    final l10n = AppLocalizations.of(context)!;
    final recent = provider.closedPositions.take(5).toList();
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;
    final isMediumOrUp = context.isMediumOrUp;

    return _buildSectionCard(
      context,
      title: l10n.recentTrades,
      isDark: isDark,
      child: recent.isEmpty
        ? _buildInlineEmpty(l10n.noTradesYet, subColor)
        : isMediumOrUp
          ? LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: recent.map((trade) => SizedBox(
                    width: itemWidth,
                    child: _buildTradeRow(trade, textColor, subColor, upColor, downColor),
                  )).toList(),
                );
              },
            )
          : Column(
              children: recent.map((trade) => _buildTradeRow(trade, textColor, subColor, upColor, downColor)).toList(),
            ),
    );
  }

  Widget _buildTradeRow(TradeEntry trade, Color textColor, Color subColor, Color upColor, Color downColor) {
    final dateFormat = DateFormat('MM/dd');
    final isWin = trade.result == TradeResult.success;
    final resultColor = isWin ? upColor : downColor;

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
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  dateFormat.format(trade.exitDate ?? trade.entryDate),
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${trade.profitLoss >= 0 ? '+' : ''}${formatTradeMoney(trade.profitLoss, trade.market ?? inferMarketFromSymbol(trade.stockSymbol))}',
                maxLines: 1,
                style: TextStyle(
                  color: resultColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${trade.profitLossPercent >= 0 ? '+' : ''}${trade.profitLossPercent.toStringAsFixed(2)}%',
                maxLines: 1,
                style: TextStyle(
                  color: resultColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminders(BuildContext context, TradeProvider provider, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final unread = provider.reminders.where((r) => !r.isRead).take(3).toList();
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;

    return _buildSectionCard(
      context,
      title: l10n.reminders,
      count: unread.length,
      isDark: isDark,
      child: unread.isEmpty
        ? _buildInlineEmpty(l10n.noPendingReminders, subColor)
        : Column(
            children: unread.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppColors.purpleLight, size: 18),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                    ),
                  ),
                  Text(
                    DateFormat('MM/dd').format(r.remindAt),
                    style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )).toList(),
          ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, int? count, required bool isDark, required Widget child}) {
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.lightBorder;
    final textColor = isDark ? AppColors.white : AppColors.lightText;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                ),
              ),
              if (count != null && count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: AppColors.purpleLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  /// Centered inline message used inside section cards when the section's
  /// content list is empty (e.g., recent trades, reminders). Kept private;
  /// only this screen needs it. The original audit-marked-removed was a
  /// false positive — the two call sites (_buildRecentTrades and
  /// _buildReminders) DO use it.
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

  Widget _buildMarketIndices(BuildContext context, MarketProvider provider, bool isDark, Color upColor, Color downColor) {
    final l10n = AppLocalizations.of(context)!;
    final indices = provider.indices;
    if (indices.isEmpty) return const SizedBox.shrink();

    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.lightBorder.withValues(alpha: 0.4);
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            l10n.marketIndices.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? textSecondaryColor(isDark) : subColor,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 86,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: indices.length,
            itemBuilder: (context, index) {
              final idx = indices[index];
              final isUp = idx.changePrice >= 0;
              final color = isUp ? upColor : downColor;
              final sign = isUp ? '+' : '';

              return Container(
                width: 146,
                margin: EdgeInsets.only(
                  right: index == indices.length - 1 ? 0 : AppSpacing.md,
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          idx.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Icon(
                          isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          size: 14,
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      idx.currentPrice.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$sign${idx.changePrice.toStringAsFixed(2)} ($sign${idx.changePercent.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color textSecondaryColor(bool isDark) {
    return Colors.white.withValues(alpha: 0.7);
  }
}

class _StatData {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  _StatData(this.label, this.value, this.color, this.icon);
}
