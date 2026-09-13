import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/trade_analytics.dart';
import '../../theme/app_theme.dart';

/// Donut chart that shows the win / loss / breakeven split for the
/// filtered trade list. The center of the donut renders the win rate
/// and total trade count so the user sees the headline number without
/// having to interpret the pie segments.
///
/// Color coding follows [upColor] / [downColor] so the donut is
/// consistent with the rest of the analytics screen. Breakeven trades
/// (P&L = 0) get a neutral grey so they neither inflate the win rate
/// nor the loss rate visually.
class WinLossDonutChart extends StatelessWidget {
  const WinLossDonutChart({
    super.key,
    required this.summary,
    required this.upColor,
    required this.downColor,
    this.size = 180,
    this.neutralColor,
  });

  final TradeAnalyticsSummary summary;
  final Color upColor;
  final Color downColor;
  final Color? neutralColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labelColor = AppColors.textMuted;
    final titleColor = AppColors.text;
    final neutral = neutralColor ?? AppColors.textMuted;

    final sections = <PieChartSectionData>[];
    if (summary.winningTrades > 0) {
      sections.add(
        PieChartSectionData(
          value: summary.winningTrades.toDouble(),
          color: upColor,
          title: '',
          radius: 22,
        ),
      );
    }
    if (summary.losingTrades > 0) {
      sections.add(
        PieChartSectionData(
          value: summary.losingTrades.toDouble(),
          color: downColor,
          title: '',
          radius: 22,
        ),
      );
    }
    if (summary.breakevenTrades > 0) {
      sections.add(
        PieChartSectionData(
          value: summary.breakevenTrades.toDouble(),
          color: neutral,
          title: '',
          radius: 22,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (sections.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: labelColor.withValues(alpha: 0.3),
                    ),
                  ),
                )
              else
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: size * 0.28,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${summary.winRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${l10n.total} ${summary.totalTrades}',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendRow(
                color: upColor,
                label: l10n.win,
                count: summary.winningTrades,
                labelColor: labelColor,
              ),
              const SizedBox(height: AppSpacing.sm),
              _LegendRow(
                color: downColor,
                label: l10n.loss,
                count: summary.losingTrades,
                labelColor: labelColor,
              ),
              const SizedBox(height: AppSpacing.sm),
              _LegendRow(
                color: neutral,
                label: l10n.position,
                count: summary.breakevenTrades,
                labelColor: labelColor,
                isBreakeven: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.count,
    required this.labelColor,
    this.isBreakeven = false,
  });

  final Color color;
  final String label;
  final int count;
  final Color labelColor;
  final bool isBreakeven;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            color: labelColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
