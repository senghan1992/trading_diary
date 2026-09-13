import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/trade_analytics.dart';
import '../../theme/app_theme.dart';

/// Daily realised P&L bar chart.
///
/// Visualises daily profit and loss per trading day around a clear zero
/// baseline. Positive days extend upward in [upColor]; negative days extend
/// downward in [downColor]. Includes a top metric strip showing winning/losing
/// days and best/worst single-day results.
class DailyPnLBarChart extends StatelessWidget {
  const DailyPnLBarChart({
    super.key,
    required this.points,
    required this.upColor,
    required this.downColor,
    this.height = 220,
    this.neutralColor,
  });

  final List<CumulativePnLPoint> points;
  final Color upColor;
  final Color downColor;
  final Color? neutralColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gridColor = AppColors.border;
    final labelColor = AppColors.textMuted;
    final neutral = neutralColor ?? labelColor.withValues(alpha: 0.5);

    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            l10n.noClosedTrades,
            style: TextStyle(color: labelColor, fontSize: 13),
          ),
        ),
      );
    }

    // Compute key daily metrics for the summary strip
    var winDays = 0;
    var lossDays = 0;
    var maxGain = 0.0;
    var maxLoss = 0.0;

    for (final p in points) {
      if (p.dailyPnL > 0) {
        winDays++;
        if (p.dailyPnL > maxGain) maxGain = p.dailyPnL;
      } else if (p.dailyPnL < 0) {
        lossDays++;
        if (p.dailyPnL < maxLoss) maxLoss = p.dailyPnL;
      }
    }

    // Chart Y range around zero baseline
    final maxAbs = points
        .map((p) => p.dailyPnL.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);
    final yMax = maxAbs == 0 ? 1000.0 : maxAbs * 1.2;
    final yMin = -yMax;

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      Color barColor;
      if (p.dailyPnL > 0) {
        barColor = upColor;
      } else if (p.dailyPnL < 0) {
        barColor = downColor;
      } else {
        barColor = neutral;
      }

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: p.dailyPnL,
              color: barColor,
              width: points.length > 20 ? 8 : (points.length > 10 ? 12 : 16),
              borderRadius: p.dailyPnL >= 0
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
        // Summary Strip: Win/Loss Days + Best/Worst Day
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
                    '매매 $winDays일 수익',
                    style: TextStyle(
                      color: upColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    ' · $lossDays일 손실',
                    style: TextStyle(
                      color: downColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (maxGain > 0 || maxLoss < 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (maxGain > 0) ...[
                      Text(
                        '최고 +${_formatShortMoney(maxGain)}',
                        style: TextStyle(
                          color: upColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (maxLoss < 0)
                      Text(
                        '최대 -${_formatShortMoney(maxLoss.abs())}',
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

        // Bar Chart Body with zero-baseline
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
                horizontalInterval: yMax / 2,
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
                          '$sign${_formatShortMoney(value.abs())}',
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
                    interval: (points.length / 5).clamp(1, double.infinity).toDouble(),
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                      final date = points[idx].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          DateFormat('M/d').format(date),
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
                  getTooltipItem: (group, _, rod, _) {
                    final p = points[group.x];
                    final dateStr = DateFormat.yMMMd().format(p.date);
                    final sign = p.dailyPnL >= 0 ? '+' : '-';
                    return BarTooltipItem(
                      '$dateStr\n일손익: $sign${_formatShortMoney(p.dailyPnL.abs())}\n거래: ${p.tradeCount}건',
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

  static String _formatShortMoney(double v) {
    if (v.abs() >= 100000000) {
      return '${(v / 100000000).toStringAsFixed(1)}억';
    }
    if (v.abs() >= 10000) {
      return '${(v / 10000).toStringAsFixed(0)}만';
    }
    return v.toStringAsFixed(0);
  }
}
