import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../providers/trade_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
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
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final closedTrades = provider.closedTrades;
    final winningTrades = closedTrades.where((t) => t.result == TradeResult.success).toList();
    final losingTrades = closedTrades.where((t) => t.result == TradeResult.failure).toList();

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? Colors.transparent : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(l10n.learning, style: TextStyle(color: textColor)),
        actions: context.isCompact ? [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.language, color: textColor),
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
        ] : null,
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsCard(context, provider, isDark, bgColor, textColor, subColor, cardColor, borderColor),
              const SizedBox(height: 16),
              _buildStreakAnalysis(context, provider, isDark, bgColor, textColor, subColor, cardColor, borderColor),
              const SizedBox(height: 16),
              context.isMediumOrUp
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildLessonsSection(context, l10n.win, winningTrades, isDark, bgColor, textColor, subColor, cardColor, borderColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildLessonsSection(context, l10n.loss, losingTrades, isDark, bgColor, textColor, subColor, cardColor, borderColor),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildLessonsSection(context, l10n.win, winningTrades, isDark, bgColor, textColor, subColor, cardColor, borderColor),
                      const SizedBox(height: 16),
                      _buildLessonsSection(context, l10n.loss, losingTrades, isDark, bgColor, textColor, subColor, cardColor, borderColor),
                    ],
                  ),
              const SizedBox(height: 16),
              _buildRecentReminders(context, provider, isDark, bgColor, textColor, subColor, cardColor, borderColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, TradeProvider provider, bool isDark, Color bgColor, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    final l10n = AppLocalizations.of(context)!;
    final total = provider.totalTrades;
    final win = provider.winningTrades;
    final loss = provider.losingTrades;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tradingIdea, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildLargeStat(l10n.total, '$total', textColor, subColor),
              _buildLargeStat(l10n.win, '$win', textColor, subColor),
              _buildLargeStat(l10n.loss, '$loss', textColor, subColor),
              _buildLargeStat(l10n.winRate, '${provider.winRate.toStringAsFixed(1)}%', textColor, subColor),
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
              : Container(height: 8, color: subColor.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeStat(String label, String value, Color textColor, Color subColor) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: subColor)),
        ],
      ),
    );
  }

  Widget _buildStreakAnalysis(BuildContext context, TradeProvider provider, bool isDark, Color bgColor, Color textColor, Color subColor, Color cardColor, Color borderColor) {
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

    final streakColor = streakType == TradeResult.success ? AppColors.green :
           streakType == TradeResult.failure ? AppColors.red : subColor;
    final streakBg = streakType == TradeResult.success ? AppColors.greenBg :
           streakType == TradeResult.failure ? AppColors.redBg : AppColors.purpleSubtle;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: streakBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              streakType == TradeResult.success ? Icons.local_fire_department :
              streakType == TradeResult.failure ? Icons.water_drop : Icons.remove,
              color: streakColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.win,
                  style: TextStyle(fontSize: 12, color: subColor)),
                Text('$currentStreak ${streakType == TradeResult.success ? l10n.win : streakType == TradeResult.failure ? l10n.loss : l10n.total}',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: streakColor,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsSection(BuildContext context, String title, List<TradeEntry> trades, bool isDark, Color bgColor, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    if (trades.isEmpty) return const SizedBox();

    final isWin = title == 'WIN' || title == '승';
    final iconColor = isWin ? AppColors.green : AppColors.red;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
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
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          ...trades.take(5).map((trade) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showTradeLesson(context, trade),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trade.stockName,
                            style: TextStyle(fontWeight: FontWeight.w500, color: textColor, fontSize: 14)),
                          Text(DateFormat('MM/dd/yy').format(trade.exitDate ?? trade.entryDate),
                            style: TextStyle(fontSize: 12, color: subColor)),
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
                            color: trade.profitLoss >= 0 ? AppColors.green : AppColors.red,
                          ),
                        ),
                        Text(
                          '${trade.profitLossPercent >= 0 ? '+' : ''}${trade.profitLossPercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: trade.profitLoss >= 0 ? AppColors.green : AppColors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  void _showTradeLesson(BuildContext context, TradeEntry trade) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.white : AppColors.lightText;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trade.stockName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 4),
            Text(DateFormat('MM/dd/yy').format(trade.exitDate ?? trade.entryDate),
              style: TextStyle(color: subColor)),
            const SizedBox(height: 16),
            if (trade.strategy != null && trade.strategy!.isNotEmpty) ...[
              Text(l10n.tradingIdea, style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(trade.strategy!, style: TextStyle(color: textColor)),
              const SizedBox(height: 12),
            ],
            if (trade.reason != null && trade.reason!.isNotEmpty) ...[
              Text(l10n.lesson, style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(trade.reason!, style: TextStyle(color: textColor)),
              const SizedBox(height: 12),
            ],
            if (trade.lesson != null && trade.lesson!.isNotEmpty) ...[
              Text(l10n.lesson, style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(trade.lesson!, style: TextStyle(color: textColor)),
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

  Widget _buildRecentReminders(BuildContext context, TradeProvider provider, bool isDark, Color bgColor, Color textColor, Color subColor, Color cardColor, Color borderColor) {
    final l10n = AppLocalizations.of(context)!;
    final reminders = provider.reminders.where((r) => !r.isRead).toList();
    if (reminders.isEmpty) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppColors.purple, size: 20),
              const SizedBox(width: 8),
              Text(l10n.reminders, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          ...reminders.map((r) => Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active, color: AppColors.purple, size: 20),
              title: Text(r.title, style: TextStyle(fontSize: 14, color: textColor)),
              subtitle: r.note != null ? Text(r.note!, style: TextStyle(fontSize: 12, color: subColor)) : null,
              trailing: Text(DateFormat('MM/dd').format(r.remindAt),
                style: TextStyle(fontSize: 12, color: subColor)),
              onTap: () => provider.markReminderRead(r.id),
            ),
          )),
        ],
      ),
    );
  }
}
