import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/trade_analytics.dart';
import '../../theme/app_theme.dart';

/// Per-strategy performance card. Renders a vertical list of chips; each
/// chip displays the strategy name, trade count, win rate, and net P&L
/// so the user can spot which playbooks are paying off and which are
/// bleeding capital.
///
/// When [rows] is empty, the card body shows a localised "no closed
/// trades" hint instead of an empty box.
class StrategyPerformanceCard extends StatelessWidget {
  const StrategyPerformanceCard({
    super.key,
    required this.rows,
    required this.upColor,
    required this.downColor,
    this.embedded = false,
  });

  final List<StrategyPerformanceSummary> rows;
  final Color upColor;
  final Color downColor;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = AppColors.card;
    final textColor = AppColors.text;
    final subColor = AppColors.textMuted;
    final borderColor = AppColors.border;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(
            l10n.strategyPerformance,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                l10n.noClosedTrades,
                style: TextStyle(color: subColor, fontSize: 13),
              ),
            ),
          )
        else
          ...rows
              .take(8)
              .map(
                (r) => _StrategyRow(
                  summary: r,
                  textColor: textColor,
                  subColor: subColor,
                  upColor: upColor,
                  downColor: downColor,
                  uncategorisedLabel: l10n.uncategorisedStrategy,
                ),
              ),
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
}

class _StrategyRow extends StatelessWidget {
  const _StrategyRow({
    required this.summary,
    required this.textColor,
    required this.subColor,
    required this.upColor,
    required this.downColor,
    required this.uncategorisedLabel,
  });

  final StrategyPerformanceSummary summary;
  final Color textColor;
  final Color subColor;
  final Color upColor;
  final Color downColor;
  final String uncategorisedLabel;

  @override
  Widget build(BuildContext context) {
    final pnlColor = summary.totalProfitLoss > 0
        ? upColor
        : summary.totalProfitLoss < 0
        ? downColor
        : subColor;

    // Treat the calculator's internal sentinel as "Uncategorised" in
    // the user-visible label so the underlying magic string never
    // leaks to the UI.
    final displayName = summary.strategyName.startsWith('(')
        ? uncategorisedLabel
        : summary.strategyName;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: pnlColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: pnlColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.tradeCount}회 · 승률 ${summary.winRate.toStringAsFixed(0)}%',
                    style: TextStyle(color: subColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  summary.totalProfitLoss >= 0 ? '+' : '-',
                  style: TextStyle(
                    color: pnlColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.averageReturnPercent.toStringAsFixed(1)}%',
                  style: TextStyle(color: subColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
