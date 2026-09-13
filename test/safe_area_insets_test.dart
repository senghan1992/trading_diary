import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/main.dart';

void main() {
  group('SystemBarInsetGuard', () {
    testWidgets('consumes system bar bottom and left padding from child', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 48, left: 24),
          ),
          child: MaterialApp(
            builder: (context, child) => SystemBarInsetGuard(child: child!),
            home: const Scaffold(body: Placeholder()),
          ),
        ),
      );

      final bottomLeft = tester.getBottomLeft(find.byType(Placeholder));
      expect(bottomLeft.dy, equals(600 - 48));
      expect(bottomLeft.dx, equals(24));
    });

    testWidgets('passes through full surface when padding is zero', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.zero),
          child: MaterialApp(
            builder: (context, child) => SystemBarInsetGuard(child: child!),
            home: const Scaffold(body: Placeholder()),
          ),
        ),
      );

      final bottomLeft = tester.getBottomLeft(find.byType(Placeholder));
      expect(bottomLeft.dy, equals(600));
      expect(bottomLeft.dx, equals(0));
    });

    testWidgets('preserves viewInsets (keyboard bottom inset) for child', (
      tester,
    ) async {
      double? capturedViewInsetBottom;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 48),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: MaterialApp(
            builder: (context, child) => SystemBarInsetGuard(child: child!),
            home: Builder(
              builder: (context) {
                capturedViewInsetBottom = MediaQuery.viewInsetsOf(
                  context,
                ).bottom;
                return const Scaffold(body: Placeholder());
              },
            ),
          ),
        ),
      );

      expect(capturedViewInsetBottom, equals(300));
    });
  });
}
