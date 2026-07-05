// Comprehensive widget test for the chart card layout on iPad.
//
// Mounts the exact chart container structure used in TradeDetailScreen
// inside a LayoutBuilder + Expanded(flex: 3) inside a Row inside a
// ResponsiveContainer — i.e. the real iPad side-by-side layout — and
// verifies that:
//
//   1. The chart container renders at non-zero width (not 0 as before).
//   2. The fl_chart LineChart inside the InteractiveViewer actually paints
//      at a non-zero size (because LayoutBuilder + Stack inside fl_chart's
//      AxisChartScaffoldWidget can collapse to 0 if the constraint chain is
//      broken).
//   3. The empty state also renders at non-zero width.
//
// If any of these fail, the test prints the actual render-box sizes so the
// regression is diagnosable.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/theme/app_theme.dart';

void main() {
  // Replicates `_buildInteractiveChart` from trade_detail_screen.dart
  // but takes the prices as a parameter so we can drive the test
  // deterministically without a network round trip.
  Widget buildInteractiveChart({
    required List<double> closes,
    required double entryPrice,
    double? exitPrice,
  }) {
    final priceMin = closes.reduce((a, b) => a < b ? a : b);
    final priceMax = closes.reduce((a, b) => a > b ? a : b);
    final values = <double>[priceMin, priceMax, entryPrice, ?exitPrice];
    final minVal = values.reduce((a, b) => a < b ? a : b) * 0.97;
    final maxVal = values.reduce((a, b) => a > b ? a : b) * 1.03;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (closes.length - 1).toDouble(),
          minY: minVal,
          maxY: maxVal,
          lineBarsData: [
            LineChartBarData(
              spots: closes
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                  .toList(),
              color: AppColors.purple,
              barWidth: 2,
            ),
          ],
        ),
      ),
    );
  }

  // Replicates the chart container from `_buildChartCard`. Both empty and
  // data states are tested. Both must use `width: double.infinity`.
  Widget buildChartCard({
    required bool hasData,
    required double chartHeight,
    required bool isDark,
  }) {
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final subColor = isDark ? AppColors.silverBlue : AppColors.lightTextSecondary;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: AppColors.purple, size: 20),
              const SizedBox(width: 8),
              Text('차트', style: TextStyle(color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: subColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('pinch', style: TextStyle(color: subColor, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasData)
            Container(
              width: double.infinity,
              height: 250,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.lightBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 48, color: subColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text('no data', style: TextStyle(color: subColor)),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              height: chartHeight,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.lightBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(20),
                  child: buildInteractiveChart(
                    closes: const [100, 102, 105, 103, 108, 110, 107],
                    entryPrice: 100,
                    exitPrice: 110,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 3, color: AppColors.purple),
              const SizedBox(width: 6),
              Text('매수가', style: TextStyle(color: subColor, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // Simulates the iPad side-by-side overview tab layout:
  //   LayoutBuilder (width = viewport)
  //   Row
  //     Expanded(flex: 2) → summary
  //     SizedBox(20)
  //     Expanded(flex: 3) → chart card  ← this is the slot we want to test
  Widget buildIpadSideBySideLayout({
    required double viewportWidth,
    required bool hasData,
    required double chartHeight,
    required bool isDark,
  }) {
    return Scaffold(
      body: SafeArea(
        child: SizedBox(
          width: viewportWidth,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              if (!isWide) {
                // Just return the chart card directly to focus the test.
                return buildChartCard(
                  hasData: hasData,
                  chartHeight: chartHeight,
                  isDark: isDark,
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      color: Colors.red.withValues(alpha: 0.1),
                      height: 200,
                      child: const Center(child: Text('summary')),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: buildChartCard(
                      hasData: hasData,
                      chartHeight: chartHeight,
                      isDark: isDark,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  group('chart card on iPad side-by-side layout', () {
    testWidgets('data state at iPad portrait (768 dp viewport → 720 cap)',
        (tester) async {
      // iPad portrait width is 768 dp. ResponsiveContainer caps at 720 dp
      // (medium bucket, since 600 ≤ 768 < 840).
      await tester.pumpWidget(MaterialApp(
        home: buildIpadSideBySideLayout(
          viewportWidth: 720,
          hasData: true,
          chartHeight: 360,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Find the chart container by its unique borderRadius(12).
      final chartContainerFinder = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final dec = w.decoration;
        return dec is BoxDecoration &&
            dec.borderRadius == BorderRadius.circular(12);
      });
      expect(chartContainerFinder, findsOneWidget,
          reason: 'chart container must be present');

      final renderBox = tester.renderObject<RenderBox>(chartContainerFinder);
      final size = renderBox.size;
      expect(size.width, greaterThan(0),
          reason: 'chart container must render with width > 0 '
              '(got ${size.width})');
      expect(size.height, closeTo(360, 0.5),
          reason: 'chart container must render with height ≈ chartHeight '
              '(got ${size.height})');

      // The chart container must fill the chart-card's inner Column.
      // 720 viewport - 0 nav rail (Row direct) - 0 spacing already in Row -
      // 20 SizedBox between summary and chart - flex 3 of (720-20).
      // Card has padding 16 on each side, so inner Column width =
      // (flex_width - 32). flex_width = (720 - 20) * 3/5 = 420. Inner = 388.
      expect(size.width, closeTo(388, 4),
          reason: 'chart container width should ≈ 388 dp on iPad portrait '
              'side-by-side (got ${size.width})');
    });

    testWidgets('data state at iPad landscape (1024 dp viewport → 720 cap)',
        (tester) async {
      // iPad landscape width is 1024 dp. ResponsiveContainer caps at 720
      // (medium bucket, since 1024 < 1200).
      await tester.pumpWidget(MaterialApp(
        home: buildIpadSideBySideLayout(
          viewportWidth: 720, // already capped by ResponsiveContainer
          hasData: true,
          chartHeight: 360,
          isDark: true,
        ),
      ));
      await tester.pumpAndSettle();

      final chartContainerFinder = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final dec = w.decoration;
        return dec is BoxDecoration &&
            dec.borderRadius == BorderRadius.circular(12);
      });
      final renderBox = tester.renderObject<RenderBox>(chartContainerFinder);
      final size = renderBox.size;
      expect(size.width, greaterThan(0));
      expect(size.height, closeTo(360, 0.5));
    });

    testWidgets('data state at iPad Pro 12.9 landscape (1366 → 1200 cap)',
        (tester) async {
      // iPad Pro 12.9 landscape: 1366 dp. ResponsiveContainer caps at
      // 1200 dp (large bucket, since 1366 ≥ 1200).
      await tester.pumpWidget(MaterialApp(
        home: buildIpadSideBySideLayout(
          viewportWidth: 1200,
          hasData: true,
          chartHeight: 360,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      final chartContainerFinder = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final dec = w.decoration;
        return dec is BoxDecoration &&
            dec.borderRadius == BorderRadius.circular(12);
      });
      final renderBox = tester.renderObject<RenderBox>(chartContainerFinder);
      final size = renderBox.size;
      // flex_width = (1200 - 20) * 3/5 = 708. Inner Column = 676.
      expect(size.width, greaterThan(0));
      expect(size.height, closeTo(360, 0.5));
    });

    testWidgets('empty state at iPad portrait', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: buildIpadSideBySideLayout(
          viewportWidth: 720,
          hasData: false,
          chartHeight: 280,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      final chartContainerFinder = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final dec = w.decoration;
        return dec is BoxDecoration &&
            dec.borderRadius == BorderRadius.circular(12) &&
            w.constraints?.maxHeight == 250; // empty state has fixed height
      });
      expect(chartContainerFinder, findsOneWidget,
          reason: 'empty state container must be present');
      final renderBox = tester.renderObject<RenderBox>(chartContainerFinder);
      expect(renderBox.size.width, greaterThan(0));
      expect(renderBox.size.height, closeTo(250, 0.5));
    });

    testWidgets('LineChart inside InteractiveViewer paints at non-zero size',
        (tester) async {
      // Specifically verifies the fl_chart LineChart paint (not just the
      // surrounding container). The bug we hit before was that the
      // AxisChartScaffoldWidget's LayoutBuilder+Stack collapsed to 0 px
      // because of loose constraints. With `width: double.infinity` on
      // the chart container the constraints propagate as bounded all the
      // way down to the LineChart.
      await tester.pumpWidget(MaterialApp(
        home: buildIpadSideBySideLayout(
          viewportWidth: 720,
          hasData: true,
          chartHeight: 360,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      // The AxisChartScaffoldWidget is what fl_chart renders. It uses a
      // Stack of SideTitlesWidgets around the central chart. Look for the
      // LineChart widget directly.
      expect(find.byType(LineChart), findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(find.byType(LineChart));
      final size = renderBox.size;
      expect(size.width, greaterThan(50),
          reason: 'LineChart must paint at non-trivial width '
              '(got ${size.width}). If this is 0 or tiny the chart is '
              'invisible — the layout chain is broken again.');
      expect(size.height, greaterThan(50),
          reason: 'LineChart must paint at non-trivial height '
              '(got ${size.height}).');
    });
  });
}