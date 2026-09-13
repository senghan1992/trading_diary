import 'package:flutter/material.dart';

/// Spacing scale — a 4dp rhythm with deliberate padding for breathing room.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Radius scale — gentle corners throughout, premium but never soft.
class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

// ─────────────────────────────────────────────────────────────────────────────
// THE LEDGER — a premium, calm financial journal.
//
//   Light  : warm paper (ivory) grounds, deep warm-ink text, evergreen
//            action accent, brass/gold emphasis. Reads like a crafted
//            financial instrument you can trust, not a cold dashboard.
//   Dark   : deep ink-green surfaces, brighter evergreen accent, muted
//            sage neutrals — restful for nightly review without glare.
//
// Referenced by the brightness-aware facade below; theme reads the LITERAL
// classes (never the mutable facade) so a theme built mid-transition can
// never capture the wrong brightness.
// ─────────────────────────────────────────────────────────────────────────────
class AppColorsDark {
  // --- Surfaces (ink-green, never pitch black) ---
  static const bg = Color(0xFF0E1310); // deep ink-green — scaffold
  static const card = Color(0xFF181F1A); // ledger-paper slate-green — cards
  static const surface = Color(0xFF222B24); // input wells / chips
  static const border = Color(0xFF2A342C); // hairlines

  // --- Text ---
  static const text = Color(0xFFEDF1E8); // warm paper white — primary text
  static const textMuted = Color(0xFF96A195); // sage — secondary text
  static const white = Color(0xFFFFFFFF);

  // --- Brand accents (evergreen) ---
  static const accent = Color(0xFF74CE9B); // bright evergreen — primary actions
  static const accentStrong = Color(0xFF8BDDB1); // pressed state
  static const accentSubtle = Color(0x2274CE9B); // ~13% evergreen wash
  static const royalBlue = Color(0xFF79B6D9); // steel-blue — secondary
  static const gold = Color(0xFFD6B678); // brass — premium emphasis

  // --- Hero gradient — slate-green into deep evergreen ---
  static const heroGradientStart = Color(0xFF1B2A20);
  static const heroGradientEnd = Color(0xFF0F3A2A);
}

/// Brightness-aware color facade.
///
/// All screen/widget code reads colors through `AppColors.*` exactly as
/// before, but every token now resolves against the *active* brightness
/// instead of being hard-wired to light values. The harness keeps the two
/// palettes in lockstep: see [AppColorsDark] for the dark counterparts.
///
/// [brightness] is kept in sync by `MaterialApp.builder` (see main.dart),
/// which runs on every theme or platform-brightness change. Because a
/// theme change also rebuilds the whole MaterialApp subtree, every screen
/// re-resolves these getters on the same frame.
/// Light palette — warm paper / evergreen premium tones.
abstract class AppColorsLight {
  // --- Surfaces (warm ivory paper) ---
  static const bg = Color(0xFFF6F4ED); // warm ivory — scaffold background
  static const card = Color(0xFFFFFFFF); // crisp paper — cards & sheets
  static const surface = Color(0xFFECE9DF); // warm sand — input wells/chips
  static const border = Color(0xFFE4DFD2); // warm hairline

  // --- Text (deep warm ink) ---
  static const text = Color(0xFF182019); // near-black green — primary text
  static const textMuted = Color(0xFF5E6A60); // sage-gray — secondary text
  static const white = Color(0xFFFFFFFF);

  // --- Brand accents (evergreen) ---
  static const accent = Color(0xFF1E5B45); // deep evergreen — primary actions
  static const accentStrong = Color(0xFF164736); // pressed state
  static const accentSubtle = Color(0x141E5B45); // ~8% evergreen wash
  static const royalBlue = Color(0xFF2E6F8E); // steel-blue — secondary
  static const gold = Color(0xFFA68A3C); // brass — premium emphasis

  // --- Hero gradient — evergreen into deep ink-green ---
  static const heroGradientStart = Color(0xFF244A37);
  static const heroGradientEnd = Color(0xFF123A2A);
}

abstract class AppColors {
  static Brightness _brightness = Brightness.light;

