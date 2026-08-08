import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// The v3 design-system color roles, mirroring the tokens in the canonical
/// mockup (`foam-shop-pos-mockup.html`): domain tint/fg pairs, ink scale,
/// surfaces, outline, primary/accent families, plus the FIXED "solid" tokens.
///
/// Dark-mode rule (NFR-9 / mockup v3.3): `--primary`/`--expense-fg` and the
/// other `-fg` tokens are intentionally *lightened* in dark mode for use as
/// on-dark-surface TEXT. Any card/badge/button that pairs a solid colored
/// fill with fixed white content must source that fill from `brandSolid` /
/// `brandSolidStrong` / `dangerSolid`, which stay a constant rich color in
/// both themes.
class AppColors extends ThemeExtension<AppColors> {
  // ── Domain tint + fg pairs ──
  final Color saleTint;
  final Color purchaseTint;
  final Color expenseTint;
  final Color profitTint;
  final Color inventoryTint;
  final Color khataTint;
  final Color cashTint;

  final Color saleFg;
  final Color purchaseFg;
  final Color expenseFg;
  final Color profitFg;
  final Color inventoryFg;
  final Color khataFg;
  final Color cashFg;

  // ── Ink scale ──
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;

  // ── Surfaces & outlines ──
  final Color surface;
  final Color surface2;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color outline;
  final Color outlineStrong;

  // ── Primary family ──
  final Color primary;
  final Color primaryStrong;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  // ── Accent family ──
  final Color accent;
  final Color onAccent;
  final Color accentContainer;

  // ── Fixed "solid" tokens (constant in both themes) ──
  final Color brandSolid;
  final Color brandSolidStrong;
  final Color dangerSolid;

  const AppColors({
    required this.saleTint,
    required this.purchaseTint,
    required this.expenseTint,
    required this.profitTint,
    required this.inventoryTint,
    required this.khataTint,
    required this.cashTint,
    required this.saleFg,
    required this.purchaseFg,
    required this.expenseFg,
    required this.profitFg,
    required this.inventoryFg,
    required this.khataFg,
    required this.cashFg,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.surface,
    required this.surface2,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.outline,
    required this.outlineStrong,
    required this.primary,
    required this.primaryStrong,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.brandSolid,
    required this.brandSolidStrong,
    required this.dangerSolid,
  });

  static const _light = AppColors(
    saleTint: Color(0xFFDEF3E7),
    purchaseTint: Color(0xFFFAEDD3),
    expenseTint: Color(0xFFFBE2DC),
    profitTint: Color(0xFFE7E3FB),
    inventoryTint: Color(0xFFF2E4FB),
    khataTint: Color(0xFFDCF0F4),
    cashTint: Color(0xFFDBEFE0),
    saleFg: Color(0xFF1B7A56),
    purchaseFg: Color(0xFFB07417),
    expenseFg: Color(0xFFC13F2C),
    profitFg: Color(0xFF2C2760),
    inventoryFg: Color(0xFF7C3FB0),
    khataFg: Color(0xFF0E6E82),
    cashFg: Color(0xFF166534),
    ink: Color(0xFF1B1A2A),
    inkSoft: Color(0xFF5B5A72),
    inkFaint: Color(0xFF9694AC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFBFAFF),
    surfaceHigh: Color(0xFFF1EEFA),
    surfaceHighest: Color(0xFFE6E2F5),
    outline: Color(0xFFE4E0F2),
    outlineStrong: Color(0xFFD3CDEA),
    primary: Color(0xFF3E3878),
    primaryStrong: Color(0xFF2C2760),
    primaryContainer: Color(0xFFE7E3FB),
    onPrimaryContainer: Color(0xFF2C2760),
    accent: Color(0xFFC9852B),
    onAccent: Color(0xFF2A1A00),
    accentContainer: Color(0xFFFBEBD2),
    brandSolid: Color(0xFF3E3878),
    brandSolidStrong: Color(0xFF241F52),
    dangerSolid: Color(0xFFC13F2C),
  );

