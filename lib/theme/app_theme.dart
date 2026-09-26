import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// The liquid-glass design tokens, mirroring the canonical mockup
/// (`liquid_glass_mockup.html`): domain tint/fg pairs, ink scale, glass
/// surface tokens, blur radii, orb colors, plus the FIXED "solid" tokens.
///
/// Glass rule (mockup v1): glass surfaces are translucent fills
/// (`glassFill`) sampled over whatever sits behind them. Semantic tints are
/// translucent color overlays on the glass. Ink and -fg tokens are *lightened*
/// in dark mode for use as on-glass TEXT. Any card that pairs a solid colored
/// fill with fixed white content must source that fill from `brandSolid` /
/// `brandSolidStrong` / `dangerSolid`.
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

  // ── Liquid glass tokens ──
  final Color orb1; // teal orb
  final Color orb2; // indigo orb
  final Color orb3; // coral orb
  final Color glassFill; // base glass surface fill
  final Color glassFillStrong; // emphasised glass surface
  final Color glassBorder; // 1px glass edge
  final Color glassGloss; // top-edge light refraction line
  final double glassBlur; // backdrop blur sigma

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
    required this.orb1,
    required this.orb2,
    required this.orb3,
    required this.glassFill,
    required this.glassFillStrong,
    required this.glassBorder,
    required this.glassGloss,
    required this.glassBlur,
  });

  static const _light = AppColors(
    // Translucent domain tints derived from the reference palette
    // (slate blue / periwinkle / dusty mauve) so they blend over the glass fill.
    saleTint: Color(0xCCE0E5F1),
    purchaseTint: Color(0xCCE8EBF4),
    expenseTint: Color(0xCCF1E8ED),
    profitTint: Color(0xCCECECF4),
    inventoryTint: Color(0xCCE3E7F1),
    khataTint: Color(0xCCDEE3F0),
    cashTint: Color(0xCCECECF4),
    saleFg: Color(0xFF3D5387),
    purchaseFg: Color(0xFF182346),
    expenseFg: Color(0xFF7E4A63),
    profitFg: Color(0xFF4A5C97),
    inventoryFg: Color(0xFF5B6390),
    khataFg: Color(0xFF2A3A6B),
    cashFg: Color(0xFF3F4C7C),
    ink: Color(0xFF0E0D15),
    inkSoft: Color(0xFF3D3B45),
    inkFaint: Color(0xFF777582),
    surface: Color(0xFFF7F4F2),
    surface2: Color(0xFFFBF9F8),
    surfaceHigh: Color(0xFFF1EEF0),
    surfaceHighest: Color(0xFFE7E2E5),
    outline: Color(0xFFD9D7DC),
    outlineStrong: Color(0xFFC2C0C8),
    primary: Color(0xFF182346),
    primaryStrong: Color(0xFF0E0D15),
    primaryContainer: Color(0xFFE3E7F1),
    onPrimaryContainer: Color(0xFF182346),
    accent: Color(0xFFBFA9BA),
    onAccent: Color(0xFF0E0D15),
    accentContainer: Color(0xFFF1E8ED),
    brandSolid: Color(0xFF3D5387),
    brandSolidStrong: Color(0xFF182346),
    dangerSolid: Color(0xFF7E4A63),
    orb1: Color(0x667C83AD),
    orb2: Color(0x4D3D5387),
    orb3: Color(0x59BFA9BA),
    glassFill: Color(0xB3FFFFFF), // ~70% frosted white
    glassFillStrong: Color(0xE8FFFFFF),
    glassBorder: Color(0xFFFFFFFF),
    glassGloss: Color(0x66FFFFFF),
    glassBlur: 24.0,
  );

  static const _dark = AppColors(
    saleTint: Color(0x333D5387),
    purchaseTint: Color(0x3D182346),
    expenseTint: Color(0x3DBFA9BA),
    profitTint: Color(0x337C83AD),
    inventoryTint: Color(0x337C83AD),
    khataTint: Color(0x33182346),
    cashTint: Color(0x337C83AD),
    saleFg: Color(0xFF9AA2D0),
    purchaseFg: Color(0xFF8E9AD6),
    expenseFg: Color(0xFFD3AFC0),
    profitFg: Color(0xFFAEB5E0),
    inventoryFg: Color(0xFF9AA2D0),
    khataFg: Color(0xFF8B97D4),
    cashFg: Color(0xFFAEB5E0),
    ink: Color(0xFFF5F2F4),
    inkSoft: Color(0xFFC7C5CF),
    inkFaint: Color(0xFF9A98A5),
    surface: Color(0xFF0E0D15),
    surface2: Color(0xFF141A2A),
    surfaceHigh: Color(0xFF202D4E),
    surfaceHighest: Color(0xFF2D3B61),
    outline: Color(0xFF34405D),
    outlineStrong: Color(0xFF4A5777),
    primary: Color(0xFF7C83AD),
    primaryStrong: Color(0xFFBFA9BA),
    primaryContainer: Color(0xFF182346),
    onPrimaryContainer: Color(0xFFF5F2F4),
    accent: Color(0xFFBFA9BA),
    onAccent: Color(0xFF0E0D15),
    accentContainer: Color(0xFF3A3040),
    brandSolid: Color(0xFF7C83AD),
    brandSolidStrong: Color(0xFFBFA9BA),
    dangerSolid: Color(0xFFC8A2B6),
    orb1: Color(0x593D5387),
    orb2: Color(0x4D7C83AD),
    orb3: Color(0x4DBFA9BA),
    glassFill: Color(0x12FFFFFF),
    glassFillStrong: Color(0x1FFFFFFF),
    glassBorder: Color(0x1AFFFFFF),
    glassGloss: Color(0x1FFFFFFF),
    glassBlur: 16.0,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? _dark;

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
    Color? orb1, Color? orb2, Color? orb3,
    Color? glassFill, Color? glassFillStrong,
    Color? glassBorder, Color? glassGloss, double? glassBlur,
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
    orb1: orb1 ?? this.orb1,
    orb2: orb2 ?? this.orb2,
    orb3: orb3 ?? this.orb3,
    glassFill: glassFill ?? this.glassFill,
    glassFillStrong: glassFillStrong ?? this.glassFillStrong,
    glassBorder: glassBorder ?? this.glassBorder,
    glassGloss: glassGloss ?? this.glassGloss,
    glassBlur: glassBlur ?? this.glassBlur,
  );

  @override
  ThemeExtension<AppColors> lerp(covariant ThemeExtension<AppColors>? other, double t) => this;
}

