// Copyright (c) 2026 Trading Diary. Responsive infrastructure for tablet /
// foldable support. See DESIGN.md for the breakpoint rationale.
//
// ─── Breakpoints ────────────────────────────────────────────────────────────
//
// We follow Flutter's Material 3 window size class buckets, expressed in
// *logical* pixels (dp). Width is measured by `MediaQuery.sizeOf(context)`
// — width, not orientation, because foldables (Galaxy Z Fold, Surface Duo)
// routinely switch orientation while keeping the same width class.
//
//   compact   :  width <  600 dp   ←  phones, Galaxy Z Fold *folded*
//   medium    :  600 ≤ w < 840 dp  ←  Galaxy Z Fold *unfolded*, small tablets
//   expanded  :  840 ≤ w < 1200 dp ←  iPad portrait, iPad landscape (small),
//                                     small desktop windows
//   large     :  1200 dp and up    ←  desktop, iPad Pro landscape
//
// ─── LayoutBuilder vs MediaQuery ────────────────────────────────────────────
//
//   • `MediaQuery.sizeOf(context).width` — REBUILDS ONLY on width changes.
//     Cheaper; safe to call inside `build` of screen-level widgets, the
//     shell, the theme, and large subtrees. This is what we use here.
//
//   • `MediaQuery.of(context).size`     — REBUILDS on EVERY MediaQuery
//     mutation (keyboard show/hide, text scale, safe area, padding…).
//     Avoid in `build`; can cause runaway rebuilds.
//
//   • `LayoutBuilder`                   — gives you the parent's
//     `BoxConstraints.maxWidth`. Use it INSIDE a sub-tree to adapt an
//     individual component (card grid columns, chart height, etc.) without
//     coupling to the global window size. Prefer this for component-level
//     decisions; reach for `MediaQuery.sizeOf` only at the screen level.
//
// ─── Usage ──────────────────────────────────────────────────────────────────
//
//   ```dart
//   // At the screen / shell level:
//   if (context.isMediumOrUp) { ... }
//   if (context.isCompact)    { ... }
//   final width = context.screenWidth;
//
//   // Inside a component, prefer LayoutBuilder:
//   LayoutBuilder(builder: (ctx, c) {
//     final columns = c.maxWidth >= 600 ? 3 : 1;
//     return GridView.count(crossAxisCount: columns, ...);
//   });
//   ```

import 'package:flutter/widgets.dart';

/// Material 3 window size class thresholds (logical pixels / dp).
///
/// Each constant is the *upper* bound of the named bucket — i.e. `medium = 840`
/// means "the medium bucket tops out at 839 dp; 840 dp and above is expanded".
/// The values intentionally match Flutter's `WindowSizeClass` defaults so a
/// downstream user could swap to the framework API later without renumbering.
abstract final class Breakpoints {
  /// End of the `compact` bucket. Width < `compact` → phone / folded foldable.
  static const double compact = 600;

  /// End of the `medium` bucket. 600 ≤ width < `medium` → small tablet /
  /// unfolded foldable.
  static const double medium = 840;

  /// End of the `expanded` bucket. 840 ≤ width < `expanded` → iPad portrait
  /// / small desktop.
  static const double expanded = 1200;

  /// Classify the current window into one of the four buckets.
  ///
  /// Reads `MediaQuery.sizeOf(context).width`, which is a `ValueListenable`
  /// scoped to size — so a widget that calls this only rebuilds on width /
  /// height changes (NOT on keyboard show/hide, text scale, padding, etc.).
  static WindowSizeClass of(BuildContext context) {
    return _classify(MediaQuery.sizeOf(context).width);
  }

  /// Pure classifier — exposed for tests and for components that already
  /// have a width (e.g. inside a `LayoutBuilder`) and want to apply the
  /// same bucketing without re-reading `MediaQuery`.
  static WindowSizeClass classify(double width) => _classify(width);

  static WindowSizeClass _classify(double width) {
    if (width < compact) return WindowSizeClass.compact;
    if (width < medium) return WindowSizeClass.medium;
    if (width < expanded) return WindowSizeClass.expanded;
    return WindowSizeClass.large;
  }
}

/// Discrete width buckets mirroring Flutter's `WindowSizeClass`.
///
/// `index` is monotonic with width, so range checks like
/// `windowSizeClass.index >= WindowSizeClass.medium.index` are well-defined
/// without spelling out every case.
enum WindowSizeClass { compact, medium, expanded, large }

/// Convenience getters for screen-level widgets.
///
/// These intentionally read `MediaQuery.sizeOf` once per call — `sizeOf`
/// is itself cached by the framework, and the rebuild scope is already
/// restricted to size changes, so there is no win from re-caching.
extension ResponsiveContext on BuildContext {
  /// Current window size class. Equivalent to `Breakpoints.of(this)`.
  WindowSizeClass get windowSizeClass => Breakpoints.of(this);

  /// Current window width in logical pixels.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// True on phones and folded foldables (width < 600 dp).
  bool get isCompact => windowSizeClass == WindowSizeClass.compact;

  /// True on small tablets and up (width ≥ 600 dp).
  bool get isMediumOrUp =>
      windowSizeClass.index >= WindowSizeClass.medium.index;

  /// True on iPad-portrait-class devices and up (width ≥ 840 dp).
  bool get isExpandedOrUp =>
      windowSizeClass.index >= WindowSizeClass.expanded.index;

  /// True on desktop-class devices (width ≥ 1200 dp).
  bool get isLarge => windowSizeClass == WindowSizeClass.large;
}