  static const _dark = AppColors(
    saleTint: Color(0xFF173829),
    purchaseTint: Color(0xFF3B2E10),
    expenseTint: Color(0xFF3B2019),
    profitTint: Color(0xFF312B5C),
    inventoryTint: Color(0xFF332756),
    khataTint: Color(0xFF123640),
    cashTint: Color(0xFF123626),
    saleFg: Color(0xFF6FE0AE),
    purchaseFg: Color(0xFFF0C877),
    expenseFg: Color(0xFFF29483),
    profitFg: Color(0xFFC7BEFF),
    inventoryFg: Color(0xFFDBB4F7),
    khataFg: Color(0xFF7BDCEF),
    cashFg: Color(0xFF7EE0A8),
    ink: Color(0xFFEDEBFA),
    inkSoft: Color(0xFFB7B4D1),
    inkFaint: Color(0xFF817EA0),
    surface: Color(0xFF1E1A38),
    surface2: Color(0xFF231F41),
    surfaceHigh: Color(0xFF2A2650),
    surfaceHighest: Color(0xFF332D5E),
    outline: Color(0xFF332D5E),
    outlineStrong: Color(0xFF453D77),
    primary: Color(0xFFB7ADFF),
    primaryStrong: Color(0xFFCFC7FF),
    primaryContainer: Color(0xFF3A3372),
    onPrimaryContainer: Color(0xFFDCD5FF),
    accent: Color(0xFFF0B95C),
    onAccent: Color(0xFF3A2600),
    accentContainer: Color(0xFF4A3714),
    brandSolid: Color(0xFF3E3878),
    brandSolidStrong: Color(0xFF241F52),
    dangerSolid: Color(0xFFC13F2C),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? _light;

  @override
  ThemeExtension<AppColors> copyWith({
    Color? saleTint, Color? purchaseTint, Color? expenseTint,
    Color? profitTint, Color? inventoryTint, Color? khataTint, Color? cashTint,
    Color? saleFg, Color? purchaseFg, Color? expenseFg,
    Color? profitFg, Color? inventoryFg, Color? khataFg, Color? cashFg,
    Color? ink, Color? inkSoft, Color? inkFaint,
    Color? surface, Color? surface2, Color? surfaceHigh, Color? surfaceHighest,
    Color? outline, Color? outlineStrong,
    Color? primary, Color? primaryStrong, Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? accent, Color? onAccent, Color? accentContainer,
    Color? brandSolid, Color? brandSolidStrong, Color? dangerSolid,
  }) => AppColors(
    saleTint: saleTint ?? this.saleTint,
    purchaseTint: purchaseTint ?? this.purchaseTint,
    expenseTint: expenseTint ?? this.expenseTint,
    profitTint: profitTint ?? this.profitTint,
    inventoryTint: inventoryTint ?? this.inventoryTint,
    khataTint: khataTint ?? this.khataTint,
    cashTint: cashTint ?? this.cashTint,
    saleFg: saleFg ?? this.saleFg,
    purchaseFg: purchaseFg ?? this.purchaseFg,
    expenseFg: expenseFg ?? this.expenseFg,
    profitFg: profitFg ?? this.profitFg,
    inventoryFg: inventoryFg ?? this.inventoryFg,
    khataFg: khataFg ?? this.khataFg,
    cashFg: cashFg ?? this.cashFg,
    ink: ink ?? this.ink,
    inkSoft: inkSoft ?? this.inkSoft,
    inkFaint: inkFaint ?? this.inkFaint,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    surfaceHighest: surfaceHighest ?? this.surfaceHighest,
    outline: outline ?? this.outline,
    outlineStrong: outlineStrong ?? this.outlineStrong,
    primary: primary ?? this.primary,
    primaryStrong: primaryStrong ?? this.primaryStrong,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentContainer: accentContainer ?? this.accentContainer,
    brandSolid: brandSolid ?? this.brandSolid,
    brandSolidStrong: brandSolidStrong ?? this.brandSolidStrong,
    dangerSolid: dangerSolid ?? this.dangerSolid,
  );

  @override
  ThemeExtension<AppColors> lerp(covariant ThemeExtension<AppColors>? other, double t) => this;
}

class AppTheme {
  // Backwards-compatible aliases mapped onto the new v3 palette so existing
  // screens keep compiling while they are progressively restyled.
  static const ink = Color(0xFF1B1A2A);
  static const inkSoft = Color(0xFF5B5A72);
  static const inkFaint = Color(0xFF9694AC);
  static const teal = Color(0xFF3E3878); // brand indigo
  static const tealDark = Color(0xFF241F52); // brand solid strong
  static const amber = Color(0xFFC9852B);
  static const terracotta = Color(0xFFC13F2C);
  static const sage = Color(0xFF1B7A56);
  static const bgLight = Color(0xFFF1EEFA);
  static const bgDark = Color(0xFF16132A);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surface2Light = Color(0xFFFBFAFF);
  static const surfaceDark = Color(0xFF1E1A38);
  static const surface2Dark = Color(0xFF231F41);