class AppTheme {
  // Backwards-compatible aliases mapped onto the new liquid palette so
  // existing screens keep compiling while they are progressively restyled.
  static const ink = Color(0xFF0E0D15);
  static const inkSoft = Color(0xFF3D3B45);
  static const inkFaint = Color(0xFF777582);
  static const teal = Color(0xFF3D5387);
  static const tealDark = Color(0xFF182346);
  static const amber = Color(0xFF7C83AD);
  static const terracotta = Color(0xFF7E4A63);
  static const sage = Color(0xFF4A5C97);
  static const bgLight = Color(0xFFF7F4F2);
  static const bgDark = Color(0xFF0E0D15);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surface2Light = Color(0xFFFBF9F8);
  static const surfaceDark = Color(0xFF141A2A);
  static const surface2Dark = Color(0xFF0E0D15);

  static ThemeData light() {
    final ac = AppColors._light;
    final cs = _scheme(
      brightness: Brightness.light,
      primary: ac.primary,
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: ac.primaryContainer,
      onPrimaryContainer: ac.onPrimaryContainer,
      secondary: const Color(0xFF3D5387),
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFFE4E8F2),
      onSecondaryContainer: const Color(0xFF182346),
      error: ac.dangerSolid,
      onError: const Color(0xFFFFFFFF),
      tertiary: const Color(0xFF7C83AD),
      onTertiary: const Color(0xFFFFFFFF),
      surface: ac.surface,
      onSurface: ac.ink,
      surfaceContainerLowest: ac.glassFillStrong,
      surfaceContainerLow: const Color(0xFFFBF9F8),
      surfaceContainerHigh: const Color(0xFFF1EEF0),
      surfaceContainerHighest: const Color(0xFFE7E2E5),
      onSurfaceVariant: ac.inkSoft,
      outline: ac.outlineStrong,
      outlineVariant: ac.outline,
      shadow: const Color(0x330E0D15),
    );
    return _base(cs, ac);
  }

  static ThemeData dark() {
    final ac = AppColors._dark;
    final cs = _scheme(
      brightness: Brightness.dark,
      primary: ac.primary,
      onPrimary: const Color(0xFF0E0D15),
      primaryContainer: ac.primaryContainer,
      onPrimaryContainer: ac.onPrimaryContainer,
      secondary: const Color(0xFF3D5387),
      onSecondary: const Color(0xFFF5F2F4),
      secondaryContainer: const Color(0xFF26365F),
      onSecondaryContainer: const Color(0xFFBFA9BA),
      error: const Color(0xFFC8A2B6),
      onError: const Color(0xFF0E0D15),
      tertiary: const Color(0xFFBFA9BA),
      onTertiary: const Color(0xFF0E0D15),
      surface: ac.surface,
      onSurface: ac.ink,
      surfaceContainerLowest: ac.surface2,
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
    Color? tertiary,
    Color? onTertiary,
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
      tertiary: tertiary ?? primary,
      onTertiary: onTertiary ?? onPrimary,
      error: error,
      onError: onError,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceContainer: surfaceContainerHigh,
      surfaceDim: surface,
      surfaceBright: surfaceContainerHigh,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: shadow,
    );
  }

  static ThemeData _base(ColorScheme cs, AppColors appColors) {
    final inter = GoogleFonts.interTextTheme();
    final manrope = GoogleFonts.manropeTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: inter.copyWith(
        displayLarge: inter.displayLarge?.copyWith(
            fontFamily: 'Inter', fontWeight: FontWeight.w800, letterSpacing: -0.02),
        displayMedium: inter.displayMedium?.copyWith(
            fontFamily: 'Inter', fontWeight: FontWeight.w800, letterSpacing: -0.02),
        displaySmall: inter.displaySmall?.copyWith(
            fontFamily: 'Inter', fontWeight: FontWeight.w800, letterSpacing: -0.02),
        headlineLarge: inter.headlineLarge?.copyWith(
            fontFamily: 'Inter', fontWeight: FontWeight.w800, letterSpacing: -0.02),
        headlineMedium: inter.headlineMedium?.copyWith(
            fontFamily: 'Inter', fontWeight: FontWeight.w800, letterSpacing: -0.02),
        headlineSmall: inter.headlineSmall?.copyWith(
            fontFamily: 'Inter', fontWeight: FontWeight.w800, letterSpacing: -0.02),
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

  /// Inter display style for numerals/headings used across the design system
  /// (herro amounts, KPI values, big totals) — tabular figures by default.
  static TextStyle display(BuildContext context, {double size = 21, FontWeight weight = FontWeight.w800, Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: const ['sans-serif'],
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.01,
      color: color ?? cs.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static const appTitleStyle = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 15.5,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.01,
  );
}