// Copyright (c) 2026 Trading Diary. Shared responsive widgets consumed by
// every screen-level adapter. Keep this file dependency-light: it may pull
// in `theme/app_theme.dart` for spacing tokens but MUST NOT import any
// screen, model, or provider.
//
// Three pieces:
//
//   • ResponsiveContainer  — content max-width + centering (via LayoutBuilder,
//                            so it works inside dialogs, sheets, and nested
//                            scaffolds that already constrain the width).
//
//   • ResponsivePadding    — adaptive horizontal padding that scales with
//                            window size. Reads MediaQuery once per build.
//
//   • ResponsiveSheet.show — modal that becomes a bottom sheet on phone and
//                            a centered dialog on tablet/desktop. Lets screen
//                            adapters drop the "show bottom sheet here" call
//                            in without a width check at every call site.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Centers its [child] and constrains it to a max width per size class.
///
/// Use this to keep long-form content (lists, forms, articles) from
/// stretching edge-to-edge on a 1366-dp tablet. Default caps:
///
///   compact   : unbounded (full width, behaves like a `Center`)
///   medium    : 720 dp   — small tablet reading width
///   expanded  : 960 dp   — iPad portrait
///   large     : 1200 dp  — desktop / iPad Pro landscape
///
/// All caps are configurable per-instance via the `*MaxWidth` named
/// parameters. `compactMaxWidth` defaults to `double.infinity` because the
/// phone form factor should never apply a horizontal ceiling of its own;
/// a screen can still opt in by passing e.g. `compactMaxWidth: 480`.
///
/// Internally a [LayoutBuilder] is used so this widget composes correctly
/// inside dialogs, sheets, and any other parent that constrains width.
/// `constraints.maxWidth` is the source of truth — do NOT also read
/// `MediaQuery.sizeOf`, since the two can disagree (e.g. inside a dialog the
/// MediaQuery width is the screen, but LayoutBuilder sees the dialog).
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.compactMaxWidth = double.infinity,
    this.mediumMaxWidth = 720,
    this.expandedMaxWidth = 960,
    this.largeMaxWidth = 1200,
  });

  final Widget child;
  final double compactMaxWidth;
  final double mediumMaxWidth;
  final double expandedMaxWidth;
  final double largeMaxWidth;

  /// Select the cap for a given parent width. Public so tests can lock the
  /// bucket boundaries without instantiating a [LayoutBuilder].
  static double selectMaxWidth(
    double parentWidth, {
    double compactMaxWidth = double.infinity,
    double mediumMaxWidth = 720,
    double expandedMaxWidth = 960,
    double largeMaxWidth = 1200,
  }) {
    if (parentWidth >= Breakpoints.expanded) return largeMaxWidth;
    if (parentWidth >= Breakpoints.compact) return mediumMaxWidth;
    return compactMaxWidth;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        if (available.isInfinite) {
          // Unconstrained (e.g. sitting directly inside a `Row` without an
          // `Expanded`). Fall back to the global screen width so we can still
          // pick a sensible cap.
          final screenWidth = MediaQuery.sizeOf(context).width;
          return _Centered(
            maxWidth: _capForWidth(screenWidth),
            child: child,
          );
        }
        return _Centered(maxWidth: _capForWidth(available), child: child);
      },
    );
  }

  double _capForWidth(double width) => selectMaxWidth(
        width,
        compactMaxWidth: compactMaxWidth,
        mediumMaxWidth: mediumMaxWidth,
        expandedMaxWidth: expandedMaxWidth,
        largeMaxWidth: largeMaxWidth,
      );
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child, required this.maxWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (maxWidth.isInfinite) {
      return Align(alignment: Alignment.topCenter, child: child);
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Horizontal padding that grows with screen size.
///
///   compact   : AppSpacing.lg   (16 dp)
///   medium    : AppSpacing.xxl  (24 dp)
///   expanded+ : AppSpacing.xxxl (32 dp)
///
/// On phones the 16-dp gutter is unchanged from the existing mobile UI, so
/// this widget is a drop-in replacement for the current hard-coded
/// `EdgeInsets.symmetric(horizontal: 16)` paddings — just wrap and go.
///
/// Pass [overridePadding] to bypass the breakpoint lookup entirely (e.g. on
/// a screen that wants a fixed 8-dp horizontal gutter regardless of form
/// factor). When set, [overridePadding] wins and the breakpoint reads are
/// skipped.
class ResponsivePadding extends StatelessWidget {
  const ResponsivePadding({super.key, required this.child, this.overridePadding});

  final Widget child;

  /// If non-null, this padding is used as-is and the window size is ignored.
  final EdgeInsetsGeometry? overridePadding;

  /// The horizontal gutter Flutter applies per window size class.
  /// Exposed for tests and for screens that want to compose their own
  /// `EdgeInsets` (e.g. add a custom top padding).
  static double horizontalGutterFor(double width) {
    if (width >= Breakpoints.medium) return AppSpacing.xxxl;
    if (width >= Breakpoints.compact) return AppSpacing.xxl;
    return AppSpacing.lg;
  }

  @override
  Widget build(BuildContext context) {
    final override = overridePadding;
    if (override != null) {
      return Padding(padding: override, child: child);
    }
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalGutterFor(width)),
      child: child,
    );
  }
}

/// Adaptive modal. On phones and unfolded-but-narrow foldables it shows a
/// bottom sheet; on iPad-portrait and larger it shows a centered dialog
/// capped at 560 dp wide.
///
/// Replace `showModalBottomSheet(...)` call sites with
/// `ResponsiveSheet.show(...)` once the screen is being adapted; the
/// dialog-vs-sheet choice is then made centrally here.
///
/// ```dart
/// final picked = await ResponsiveSheet.show<DateTime>(
///   context: context,
///   builder: (ctx) => MyPickerSheet(),
/// );
/// ```
///
/// The returned future resolves to the same value the wrapped builder
/// would have produced (i.e. whatever you `Navigator.pop` from the inner
/// builder is what comes back through this future).
///
/// [isScrollControlled] is forwarded to `showModalBottomSheet` and ignored
/// on the dialog path (dialogs are not scroll-controlled).
class ResponsiveSheet {
  // Non-instantiable; only the static `show` entry point is meaningful.
  const ResponsiveSheet._();

  /// Width of the dialog on tablet / desktop. Material's M3 dialog inset
  /// caps at 560 dp for "simple" dialogs, which matches our existing
  /// picker / filter sheets well — wider and the content reads as a small
  /// window instead of a focused modal.
  static const double _dialogMaxWidth = 560;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    final sizeClass = Breakpoints.of(context);
    final useDialog = sizeClass == WindowSizeClass.expanded ||
        sizeClass == WindowSizeClass.large;

    if (useDialog) {
      return showDialog<T>(
        context: context,
        builder: (dialogCtx) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
              child: Builder(builder: (ctx) => builder(ctx)),
            ),
          );
        },
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      builder: builder,
    );
  }
}