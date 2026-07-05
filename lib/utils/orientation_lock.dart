// Copyright (c) 2026 Trading Diary. Locks screen orientation by form factor.
//
// Why this exists:
//
//   • Phones (compact, width < 600 dp) are locked to portrait. Most of the app
//     was designed phone-first, and the layouts that would otherwise see
//     `landscape phone` (tall stats grids overflowing in the narrow viewport)
//     simply are not worth the engineering effort to support — phone users
//     rotate their device far more often than tablet users do, and every
//     rotation triggers a full relayout.
//
//   • Tablets (medium / expanded / large, width >= 600 dp) keep all four
//     orientations. The user explicitly asked for landscape on iPad / Galaxy
//     Tab so the wide horizontal real-estate can be used.
//
// The lock reacts to view-size changes via [didChangeDependencies], so a
// split-screen or foldable that crosses the 600-dp boundary will get its
// orientation set updated without a relaunch. The first frame is handled in
// [main] before `runApp` (see `applyInitialOrientation`) so the OS does not
// briefly render in the "wrong" orientation.
//
// Implementation note: this widget reads view size via [View.of] rather than
// [MediaQuery.sizeOf]. The widget intentionally lives ABOVE `MaterialApp` in
// the tree, so no `MediaQuery` ancestor exists yet — `MediaQuery` is
// established by `MaterialApp` itself. `View.of(context)` works at any level
// because the underlying `FlutterView` is provided by the engine.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'responsive.dart';

/// A widget that locks the OS orientation based on the current form factor.
///
/// Wraps the root of the app. Re-applies the lock whenever the window size
/// class changes (compact ↔ medium+), so a foldable unfolding from phone
/// width to tablet width automatically unlocks landscape.
///
/// The widget itself is invisible (just forwards its [child]); the side
/// effect is the platform-channel call to `SystemChrome`.
class OrientationLock extends StatefulWidget {
  const OrientationLock({super.key, required this.child});

  final Widget child;

  @override
  State<OrientationLock> createState() => _OrientationLockState();
}

class _OrientationLockState extends State<OrientationLock> {
  WindowSizeClass? _lastClass;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = _classifyFromView(context);
    if (current != _lastClass) {
      _lastClass = current;
      // Fire and forget — the platform call resolves asynchronously but
      // there's nothing to await on the UI side. The OS picks up the new
      // orientation the next time it polls.
      SystemChrome.setPreferredOrientations(orientationsFor(current));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Reads the window size from the engine's `View` and classifies it.
///
/// IMPORTANT: classification uses the **shortest side** (min(width, height))
/// rather than width alone. The form-factor decision (phone vs tablet) has
/// to be orientation-invariant — otherwise a phone that the user has already
/// rotated to landscape at app startup would be misclassified as a tablet
/// (its `width` is then > 600 dp even though its `shortestSide` is still
/// < 600 dp). Using shortestSide matches the Material 3 WindowSizeClass
/// spec and ensures the orientation lock is consistent regardless of how
/// the device is currently oriented.
WindowSizeClass _classifyFromView(BuildContext context) {
  final mq = MediaQueryData.fromView(View.of(context));
  final shortestSide =
      mq.size.width < mq.size.height ? mq.size.width : mq.size.height;
  return Breakpoints.classify(shortestSide);
}

/// The orientation set Flutter will apply for the given size class.
///
/// Public so [main] can set the orientation before `runApp` — see
/// [applyInitialOrientation] below. Without that pre-set, the OS briefly
/// shows the wrong orientation on cold start when the device happens to
/// be in landscape.
List<DeviceOrientation> orientationsFor(WindowSizeClass cls) {
  if (cls == WindowSizeClass.compact) {
    // Phones: portrait only. `portraitDown` (upside-down) is intentionally
    // omitted — no consumer asks for it and most launchers do not honor it
    // anyway.
    return const <DeviceOrientation>[DeviceOrientation.portraitUp];
  }
  // Tablets and up: all four. Tablet users explicitly want landscape, and
  // locking them out would defeat the responsive layout work that lets
  // them use the wider viewport.
  return const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
}

/// Reads the first view's logical-pixel width at startup and applies the
/// matching orientation set **before** the first frame paints.
///
/// Called from `main()` so the OS does not briefly render in landscape on
/// a phone (the lock only takes effect after the first [OrientationLock]
/// build, by which point one frame may already have been shown in the
/// pre-lock orientation).
Future<void> applyInitialOrientation() async {
  // The binding must already be initialized by the time this is called —
  // `WidgetsFlutterBinding.ensureInitialized()` in `main()` satisfies that.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final width = view.physicalSize.width / view.devicePixelRatio;
  final height = view.physicalSize.height / view.devicePixelRatio;
  // Use shortestSide so a phone that happens to be in landscape at startup
  // is still classified as a phone and locked to portrait.
  final shortestSide = width < height ? width : height;
  final cls = Breakpoints.classify(shortestSide);
  await SystemChrome.setPreferredOrientations(orientationsFor(cls));
}