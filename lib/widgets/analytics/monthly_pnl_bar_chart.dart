import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/trade_analytics.dart';
import '../../theme/app_theme.dart';

/// Monthly realised P&L bar chart. One bar per month; positive months
/// use [upColor], negative months use [downColor]. A bar with zero P&L
/// is rendered with [neutralColor] so it doesn't disappear against the
/// background.
///
/// Touch handling is delegated to fl_chart's [BarChart]; tapping a bar
/// pops a tooltip with the month label, total P&L, and trade count.
class MonthlyPnLBarChart extends StatelessWidget {
  const MonthlyPnLBarChart({
    super.key,
    required this.rows,
    required this.upColor,
    required this.downColor,
    this.height = 200,
    this.neutralColor,
  });

  /// Rows sorted oldest first. Caller is responsible for sorting; the
  /// chart assumes ascending chronological order so the x-axis reads
  /// left-to-right.
  final List<MonthlyPnLSummary> rows;
  final Color upColor;
  final Color downColor;
  final Color? neutralColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gridColor = AppColors.border;
    final labelColor = AppColors.textMuted;
    final neutral = neutralColor ?? labelColor.withValues(alpha: 0.6);

    if (rows.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(l10n.noClosedTrades, style: TextStyle(color: labelColor)),
        ),
      );
    }

    // Summary metrics for the strip
    var profitMonths = 0;
    var lossMonths = 0;
    var maxProfitMonth = 0.0;
    var maxLossMonth = 0.0;

    for (final r in rows) {
      if (r.profitLoss > 0) {
        profitMonths++;
        if (r.profitLoss > maxProfitMonth) maxProfitMonth = r.profitLoss;
      } else if (r.profitLoss < 0) {
        lossMonths++;
        if (r.profitLoss < maxLossMonth) maxLossMonth = r.profitLoss;
      }
    }

    final maxAbs = rows
        .map((r) => r.profitLoss.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);
    final yBound = maxAbs == 0 ? 1000.0 : maxAbs * 1.2;
    final yMax = yBound;
    final yMin = -yBound;
    final gridInterval = yBound / 2;

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      Color color;
      if (row.profitLoss > 0) {
        color = upColor;
      } else if (row.profitLoss < 0) {
        color = downColor;
      } else {
        color = neutral;
      }
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: row.profitLoss,
              color: color,
              width: rows.length > 12 ? 10 : 14,
              borderRadius: row.profitLoss >= 0
                  ? const BorderRadius.vertical(top: Radius.circular(AppRadius.sm))
                  : const BorderRadius.vertical(bottom: Radius.circular(AppRadius.sm)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top summary strip: Profit/Loss Months + Best/Worst Month
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '흑자 $profitMonths개월',
                    style: TextStyle(
                      color: upColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    ' · 적자 $lossMonths개월',
                    style: TextStyle(
                      color: downColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (maxProfitMonth > 0 || maxLossMonth < 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (maxProfitMonth > 0) ...[
                      Text(
                        '최고 +${_shortMoney(maxProfitMonth)}',
                        style: TextStyle(
                          color: upColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (maxLossMonth < 0)
                      Text(
                        '최대 -${_shortMoney(maxLossMonth.abs())}',
                        style: TextStyle(
                          color: downColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),

        // Bar Chart Body
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: yMax,
              minY: yMin,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: gridInterval,
                getDrawingHorizontalLine: (val) {
                  if (val.abs() < 0.01) {
                    return FlLine(
                      color: labelColor.withValues(alpha: 0.6),
                      strokeWidth: 1.5,
                      dashArray: [4, 4],
                    );
                  }
                  return FlLine(color: gridColor, strokeWidth: 1);
                },
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 0,
                    color: labelColor.withValues(alpha: 0.6),
                    strokeWidth: 1.5,
                    dashArray: [4, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 6, bottom: 2),
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      labelResolver: (_) => '0',
                    ),
                  ),
                ],
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (value, _) {
                      if (value == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: Text(
                            '0',
                            style: TextStyle(
                              color: labelColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      final sign = value > 0 ? '+' : '-';
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: Text(
                          '$sign${_shortMoney(value.abs())}',
                          style: TextStyle(color: labelColor, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= rows.length) return const SizedBox.shrink();
                  if (rows.length > 12 && idx % 2 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '${rows[idx].month}월',
                      style: TextStyle(color: labelColor, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.card,
              tooltipBorder: BorderSide(color: gridColor),
              getTooltipItem: (group, _, _, _) {
                final r = rows[group.x];
                return BarTooltipItem(
                  '${r.year}년 ${r.month}월\n'
                  '${l10n.tradeCount(r.tradeCount)}',
                  TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          barGroups: groups,
        ),
      ),
    ),
  ],
);
}

  static String _shortMoney(double v) {
    if (v.abs() >= 100000000) {
      return '${(v / 100000000).toStringAsFixed(1)}억';
    }
    if (v.abs() >= 10000) {
      return '${(v / 10000).toStringAsFixed(0)}만';
    }
    return v.toStringAsFixed(0);
  }
}
