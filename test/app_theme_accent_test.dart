// Tests for the light-only premium "Ledger" palette.
//
// Covers:
//   • The documented hex values of the core surface/text tokens
//     (bg #F6F4ED, card #FFFFFF, border #E4DFD2, text #182019,
//      textSecondary #5E6A60) — the design spec's contract.
//   • Brand accents: deep evergreen primary with a darker pressed variant
//     and a subtle wash; steel-blue secondary; brass gold emphasis.
//   • `AppTheme.lightTheme` wires the accent into the Material color scheme.
//   • Calendar marker tokens (`markerWin`, `markerLoss`, `markerNeutral`)
//     are distinct hues so they read at a glance against paper cards.
//
// These are pure-Color token checks — no widgets / no Hive — so they stay
// cheap and deterministic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/theme/app_theme.dart';

void main() {
  group('Core surface & text tokens match the design spec', () {
    test('bg is warm ivory (#F6F4ED)', () {
      expect(AppColors.bg, const Color(0xFFF6F4ED));
    });

    test('card is pure white (paper)', () {
      expect(AppColors.card, Colors.white);
    });

    test('border is warm sand (#E4DFD2)', () {
      expect(AppColors.border, const Color(0xFFE4DFD2));
    });

    test('text is deep warm ink (#182019)', () {
      expect(AppColors.text, const Color(0xFF182019));
    });

    test('textMuted is sage gray (#5E6A60)', () {
      expect(AppColors.textMuted, const Color(0xFF5E6A60));
    });
  });

  group('Brand accents', () {
    test('accent is deep evergreen (#1E5B45)', () {
      expect(AppColors.accent, const Color(0xFF1E5B45));
    });

    test('accentStrong is darker than accent (pressed state)', () {
      expect(
        AppColors.accentStrong.computeLuminance(),
        lessThan(AppColors.accent.computeLuminance()),
      );
    });

    test('accentSubtle is a low-alpha wash of the accent hue', () {
      // Same RGB as the accent — only the alpha differs, and it's subtle.
      final wash = AppColors.accentSubtle.toARGB32();
      final base = AppColors.accent.toARGB32();
      expect(wash & 0x00FFFFFF, base & 0x00FFFFFF);
      expect((wash >> 24) & 0xFF, lessThan(32));
    });

    test('royalBlue secondary accent matches steel blue (#2E6F8E)', () {
      expect(AppColors.royalBlue, const Color(0xFF2E6F8E));
    });

    test('gold emphasis accent resolves in both themes', () {
      expect(AppColorsLight.gold, const Color(0xFFA68A3C));
      expect(AppColorsDark.gold, const Color(0xFFD6B678));
    });
  });

  group('Light theme wiring', () {
    final theme = AppTheme.lightTheme;

    test('is brightness-light only', () {
      expect(theme.brightness, Brightness.light);
    });

    test('scaffold background uses the warm ivory bg token', () {
      expect(theme.scaffoldBackgroundColor, AppColors.bg);
    });

    test('color scheme primary is the evergreen accent', () {
      expect(theme.colorScheme.primary, AppColors.accent);
      expect(theme.colorScheme.surface, AppColors.card);
    });

    test('card shadow spec: warm black double shadow, blur 20 + blur 5', () {
      final shadows = AppColors.cardShadow;
      expect(shadows.length, 2);
      // The dominant (first) shadow carries most of the elevation.
      final main = shadows.first;
      expect(main.color, const Color(0x12201B10));
      expect(main.blurRadius, 20);
      expect(main.offset, const Offset(0, 10));
    });
  });

  group('Hero gradient', () {
    test('runs from evergreen into deep ink-green', () {
      expect(AppColors.heroGradientStart, const Color(0xFF244A37));
      expect(AppColors.heroGradientEnd, const Color(0xFF123A2A));
    });
  });

  group('Calendar marker tokens', () {
    test('win/loss/neutral are three distinct hues', () {
      final hues = {
        AppColors.markerWin,
        AppColors.markerLoss,
        AppColors.markerNeutral,
      };
      expect(hues.length, 3);
    });

    test('marker values match the documented hex codes', () {
      expect(AppColors.markerWin, const Color(0xFF1FA368));
      expect(AppColors.markerLoss, const Color(0xFFE05555));
      expect(AppColors.markerNeutral, const Color(0xFF8A6D2A));
    });
  });
}