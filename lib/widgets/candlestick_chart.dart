// Candlestick chart for trade detail screen.
//
// `fl_chart` 0.69.2 (this app's pinned version) doesn't have a
// `CandlestickChart` widget — it was added in a later release. Rather
// than upgrade `fl_chart` and risk breaking the rest of the app
// (analysis tab line chart, etc.), we render candlesticks ourselves
// with a `CustomPainter`. The painter draws:
//
//   • horizontal grid lines (5 divisions)
//   • left-axis price labels (₩ format)
//   • bottom-axis date labels (M/d) — one per slot, evenly distributed
//   • per-bar wick (vertical line low → high)
//   • per-bar body (rectangle open → close) — always filled (solid) for
//     both bull and bear. The previous "bull = hollow outline" style was
//     a Japanese/US convention; the user requested both directions be
//     solid so KOSPI/KOSDAQ-style red/blue and NASDAQ-style green/red
//     candles both render as filled blocks.
//   • dashed horizontal lines at `entryPrice` and `exitPrice` with
//     right-aligned labels "● 매수가 ₩xx,xxx" / "● 매도가 ₩xx,xxx"
//
// The chart paints itself inside whatever size the parent gives it.
// Pair it with `SizedBox.expand` (or any bounded size) inside an
// `InteractiveViewer` for pinch-zoom support.

