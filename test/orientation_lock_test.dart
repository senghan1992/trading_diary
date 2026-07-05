import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/utils/orientation_lock.dart';
import 'package:trading_diary/utils/responsive.dart';

void main() {
  group('orientationsFor', () {
    test('phone (compact) → portrait only', () {
      expect(orientationsFor(WindowSizeClass.compact), [
        DeviceOrientation.portraitUp,
      ]);
    });

    test('small tablet (medium) → all four orientations', () {
      expect(orientationsFor(WindowSizeClass.medium), [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });

    test('iPad-class (expanded) → all four orientations', () {
      expect(orientationsFor(WindowSizeClass.expanded), hasLength(4));
      expect(
        orientationsFor(WindowSizeClass.expanded),
        containsAll(<DeviceOrientation>[
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    });

    test('desktop-class (large) → all four orientations', () {
      expect(orientationsFor(WindowSizeClass.large), hasLength(4));
    });
  });

  // The orientation lock uses the **shortestSide** (min(width, height)) to
  // classify the device — NOT width alone — so a phone that has been
  // physically rotated to landscape is still recognized as a phone. These
  // tests pin down the shortestSide math so a future refactor does not
  // regress to width-based classification (which would mis-classify a
  // landscape phone as a tablet).
  group('orientation logic — shortestSide classification', () {
    double shortestSideFor(double width, double height) =>
        width < height ? width : height;

    test('360×800 dp phone (portrait) → shortestSide 360 → compact', () {
      final ss = shortestSideFor(360, 800);
      expect(Breakpoints.classify(ss), WindowSizeClass.compact);
      expect(orientationsFor(Breakpoints.classify(ss)), [
        DeviceOrientation.portraitUp,
      ]);
    });

    test('800×360 dp phone (landscape) → shortestSide 360 → compact', () {
      // The phone has been rotated to landscape. Width is now 800 but the
      // shortestSide is still 360 — it is still a phone.
      final ss = shortestSideFor(800, 360);
      expect(Breakpoints.classify(ss), WindowSizeClass.compact);
      expect(orientationsFor(Breakpoints.classify(ss)), [
        DeviceOrientation.portraitUp,
      ]);
    });

    test('Galaxy Z Fold folded: 280×720 → shortestSide 280 → compact', () {
      final ss = shortestSideFor(280, 720);
      expect(Breakpoints.classify(ss), WindowSizeClass.compact);
      expect(orientationsFor(Breakpoints.classify(ss)), [
        DeviceOrientation.portraitUp,
      ]);
    });

    test('Galaxy Z Fold unfolded: 673×840 → shortestSide 673 → medium', () {
      final ss = shortestSideFor(673, 840);
      expect(Breakpoints.classify(ss), WindowSizeClass.medium);
      expect(orientationsFor(Breakpoints.classify(ss)), hasLength(4));
    });

    test('iPad mini portrait 768×1024 → shortestSide 768 → medium', () {
      final ss = shortestSideFor(768, 1024);
      expect(Breakpoints.classify(ss), WindowSizeClass.medium);
      expect(orientationsFor(Breakpoints.classify(ss)), hasLength(4));
    });

    test('iPad mini landscape 1024×768 → shortestSide 768 → medium', () {
      final ss = shortestSideFor(1024, 768);
      expect(Breakpoints.classify(ss), WindowSizeClass.medium);
      expect(orientationsFor(Breakpoints.classify(ss)), hasLength(4));
    });

    test('iPad Pro 11" portrait 834×1194 → shortestSide 834 → medium', () {
      // iPad Pro 11" portrait has shortestSide 834, which is BELOW the
      // medium/expanded boundary of 840. So it sits in medium even in
      // portrait. The orientation lock still allows landscape, which the
      // user wants.
      final ss = shortestSideFor(834, 1194);
      expect(Breakpoints.classify(ss), WindowSizeClass.medium);
      expect(orientationsFor(Breakpoints.classify(ss)), hasLength(4));
    });

    test('iPad Pro 11" landscape 1194×834 → shortestSide 834 → medium', () {
      final ss = shortestSideFor(1194, 834);
      expect(Breakpoints.classify(ss), WindowSizeClass.medium);
      expect(orientationsFor(Breakpoints.classify(ss)), hasLength(4));
    });

    test('iPad Pro 12.9" landscape 1366×1024 → shortestSide 1024 → expanded',
        () {
      final ss = shortestSideFor(1366, 1024);
      expect(Breakpoints.classify(ss), WindowSizeClass.expanded);
      expect(orientationsFor(Breakpoints.classify(ss)), hasLength(4));
    });

    test('1440×900 desktop window → shortestSide 900 → expanded', () {
      final ss = shortestSideFor(1440, 900);
      expect(Breakpoints.classify(ss), WindowSizeClass.expanded);
      expect(orientationsFor(Breakpoints.classify(ss)), hasLength(4));
    });
  });
}