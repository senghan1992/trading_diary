import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../providers/trade_provider.dart';
import '../providers/language_provider.dart';
import '../models/trade_entry.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/responsive_layout.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TradeProvider>();
    final closedTrades = provider.closedTrades;
    final winningTrades = closedTrades
        .where((t) => t.result == TradeResult.success)
        .toList();
    final losingTrades = closedTrades
        .where((t) => t.result == TradeResult.failure)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(l10n.learning, style: TextStyle(color: AppColors.text)),
        actions: context.isCompact
            ? [
                PopupMenuButton<String>(
                  icon: Icon(Icons.language, color: AppColors.text),
                  onSelected: (value) {
                    context.read<LanguageProvider>().setLocale(
                      value == 'ko' ? const Locale('ko') : const Locale('en'),
                    );
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'ko', child: Text(l10n.korean)),
                    PopupMenuItem(value: 'en', child: Text(l10n.english)),
                  ],
                ),
              ]
            : null,
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsCard(context, provider),
              const SizedBox(height: 16),
              _buildStreakAnalysis(context, provider),
              const SizedBox(height: 16),
              context.isMediumOrUp
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildLessonsSection(
                            context,
                            l10n.win,
                            winningTrades,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildLessonsSection(
                            context,
                            l10n.loss,
                            losingTrades,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildLessonsSection(context, l10n.win, winningTrades),
                        const SizedBox(height: 16),
                        _buildLessonsSection(context, l10n.loss, losingTrades),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final total = provider.totalTrades;
    final win = provider.winningTrades;
    final loss = provider.losingTrades;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tradingIdea,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildLargeStat(l10n.total, '$total'),
              _buildLargeStat(l10n.win, '$win'),
              _buildLargeStat(l10n.loss, '$loss'),
              _buildLargeStat(
                l10n.winRate,
                '${provider.winRate.toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: total > 0
                ? Row(
                    children: [
                      Flexible(
                        flex: win,
                        child: Container(height: 8, color: AppColors.green),
                      ),
                      Flexible(
                        flex: loss,
                        child: Container(height: 8, color: AppColors.red),
                      ),
                    ],
                  )
                : Container(
                    height: 8,
                    color: AppColors.textMuted.withValues(alpha: 0.2),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakAnalysis(BuildContext context, TradeProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final trades = provider.closedTrades;
    if (trades.isEmpty) return const SizedBox();

    var currentStreak = 0;
    TradeResult? streakType;
    for (var i = 0; i < trades.length; i++) {
      if (streakType == null) {
        streakType = trades[i].result;
        currentStreak = 1;
      } else if (trades[i].result == streakType) {
        currentStreak++;
      } else {
        break;
      }
    }

    final streakColor = streakType == TradeResult.success
        ? AppColors.green
        : streakType == TradeResult.failure
        ? AppColors.red
        : AppColors.textMuted;
    final streakBg = streakType == TradeResult.success
        ? AppColors.greenBg
        : streakType == TradeResult.failure
        ? AppColors.redBg
        : AppColors.accentSubtle;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: streakBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              streakType == TradeResult.success
                  ? Icons.local_fire_department
                  : streakType == TradeResult.failure
                  ? Icons.water_drop
                  : Icons.remove,
              color: streakColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.win,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                Text(
                  '$currentStreak ${streakType == TradeResult.success
                      ? l10n.win
                      : streakType == TradeResult.failure
                      ? l10n.loss
                      : l10n.total}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: streakColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsSection(
    BuildContext context,
    String title,
    List<TradeEntry> trades,
  ) {
    if (trades.isEmpty) return const SizedBox();

    final isWin = title == 'WIN' || title == '승';
    final iconColor = isWin ? AppColors.green : AppColors.red;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWin ? Icons.emoji_events : Icons.insights,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...trades
              .take(5)
              .map(
                (trade) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: () => _showTradeLesson(context, trade),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trade.stockName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.text,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'MM/dd/yy',
                                  ).format(trade.exitDate ?? trade.entryDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${trade.profitLoss >= 0 ? '+' : ''}${NumberFormat('#,###').format(trade.profitLoss)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: trade.profitLoss >= 0
                                      ? AppColors.green
                                      : AppColors.red,
                                ),
                              ),
                              Text(
                                '${trade.profitLossPercent >= 0 ? '+' : ''}${trade.profitLossPercent.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: trade.profitLoss >= 0
                                      ? AppColors.green
                                      : AppColors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _showTradeLesson(BuildContext context, TradeEntry trade) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trade.stockName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MM/dd/yy').format(trade.exitDate ?? trade.entryDate),
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (trade.strategy != null && trade.strategy!.isNotEmpty) ...[
              Text(
                l10n.tradingIdea,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(trade.strategy!, style: TextStyle(color: AppColors.text)),
              const SizedBox(height: 12),
            ],
            if (trade.reason != null && trade.reason!.isNotEmpty) ...[
              Text(
                l10n.lesson,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(trade.reason!, style: TextStyle(color: AppColors.text)),
              const SizedBox(height: 12),
            ],
            if (trade.lesson != null && trade.lesson!.isNotEmpty) ...[
              Text(
                l10n.lesson,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(trade.lesson!, style: TextStyle(color: AppColors.text)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