  static ThemeData light() {
    final ac = AppColors._light;
    final cs = _scheme(
      brightness: Brightness.light,
      primary: ac.primary,
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: ac.primaryContainer,
      onPrimaryContainer: ac.onPrimaryContainer,
      secondary: ac.accent,
      onSecondary: ac.onAccent,
      secondaryContainer: ac.accentContainer,
      onSecondaryContainer: const Color(0xFF7A4F0A),
      error: ac.dangerSolid,
      onError: const Color(0xFFFFFFFF),
      surface: const Color(0xFFF1EEFA), // --bg
      onSurface: ac.ink,
      surfaceContainerLowest: ac.surface,
      surfaceContainerLow: ac.surface2,
      surfaceContainerHigh: ac.surfaceHigh,
      surfaceContainerHighest: ac.surfaceHighest,
      onSurfaceVariant: ac.inkSoft,
      outline: ac.outlineStrong,
      outlineVariant: ac.outline,
      shadow: const Color(0x1E1E143C),
    );
    return _base(cs, ac);
  }

  static ThemeData dark() {
    final ac = AppColors._dark;
    final cs = _scheme(
      brightness: Brightness.dark,
      primary: ac.primary,
      onPrimary: ac.onPrimaryContainer,
      primaryContainer: ac.primaryContainer,
      onPrimaryContainer: ac.onPrimaryContainer,
      secondary: ac.accent,
      onSecondary: ac.onAccent,
      secondaryContainer: ac.accentContainer,
      onSecondaryContainer: const Color(0xFFF0B95C),
      error: const Color(0xFFF29483),
      onError: const Color(0xFF3A1108),
      surface: const Color(0xFF16132A), // --bg
      onSurface: ac.ink,
      surfaceContainerLowest: ac.surface,
      surfaceContainerLow: ac.surface2,
      surfaceContainerHigh: ac.surfaceHigh,
      surfaceContainerHighest: ac.surfaceHighest,
      onSurfaceVariant: ac.inkSoft,
      outline: ac.outlineStrong,
      outlineVariant: ac.outline,
      shadow: Colors.black.withValues(alpha: 0.5),
    );
    return _base(cs, ac);
  }

  static ColorScheme _scheme({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color primaryContainer,
    required Color onPrimaryContainer,
    required Color secondary,
    required Color onSecondary,
    required Color secondaryContainer,
    required Color onSecondaryContainer,
    required Color error,
    required Color onError,
    required Color surface,
    required Color onSurface,
    required Color surfaceContainerLowest,
    required Color surfaceContainerLow,
    required Color surfaceContainerHigh,
    required Color surfaceContainerHighest,
    required Color onSurfaceVariant,
    required Color outline,
    required Color outlineVariant,
    required Color shadow,
  }) {
    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: primary,
      onTertiary: onPrimary,
      error: error,
      onError: onError,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: shadow,
    );
  }

