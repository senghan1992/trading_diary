import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/trade_analytics.dart';
import '../../providers/trade_provider.dart';
import '../../services/trade_analytics_calculator.dart';
import '../../theme/app_theme.dart';

/// Per-account realised-P&L comparison card for the analytics screen's
/// aggregation tab. Each [AccountPerformanceSummary] row renders three
/// horizontal progress bars — realised P&L magnitude (normalised against
/// the largest absolute P&L), win rate, and the account's share of total
/// closed trades — so accounts can be compared at a glance. Tapping a row
/// jumps back to the journal pre-filtered to that account. Unassigned
/// trades are included as their own row.
class AccountPerformanceCard extends StatelessWidget {
  const AccountPerformanceCard({
    super.key,
    required this.rows,
    required this.upColor,
    required this.downColor,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
    required this.borderColor,
    this.embedded = false,
  });

  final List<AccountPerformanceSummary> rows;
  final Color upColor;
  final Color downColor;
  final Color cardColor;
  final Color textColor;
  final Color subColor;
  final Color borderColor;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final maxAbsPnl = rows
        .map((r) => r.totalProfitLoss.abs())
        .reduce((a, b) => a > b ? a : b);
    final totalTrades = rows.fold<int>(0, (sum, r) => sum + r.tradeCount);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(
            l10n.accountPerformance,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final row in rows) ...[
          _buildRow(context, row, maxAbsPnl, totalTrades),
          if (row != rows.last) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );

    if (embedded) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: content,
    );
  }

  Widget _buildRow(
    BuildContext context,
    AccountPerformanceSummary row,
    double maxAbsPnl,
    int totalTrades,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final pnlColor = row.totalProfitLoss > 0
        ? upColor
        : (row.totalProfitLoss < 0 ? downColor : subColor);
    final formatter = NumberFormat('#,###');
    // All three bars are normalised so every account is comparable on the
    // same scale: P&L against the largest absolute result, win rate against
    // 100%, and trade count against the grand total across all accounts.
    final pnlShare = maxAbsPnl == 0
        ? 0.0
        : (row.totalProfitLoss.abs() / maxAbsPnl).clamp(0.04, 1.0);
    final winShare = (row.winRate / 100).clamp(0.0, 1.0);
    final tradeShare = totalTrades == 0 ? 0.0 : row.tradeCount / totalTrades;
    final dotColor = row.colorValue != null ? Color(row.colorValue!) : subColor;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () {
        // Drill into this account: pre-select it on the provider and pop
        // to the journal so the filter bar shows the account in context.
        context.read<TradeProvider>().setSelectedAccountTagFilter(
          row.accountName == kUnassignedAccount
              ? kUnassignedAccount
              : row.accountName,
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.accountName == kUnassignedAccount
                        ? l10n.unassignedAccount
                        : row.accountName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${row.totalProfitLoss >= 0 ? '+' : ''}'
                  '${formatter.format(row.totalProfitLoss)}',
                  style: TextStyle(
                    color: pnlColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Realised P&L magnitude vs. the biggest account result.
            _ProgressBar(
              fill: pnlColor,
              track: AppColors.surface,
              fillFraction: pnlShare,
              height: 8,
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: _LabeledBar(
                    label: l10n.winRate,
                    value: '${row.winRate.toStringAsFixed(0)}%',
                    fillFraction: winShare,
                    fillColor: AppColors.accent,
                    labelColor: subColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _LabeledBar(
                    label: l10n.tradesCount(row.tradeCount),
                    value: totalTrades == 0
                        ? '0%'
                        : '${(tradeShare * 100).toStringAsFixed(0)}%',
                    fillFraction: tradeShare,
                    fillColor: AppColors.royalBlue,
                    labelColor: subColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.avgReturn} ${row.averageReturnPercent.toStringAsFixed(2)}% · '
              '${l10n.openPositionsCount(row.openPositionCount)}',
              style: TextStyle(color: subColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded horizontal progress bar: a slate track with a coloured fill
/// proportional to [fillFraction].
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.fill,
    required this.track,
    required this.fillFraction,
    this.height = 6,
  });

  final Color fill;
  final Color track;
  final double fillFraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fillFraction.clamp(0.0, 1.0),
              child: ColoredBox(color: fill),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact labelled progress bar used for the win-rate and trade-share
/// comparisons under each account row.
class _LabeledBar extends StatelessWidget {
  const _LabeledBar({
    required this.label,
    required this.value,
    required this.fillFraction,
    required this.fillColor,
    required this.labelColor,
  });

  final String label;
  final String value;
  final double fillFraction;
  final Color fillColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: labelColor, fontSize: 10),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        _ProgressBar(
          fill: fillColor,
          track: AppColors.surface,
          fillFraction: fillFraction,
          height: 4,
        ),
      ],
    );
  }
}
