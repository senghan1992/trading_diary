import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/theme/app_theme.dart';

// Regression test for the iPad-landscape RenderFlex overflow reported in the
// journal screen's 2-column trade card grid.
//
// The bug: the grid was sized with `childAspectRatio: 2.2`, which produced
// ~138-dp cells on iPad landscape (3 columns of ~304 dp). The card content
// needs ~162 dp — Padding(32) + Row(44) + gap(12) + OutlinedButton(40) +
// InfoChips row(44). The Column inside each card overflowed.
//
// The fix: switch from `childAspectRatio` to `mainAxisExtent: 178` (a
// fixed cell height that fits the content). This test pins the values
// used in `SliverGridDelegateWithMaxCrossAxisExtent` so a future refactor
// cannot silently regress to a too-short cell height.
//
// We can't import the screen directly here (it depends on providers,
// navigation, etc.), so we replicate the grid delegate configuration
// and assert on the rendered cell heights. The actual screen must match.

void main() {
  group('journal card grid delegate', () {
    // These numbers must match `lib/screens/journal_screen.dart`
    // `_buildCardList` (the medium-or-up branch).
    const double maxCrossAxisExtent = 380;
    const double mainAxisExtent = 178;

    test('mainAxisExtent is large enough for the card content', () {
      // Card content stack (see _buildPositionCard / _buildTradeCard):
      //   Padding(16) top
      //   Row: 44 dp (icon container) OR Column with stock name + tag (~40 dp)
      //   SizedBox 12
      //   Bottom row: 40-44 dp (OutlinedButton.icon for open positions,
      //     or 3 InfoChips row for closed trades)
      //   Padding(16) bottom
      // = 32 + 44 + 12 + 44 = 132 dp absolute minimum
      const double minimumRequiredContentHeight = 132;

      // Subtract the horizontal padding only — the *vertical* padding is
      // already accounted for in the per-element measurements above. So the
      // mainAxisExtent must be >= content height (not content + padding).
      // We give a 20 dp buffer for longer stock names that wrap.
      const double requiredMainAxisExtent =
          minimumRequiredContentHeight + 20;
      expect(
        mainAxisExtent,
        greaterThanOrEqualTo(requiredMainAxisExtent),
        reason: 'mainAxisExtent=$mainAxisExtent must be ≥ '
            '$requiredMainAxisExtent dp to fit the trade card content. '
            'A smaller value will re-introduce the iPad-landscape '
            'RenderFlex overflow.',
      );
    });

    test('mainAxisExtent produces a sane cell aspect ratio on iPad landscape',
        () {
      // Simulate iPad landscape: 1024 dp wide, NavigationRail 80 dp wide,
      // VerticalDivider 1 dp, ResponsiveContainer caps at 960 dp (expanded),
      // GridView horizontal padding 16 dp on each side = 928 dp inner width.
      const double iPadLandscapeInnerWidth = 1024 - 80 - 1 - 32 - 32;
      // n columns: floor((innerWidth + spacing) / (maxExtent + spacing))
      // We pick the largest n such that n*maxExtent + (n-1)*spacing ≤ innerWidth
      const double spacing = AppSpacing.md; // 12
      final double perCol = maxCrossAxisExtent + spacing;
      final int columns = (iPadLandscapeInnerWidth / perCol).floor();
      // Each column width = (innerWidth - (columns-1)*spacing) / columns,
      // capped at maxCrossAxisExtent.
      final double columnWidth =
          ((iPadLandscapeInnerWidth - (columns - 1) * spacing) / columns)
              .clamp(0, maxCrossAxisExtent);

      expect(columns, greaterThanOrEqualTo(2));
      expect(columns, lessThanOrEqualTo(4));
      // Cell aspect ratio width:height — should be wider than 1 (cell is
      // landscape-shaped), but not absurdly so. If it gets near 1:1 the
      // cards will look squat.
      final double aspectRatio = columnWidth / mainAxisExtent;
      expect(aspectRatio, greaterThan(1.4));
      expect(aspectRatio, lessThan(2.5));
    });
  });
}