  static ThemeData _base(ColorScheme cs, AppColors appColors) {
    final inter = GoogleFonts.interTextTheme();
    final manrope = GoogleFonts.manropeTextTheme();
    final fraunces = GoogleFonts.frauncesTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: inter.copyWith(
        displayLarge: fraunces.displayLarge?.copyWith(
            fontFamily: 'Fraunces', fontWeight: FontWeight.w600, letterSpacing: -0.01),
        displayMedium: fraunces.displayMedium?.copyWith(
            fontFamily: 'Fraunces', fontWeight: FontWeight.w600, letterSpacing: -0.01),
        displaySmall: fraunces.displaySmall?.copyWith(
            fontFamily: 'Fraunces', fontWeight: FontWeight.w600, letterSpacing: -0.01),
        headlineLarge: fraunces.headlineLarge?.copyWith(
            fontFamily: 'Fraunces', fontWeight: FontWeight.w600, letterSpacing: -0.01),
        headlineMedium: fraunces.headlineMedium?.copyWith(
            fontFamily: 'Fraunces', fontWeight: FontWeight.w600, letterSpacing: -0.01),
        headlineSmall: fraunces.headlineSmall?.copyWith(
            fontFamily: 'Fraunces', fontWeight: FontWeight.w600, letterSpacing: -0.01),
        titleLarge: manrope.titleLarge?.copyWith(
            fontFamily: 'Manrope', fontWeight: FontWeight.w700, letterSpacing: -0.01),
        titleMedium: manrope.titleMedium?.copyWith(
            fontFamily: 'Manrope', fontWeight: FontWeight.w700, letterSpacing: -0.01),
        titleSmall: manrope.titleSmall?.copyWith(
            fontFamily: 'Manrope', fontWeight: FontWeight.w700, letterSpacing: -0.01),
        labelLarge: manrope.labelLarge?.copyWith(
            fontFamily: 'Manrope', fontWeight: FontWeight.w700, letterSpacing: -0.01),
        labelMedium: manrope.labelMedium?.copyWith(
            fontFamily: 'Manrope', fontWeight: FontWeight.w700),
        labelSmall: manrope.labelSmall?.copyWith(
            fontFamily: 'Manrope', fontWeight: FontWeight.w700),
      ).apply(
        bodyColor: cs.onSurface,
        displayColor: cs.onSurface,
      ),
      scaffoldBackgroundColor: cs.surface,
      extensions: [appColors],
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: cs.shadow,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        titleTextStyle: manrope.titleLarge?.copyWith(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: 19,
          letterSpacing: -0.01,
          color: cs.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: manrope.labelLarge?.copyWith(
              fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.01),
          elevation: 0,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shadowColor: cs.primary.withValues(alpha: 0.35),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: cs.outlineVariant, width: 1.5),
          backgroundColor: cs.surfaceContainerLowest,
          foregroundColor: cs.primary,
          textStyle: manrope.labelLarge?.copyWith(
              fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.01),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: cs.outlineVariant, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: cs.outlineVariant, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: inter.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1, space: 0),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: manrope.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: manrope.labelSmall,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
          elevation: const WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textStyle: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.onSurface,
        contentTextStyle: TextStyle(color: cs.surface, fontWeight: FontWeight.w700, fontSize: 12.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(
            allowEnterRouteSnapshotting: false,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Fraunces display style for numerals/headings used across the design
  /// system (hero amounts, KPI values, big totals).
  static TextStyle display(BuildContext context, {double size = 21, FontWeight weight = FontWeight.w600, Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontFamily: 'Fraunces',
      fontFamilyFallback: const ['serif'],
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.01,
      color: color ?? cs.onSurface,
    );
  }

  static const appTitleStyle = TextStyle(
    fontFamily: 'Fraunces',
    fontFamilyFallback: ['serif'],
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01,
  );
}