  static Brightness get brightness => _brightness;
  static bool get isDark => _brightness == Brightness.dark;

  /// Called from `MaterialApp.builder` before the subtree builds. Pure
  /// field assignment — safe during build, no notification needed because
  /// the theme change itself rebuilds the subtree.
  static void setBrightness(Brightness value) {
    _brightness = value;
  }

  // --- Surfaces ---
  static Color get bg => isDark ? AppColorsDark.bg : AppColorsLight.bg;
  static Color get card => isDark ? AppColorsDark.card : AppColorsLight.card;
  static Color get surface =>
      isDark ? AppColorsDark.surface : AppColorsLight.surface;
  static Color get border =>
      isDark ? AppColorsDark.border : AppColorsLight.border;

  // --- Text ---
  static Color get text => isDark ? AppColorsDark.text : AppColorsLight.text;
  static Color get textMuted =>
      isDark ? AppColorsDark.textMuted : AppColorsLight.textMuted;
  static Color get white => const Color(0xFFFFFFFF);

  // --- Brand accents ---
  static Color get accent =>
      isDark ? AppColorsDark.accent : AppColorsLight.accent;
  static Color get accentStrong =>
      isDark ? AppColorsDark.accentStrong : AppColorsLight.accentStrong;
  static Color get accentSubtle =>
      isDark ? AppColorsDark.accentSubtle : AppColorsLight.accentSubtle;
  static Color get royalBlue =>
      isDark ? AppColorsDark.royalBlue : AppColorsLight.royalBlue;
  static Color get gold =>
      isDark ? AppColorsDark.gold : AppColorsLight.gold;

  // --- Hero gradient (portfolio card) ---
  static Color get heroGradientStart => isDark
      ? AppColorsDark.heroGradientStart
      : AppColorsLight.heroGradientStart;
  static Color get heroGradientEnd =>
      isDark ? AppColorsDark.heroGradientEnd : AppColorsLight.heroGradientEnd;

  /// Standard card elevation — a soft, directionally-lit double shadow.
  /// Dark mode uses a heavier, blacker shadow so cards still separate from
  /// the ink-green background.
  static List<BoxShadow> get cardShadow => isDark
      ? const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x12201B10),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x0A201B10),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ];

  // --- Semantic status colors (shared across both modes) ---
  // Tuned for WCAG AA on paper (#FFFFFF): green ~4.7:1, red ~4.8:1 on
  // body text, while staying unmistakably green/red for P&L at a glance.
  static const green = Color(0xFF0E8345);
  static const greenBg = Color(0x1A0E8345);
  static const red = Color(0xFFC94040);
  static const redBg = Color(0x1AC94040);
  static const orange = Color(0xFFD98A28);
  static const orangeBg = Color(0x1AD98A28);
  static const blue = Color(0xFF2E75B6);
  static const blueBg = Color(0x1A2E75B6);

  // Calendar marker accents — tuned so they read at a glance on paper.
  static const markerWin = Color(0xFF1FA368); // emerald (wins)
  static const markerLoss = Color(0xFFE05555); // rose (losses)
  static const markerNeutral = Color(0xFF8A6D2A); // brass (open / notes)
}

