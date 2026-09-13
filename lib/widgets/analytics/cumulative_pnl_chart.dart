import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/trade_analytics.dart';
import '../../theme/app_theme.dart';

/// Cumulative realised P&L line chart. Renders a single line with a
/// gradient fill underneath so users can see both the absolute level
/// (cumulative) and the per-day contribution (slope) at a glance.
///
/// Touch handling is delegated to fl_chart's [LineChart]; tapping a
/// point opens a tooltip with the date, daily P&L, and running total.
///
/// When [points] has 0 or 1 entries, [emptyView] is shown instead of
/// the chart so we don't render a meaningless single dot.
class CumulativePnLChart extends StatelessWidget {
  const CumulativePnLChart({
    super.key,
    required this.points,
    required this.upColor,
    required this.downColor,
    this.height = 220,
    this.emptyView,
  });

  /// Points ordered oldest first. Caller is responsible for sorting; the
  /// chart assumes ascending chronological order.
  final List<CumulativePnLPoint> points;
  final Color upColor;
  final Color downColor;
  final double height;

  /// Optional override for the empty-state message. Defaults to a
  /// localised "no closed trades" string.
  final Widget? emptyView;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gridColor = AppColors.border;
    final labelColor = AppColors.textMuted;

    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child:
            emptyView ??
            Center(
              child: Text(
                l10n.noClosedTrades,
                style: TextStyle(color: labelColor),
              ),
            ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].cumulativePnL));
    }

    final maxAbs = points
        .map((p) => p.cumulativePnL.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);

    // Symmetric zero-centered Y scale: locks the zero baseline at exactly 50%
    // height across cumulative, daily, and monthly charts for visual parity.
    final yBound = maxAbs == 0 ? 1000.0 : maxAbs * 1.2;
    final minY = -yBound;
    final maxY = yBound;
    final gridInterval = yBound / 2;

    final actualMin = points
        .map((p) => p.cumulativePnL)
        .reduce((a, b) => a < b ? a : b);
    final actualMax = points
        .map((p) => p.cumulativePnL)
        .reduce((a, b) => a > b ? a : b);

    final latestPnL = points.last.cumulativePnL;
    final lineColor = latestPnL >= 0 ? upColor : downColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top summary strip: Current / Peak / Valley
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
                    '누적 실현: ',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${latestPnL >= 0 ? '+' : ''}${_shortMoney(latestPnL)}',
                    style: TextStyle(
                      color: lineColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '최고 +${_shortMoney(actualMax)}',
                    style: TextStyle(
                      color: actualMax > 0 ? upColor : labelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '최저 ${_shortMoney(actualMin)}',
                    style: TextStyle(
                      color: actualMin < 0 ? downColor : labelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Line Chart Body
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
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
                    interval: (points.length / 4)
                        .clamp(1, double.infinity)
                        .toDouble(),
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          _dateLabel(points[idx].date),
                          style: TextStyle(color: labelColor, fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.card,
                  tooltipBorder: BorderSide(color: gridColor),
                  getTooltipItems: (spots) => spots.map((s) {
                    final p = points[s.x.toInt()];
                    final date = DateFormat.yMd().format(p.date);
                    final sign = p.dailyPnL >= 0 ? '+' : '';
                    final cumSign = p.cumulativePnL >= 0 ? '+' : '';
                    return LineTooltipItem(
                      '$date\n${l10n.realizedPL}: $sign${_shortMoney(p.dailyPnL)}\n'
                      '누적: $cumSign${_shortMoney(p.cumulativePnL)}',
                      TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: lineColor,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, barData) {
                      // Only show a dot at the final point as a focus anchor
                      return spot.x == barData.spots.last.x;
                    },
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 5,
                        color: lineColor,
                        strokeWidth: 2,
                        strokeColor: AppColors.card,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        lineColor.withValues(alpha: 0.25),
                        lineColor.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ],
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

  static String _dateLabel(DateTime d) {
    return DateFormat('M/d').format(d);
  }
}