import 'dart:ui' as ui show TextDirection;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One OHLC candle on the chart.
class CandlestickSpot {
  const CandlestickSpot({
    required this.x,
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final double x;
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
}

/// Self-contained candlestick chart. Renders inside any bounded box;
/// pair with `SizedBox.expand` (or a fixed-height `SizedBox`) to give
/// it a concrete size, and wrap it in `InteractiveViewer` for
/// pinch-zoom support.
class CandlestickChart extends StatelessWidget {
  const CandlestickChart({
    super.key,
    required this.spots,
    required this.minY,
    required this.maxY,
    required this.bullColor,
    required this.bearColor,
    this.entryPrice,
    this.exitPrice,
    this.entryColor = const Color(0xFF6D28D9),
    this.exitColor = const Color(0xFFDC2626),
    this.gridColor,
    this.axisLabelColor,
    this.backgroundColor,
  });

  final List<CandlestickSpot> spots;
  final double minY;
  final double maxY;

  /// Color used for up candles (close ≥ open).
  final Color bullColor;

  /// Color used for down candles (close < open).
  final Color bearColor;

  /// Horizontal reference line at this price. `null` skips the line.
  final double? entryPrice;
  final Color entryColor;

  /// Horizontal reference line at this price. `null` skips the line.
  final double? exitPrice;
  final Color exitColor;

  /// Defaults to `Color(0x1A000000)` if null (10 % black grid).
  final Color? gridColor;

  /// Defaults to M3 secondary text grey if null.
  final Color? axisLabelColor;

  /// Defaults to transparent if null.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grid = gridColor ?? const Color(0x1A000000);
    final axis = axisLabelColor ??
        (theme.brightness == Brightness.dark
            ? const Color(0xFF9497A9)
            : const Color(0xFF6B7280));
    return CustomPaint(
      painter: _CandlestickPainter(
        spots: spots,
        minY: minY,
        maxY: maxY,
        bullColor: bullColor,
        bearColor: bearColor,
        entryPrice: entryPrice,
        exitPrice: exitPrice,
        entryColor: entryColor,
        exitColor: exitColor,
        gridColor: grid,
        axisLabelColor: axis,
        backgroundColor: backgroundColor ?? const Color(0x00000000),
      ),
      size: Size.infinite,
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  _CandlestickPainter({
    required this.spots,
    required this.minY,
    required this.maxY,
    required this.bullColor,
    required this.bearColor,
    required this.entryPrice,
    required this.exitPrice,
    required this.entryColor,
    required this.exitColor,
    required this.gridColor,
    required this.axisLabelColor,
    required this.backgroundColor,
  });

  final List<CandlestickSpot> spots;
  final double minY;
  final double maxY;
  final Color bullColor;
  final Color bearColor;
  final double? entryPrice;
  final double? exitPrice;
  final Color entryColor;
  final Color exitColor;
  final Color gridColor;
  final Color axisLabelColor;
  final Color backgroundColor;

  // Layout constants (logical px).
  static const double _leftGutter = 56;   // room for price labels
  static const double _bottomGutter = 30; // room for date labels
  static const double _rightGutter = 12;
  static const double _topGutter = 8;
  static const double _candleBodyWidthRatio = 0.7; // 70 % of slot width
  static const double _candleMinBodyWidth = 2;

  static String _formatPrice(double p) {
    if (p.abs() >= 1000) return NumberFormat('#,###').format(p);
    return p.toStringAsFixed(1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Paint the background.
    if ((backgroundColor.a * 255.0).round() != 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    }

    // Chart drawing area, leaving gutters for the labels.
    final chartLeft = _leftGutter;
    final chartTop = _topGutter;
    final chartRight = size.width - _rightGutter;
    final chartBottom = size.height - _bottomGutter;
    final chartW = (chartRight - chartLeft).clamp(0.0, double.infinity);
    final chartH = (chartBottom - chartTop).clamp(0.0, double.infinity);
    if (chartW <= 0 || chartH <= 0) return;

    // Range guards.
    if (minY >= maxY) return;
    if (spots.isEmpty) return;

    final range = maxY - minY;
    final n = spots.length;
    final slotW = chartW / n;
    final bodyW = (slotW * _candleBodyWidthRatio).clamp(_candleMinBodyWidth, double.infinity);

    double y(double price) =>
        chartTop + chartH * (1.0 - (price - minY) / range);

    // 1. Grid — 5 horizontal divisions.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const divisions = 5;
    for (var i = 0; i <= divisions; i++) {
      final price = minY + (range * i / divisions);
      final dy = y(price);
      canvas.drawLine(
        Offset(chartLeft, dy),
        Offset(chartRight, dy),
        gridPaint,
      );
    }

    // 2. Left axis price labels.
    _drawPriceLabels(canvas, chartLeft, chartTop, chartH, divisions);

    // 3. Bottom axis date labels (M/d).
    _drawDateLabels(canvas, chartLeft, chartBottom, slotW);

    // 4. Candles.
    final wickPaint = Paint()..strokeWidth = 1;
    final bodyFillPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final s = spots[i];
      final centerX = chartLeft + slotW * (i + 0.5);
      final isBull = s.close >= s.open;
      final color = isBull ? bullColor : bearColor;

      // Wick (low → high).
      wickPaint.color = color;
      canvas.drawLine(
        Offset(centerX, y(s.high)),
        Offset(centerX, y(s.low)),
        wickPaint,
      );

      // Body (open ↔ close). Both bull and bear are filled — the wick
      // alone communicates direction (vertical extent beyond the body),
      // and a filled body is what both Korean and US exchanges render
      // in their apps. The previous hollow-bull variant was inherited
      // from Japanese/US-style line charts and the user explicitly
      // requested solid fills for both directions.
      final bodyTop = y(isBull ? s.close : s.open);
      final bodyBottom = y(isBull ? s.open : s.close);
      final bodyRect = Rect.fromLTRB(
        centerX - bodyW / 2,
        bodyTop,
        centerX + bodyW / 2,
        bodyBottom,
      );
      bodyFillPaint.color = color;
      canvas.drawRect(bodyRect, bodyFillPaint);
    }

    // 5. Reference lines (entry + exit price).
    if (entryPrice != null) {
      _drawReferenceLine(
        canvas,
        chartLeft,
        chartRight,
        y,
        entryPrice!,
        entryColor,
        labelY: chartTop + 12,
        label: '● 매수가 ${_formatPrice(entryPrice!)}',
      );
    }
    if (exitPrice != null) {
      _drawReferenceLine(
        canvas,
        chartLeft,
        chartRight,
        y,
        exitPrice!,
        exitColor,
        labelY: chartBottom - 12,
        label: '● 매도가 ${_formatPrice(exitPrice!)}',
      );
    }
  }

  /// Draws horizontal dashed line at [price] with a label badge on the
  /// right side at [labelY].
  void _drawReferenceLine(
    Canvas canvas,
    double chartLeft,
    double chartRight,
    double Function(double) y,
    double price,
    Color color, {
    required double labelY,
    required String label,
  }) {
    final dy = y(price);
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5;

    const dashLen = 6.0;
    const gapLen = 4.0;
    var x = chartLeft;
    while (x < chartRight) {
      final end = (x + dashLen).clamp(chartLeft, chartRight);
      canvas.drawLine(Offset(x, dy), Offset(end, dy), linePaint);
      x += dashLen + gapLen;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final labelWidth = tp.width + 10;
    final labelHeight = tp.height + 4;
    final labelRect = Rect.fromLTWH(
      chartRight - labelWidth,
      labelY - labelHeight / 2,
      labelWidth,
      labelHeight,
    );

    final bgPaint = Paint()..color = color.withValues(alpha: 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      bgPaint,
    );
    tp.paint(canvas, Offset(labelRect.left + 5, labelRect.top + 2));
  }

  void _drawPriceLabels(
    Canvas canvas,
    double chartLeft,
    double chartTop,
    double chartH,
    int divisions,
  ) {
    final tpStyle = TextStyle(color: axisLabelColor, fontSize: 10);
    for (var i = 0; i <= divisions; i++) {
      final price = minY + (maxY - minY) * i / divisions;
      final dy = chartTop + chartH * (1.0 - i / divisions);
      final tp = TextPainter(
        text: TextSpan(text: _formatPrice(price), style: tpStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(chartLeft - tp.width - 6, dy - tp.height / 2),
      );
    }
  }

  void _drawDateLabels(
    Canvas canvas,
    double chartLeft,
    double chartBottom,
    double slotW,
  ) {
    if (spots.isEmpty) return;
    final tpStyle = TextStyle(color: axisLabelColor, fontSize: 10);
    final fmt = DateFormat('M/d');
    final n = spots.length;
    final labelCount = n < 5 ? n : 5;
    for (var i = 0; i < labelCount; i++) {
      // First / last / 3 evenly spaced in the middle.
      final idx = i == 0
          ? 0
          : (i == labelCount - 1
              ? n - 1
              : ((n - 1) * i / (labelCount - 1)).round());
      final slotCenterX = chartLeft + slotW * (idx + 0.5);
      final tp = TextPainter(
        text: TextSpan(text: fmt.format(spots[idx].date), style: tpStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(slotCenterX - tp.width / 2, chartBottom + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter old) {
    return old.spots != spots ||
        old.minY != minY ||
        old.maxY != maxY ||
        old.bullColor != bullColor ||
        old.bearColor != bearColor ||
        old.entryPrice != entryPrice ||
        old.exitPrice != exitPrice ||
        old.entryColor != entryColor ||
        old.exitColor != exitColor ||
        old.gridColor != gridColor ||
        old.axisLabelColor != axisLabelColor ||
        old.backgroundColor != backgroundColor;
  }
}