class AppTheme {
  /// Warm-paper light theme — calm, premium, trustworthy.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorsLight.bg,
      colorScheme: ColorScheme.light(
        primary: AppColorsLight.accent,
        secondary: AppColorsLight.royalBlue,
        surface: AppColorsLight.card,
        onSurface: AppColorsLight.text,
        error: AppColors.red,
      ),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsLight.bg,
        foregroundColor: AppColorsLight.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColorsLight.text,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColorsLight.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColorsLight.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsLight.accent,
          foregroundColor: AppColorsLight.white,
          disabledBackgroundColor: AppColorsLight.accent.withValues(alpha: 0.25),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          elevation: 0,
          shadowColor: AppColorsLight.accentSubtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsLight.accent,
          side: BorderSide(
            color: AppColorsLight.accent.withValues(alpha: 0.5),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColorsLight.accent,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsLight.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColorsLight.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: TextStyle(
          color: AppColorsLight.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(
          color: AppColorsLight.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColorsLight.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColorsLight.card,
        indicatorColor: AppColorsLight.accentSubtle,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? AppColorsLight.accent : AppColorsLight.textMuted,
            letterSpacing: -0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColorsLight.accent : AppColorsLight.textMuted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColorsLight.card,
        indicatorColor: AppColorsLight.accentSubtle,
        selectedIconTheme: const IconThemeData(
          color: AppColorsLight.accent,
          size: 24,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColorsLight.textMuted,
          size: 24,
        ),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColorsLight.accent,
          letterSpacing: -0.2,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColorsLight.textMuted,
          letterSpacing: -0.2,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColorsLight.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColorsLight.text,
        contentTextStyle: TextStyle(
          color: AppColorsLight.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColorsLight.accent,
        foregroundColor: AppColorsLight.white,
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColorsLight.accent,
        linearTrackColor: Color(0x1A1E5B45),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColorsLight.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Color(0xFF182019),
          letterSpacing: -0.5,
          height: 1.15,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Color(0xFF182019),
          letterSpacing: -0.35,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF182019),
          letterSpacing: -0.25,
          height: 1.28,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF182019),
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF182019),
          letterSpacing: -0.1,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF182019),
          letterSpacing: -0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFF182019),
          height: 1.5,
          letterSpacing: -0.1,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF5E6A60),
          height: 1.45,
          letterSpacing: -0.1,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF5E6A60),
          height: 1.4,
          letterSpacing: -0.1,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF182019),
          letterSpacing: -0.1,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5E6A60),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Deep ink-green dark theme — restful for nightly review, never glare.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColorsDark.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColorsDark.accent,
        secondary: AppColorsDark.royalBlue,
        surface: AppColorsDark.card,
        onSurface: AppColorsDark.text,
        error: AppColors.red,
      ),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsDark.bg,
        foregroundColor: AppColorsDark.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColorsDark.text,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColorsDark.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColorsDark.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsDark.accent,
          foregroundColor: AppColorsDark.bg,
          disabledBackgroundColor: AppColorsDark.accent.withValues(alpha: 0.3),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          elevation: 0,
          shadowColor: AppColorsDark.accentSubtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsDark.accentStrong,
          side: const BorderSide(
            color: AppColorsDark.accent,
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColorsDark.accentStrong,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: AppColorsDark.accentStrong,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: const TextStyle(
          color: AppColorsDark.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: AppColorsDark.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColorsDark.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColorsDark.card,
        indicatorColor: AppColorsDark.accentSubtle,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected
                ? AppColorsDark.accentStrong
                : AppColorsDark.textMuted,
            letterSpacing: -0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected
                ? AppColorsDark.accentStrong
                : AppColorsDark.textMuted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColorsDark.card,
        indicatorColor: AppColorsDark.accentSubtle,
        selectedIconTheme: const IconThemeData(
          color: AppColorsDark.accentStrong,
          size: 24,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColorsDark.textMuted,
          size: 24,
        ),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColorsDark.accentStrong,
          letterSpacing: -0.2,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColorsDark.textMuted,
          letterSpacing: -0.2,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorsDark.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColorsDark.text,
        contentTextStyle: const TextStyle(
          color: AppColorsDark.bg,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColorsDark.accent,
        foregroundColor: AppColorsDark.bg,
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColorsDark.accentStrong,
        linearTrackColor: Color(0x33EDF1E8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColorsDark.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Color(0xFFEDF1E8),
          letterSpacing: -0.5,
          height: 1.15,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Color(0xFFEDF1E8),
          letterSpacing: -0.35,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFFEDF1E8),
          letterSpacing: -0.25,
          height: 1.28,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFEDF1E8),
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEDF1E8),
          letterSpacing: -0.1,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEDF1E8),
          letterSpacing: -0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFFEDF1E8),
          height: 1.5,
          letterSpacing: -0.1,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF96A195),
          height: 1.45,
          letterSpacing: -0.1,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF96A195),
          height: 1.4,
          letterSpacing: -0.1,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEDF1E8),
          letterSpacing: -0.1,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF96A195),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
