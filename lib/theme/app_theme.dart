import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';

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

  /// Border for *controls* — outlined buttons, segmented tracks, checkbox-like
  /// affordances.
  ///
  /// Deliberately separate from [outline] and [outlineStrong]. Those are tuned
  /// for large panel edges, where the border is a subtle separator; a 1.2px
  /// control border needs to be readable as a boundary, and `outline` in dark
  /// mode is `#32323E` on a `#1E1E26` card — about 1.2:1, i.e. invisible. That
  /// is what left an outlined button looking like loose text floating on the
  /// card.
  final Color controlBorder;

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

  /// Solid brand fills that sit *behind white content* (primary buttons, the
  /// logo, avatars, active chips).
  ///
  /// These deliberately duplicate [brandSolid] in light mode and exist because
  /// of a real dark-mode bug: [brandSolid] is *lightened* in dark so it works
  /// as text on a dark surface, but it was also being used as a fill behind
  /// white glyphs. That produced a washed-out periwinkle→mauve ramp on every
  /// primary button, with white text at roughly 2:1 contrast.
  ///
  /// `brandSolid` = "brand colour as foreground", `brandFill` = "brand colour
  /// as background". Mixing them up is what made dark mode look unfinished.
  final Color brandFill;
  final Color brandFillDeep;

  /// The danger equivalent of [brandFill], for destructive buttons.
  final Color dangerFill;

  /// The deep end of the danger gradient, i.e. [dangerFill] pushed toward
  /// black. Kept as its own token (rather than derived at the call site) so the
  /// destructive ramp is defined in exactly one place, the same way
  /// [brandFill] / [brandFillDeep] are, and so it can be tuned per theme
  /// without touching every button.
  final Color dangerFillDeep;

  // ── Floating-glass tokens ──
  // Glass is now rationed to ONE surface (the floating nav pill). Everything
  // else uses the solid surfaces below, so these only tune that pill.
  final Color glassFill; // solid card surface (opaque)
  final Color glassFillStrong; // emphasised solid surface (opaque)
  final Color glassBorder; // 1px glass edge

  /// Backdrop blur sigma. Consumed only by `AppGlassLevel.floating`, so this
  /// value can be generous without the rest of the app paying for it.
  final double glassBlur;

  // ── Minimal surface-engine tokens (all alpha derivations of the palette) ──
  /// Crisp hairline used for the *outer* glass edge. `glassBorder` stays as the
  /// legacy white edge; this is the one tuned to sit on the light surface
  /// without looking like a drawn outline.
  final Color glassHairline;

  /// The bright specular refraction band along the top edge of a glass panel.
  /// Physically this is the highlight you get when light catches a bevelled
  /// edge; it is what separates a "flat translucent rectangle" from glass.
  final Color glassSpecular;

  /// Raised glass — the floating nav pill and sheets. Sits between
  /// [glassFillStrong] and an opaque surface so content scrolling underneath
  /// stays legible instead of ghosting through the labels.
  final Color glassElevated;

  /// Pressed-state overlay for glass surfaces. Neutral, so it works with any
  /// semantic tint applied on top.
  final Color glassPress;

  /// Modal scrim. Tuned to the app background so dimming a screen never shifts
  /// the hue of the palette.
  final Color glassScrim;

  /// Tint of the shadow cast by a glass panel. Kept in the theme (rather than
  /// hardcoded per widget) so dark mode can deepen it.
  final Color glassShadow;

  /// Faint inner top-edge highlight used in dark mode to fake a bevelled lip.
  final Color glassInnerGlow;

  /// A very low-alpha fill used for slots that sit *inside* another glass
  /// surface (segmented controls, nested chips) so nesting still reads as
  /// depth rather than as a flat patch.
  final Color glassNested;

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
    required this.controlBorder,
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
    required this.brandFill,
    required this.brandFillDeep,
    required this.dangerFill,
    required this.dangerFillDeep,
    required this.glassFill,
    required this.glassFillStrong,
    required this.glassBorder,
    required this.glassBlur,
    required this.glassHairline,
    required this.glassSpecular,
    required this.glassElevated,
    required this.glassPress,
    required this.glassScrim,
    required this.glassShadow,
    required this.glassInnerGlow,
    required this.glassNested,
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
    // Darkened from #777582, which measured 4.37:1 on the white card — just
    // under the 4.5:1 floor. `inkFaint` carries every secondary label in the
    // app (dates, "3 sales", "Cost of goods sold"), so it is text, not
    // decoration, and it has to clear the bar.
    inkFaint: Color(0xFF6E6A74),
    surface: Color(0xFFF7F4F2),
    surface2: Color(0xFFFBF9F8),
    surfaceHigh: Color(0xFFF1EEF0),
    surfaceHighest: Color(0xFFE7E2E5),
    outline: Color(0xFFD9D7DC),
    outlineStrong: Color(0xFFC2C0C8),
    // Darker than `outline` so the edge reads on a near-white page.
    controlBorder: Color(0xFFB4B1BB),
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
    // Light mode: the foreground and fill roles coincide, so these simply
    // mirror the solids.
    brandFill: Color(0xFF3D5387),
    brandFillDeep: Color(0xFF182346),
    dangerFill: Color(0xFF7E4A63),
    // Darker end of the destructive ramp, so the gradient reads as one
    // surface catching light rather than two unrelated colours.
    dangerFillDeep: Color(0xFF5A3348),
    // ── Minimal surfaces (2027) ──
    // Content surfaces are now OPAQUE. Translucency was the single biggest
    // source of both the "washed out" look and the render cost: every card
    // needed a `BackdropFilter`, which forces an offscreen pass per surface.
    // Cards are solid; only the floating nav pill still refracts (see
    // `AppGlassLevel.floating`).
    glassFill: Color(0xFFFFFFFF), // card surface
    glassFillStrong: Color(0xFFFFFFFF),
    glassBorder: Color(0xFFFFFFFF),
    // Only the floating nav pill consumes this now, so it can afford a real
    // sigma without the whole screen paying for it.
    glassBlur: 18.0,
    // ── glass engine ──
    // A hairline that is *slightly* darker than white so the panel edge is
    // actually perceivable against the near-white light background, instead of
    // vanishing the way a pure white border does.
    glassHairline: Color(0x140E0D15),
    // The bevel highlight across the top ~7% of a panel. Only the floating nav
    // pill paints this now, so it can stay bright without bleaching cards.
    glassSpecular: Color(0x99FFFFFF),
    // Filled/inset slots — search fields, chips, icon tiles, segmented tracks.
    // One deliberate tone step away from the card surface, which is how the
    // eye tells "control" from "content" without a single shadow.
    glassElevated: Color(0xFFF2F0F4),
    glassPress: Color(0x0A182346),
    glassScrim: Color(0x5C0E0D15),
    // Much softer than the old glass shadow. Flat design separates layers with
    // tone and a hairline, not by dropping shadows.
    glassShadow: Color(0x14182346),
    glassInnerGlow: Color(0x00FFFFFF),
    // Nested slot (segmented control track, inactive chip) on a light surface.
    glassNested: Color(0x0F182346),
  );

  static const _dark = AppColors(
    // Tints are the semantic colour wash on a card. In dark they were 20%
    // alpha over a near-black base, which collapsed them all into the same
    // grey-blue — every KPI tile looked identical. Raised to ~30% and given
    // genuinely distinct hues so "revenue" and "expenses" are told apart at a
    // glance, which is the entire point of a tinted dashboard.
    saleTint: Color(0x4D3D5387),
    purchaseTint: Color(0x4D1B2A5E),
    expenseTint: Color(0x4DBFA9BA),
    profitTint: Color(0x4D2E6B4E),
    inventoryTint: Color(0x4D7C83AD),
    khataTint: Color(0x4D8A7D9A),
    cashTint: Color(0x4D5E8A7C),
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
    // Neutral ramp, warm-neutral like light mode, but lifted well off pure
    // black.
    //
    // These were a saturated blue-navy ramp (#0E0D15 / #141A2A / #202D4E) while
    // light is a desaturated warm grey (#F7F4F2), which is most of why dark
    // looked muddy. They were then retuned too far the other way: #0D0D11 is
    // effectively black on an OLED panel, so the page had no depth, the cards
    // merged into it, and the heavy black shadows crushed what separation was
    // left. This ramp is a soft near-black that still reads as "dark" while
    // giving every layer somewhere to sit.
    surface: Color(0xFF14141A),
    surface2: Color(0xFF1E1E26),
    surfaceHigh: Color(0xFF2A2A34),
    surfaceHighest: Color(0xFF373743),
    outline: Color(0xFF32323E),
    outlineStrong: Color(0xFF474753),
    // Much lighter than `outline`/`outlineStrong`. A dark border on a dark card
    // is invisible, and an outlined control with no visible edge is not a
    // control at all - it is loose text on a surface.
    controlBorder: Color(0xFF56566A),
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
    // The *fills* stay dark and saturated in dark mode so white glyphs keep a
    // real contrast ratio (>= 6:1). Previously these reused the lightened
    // foreground values, which is why every primary button in dark mode was a
    // pale periwinkle ramp with barely-legible white text.
    brandFill: Color(0xFF44548A),
    brandFillDeep: Color(0xFF1F2A4C),
    dangerFill: Color(0xFF7E4A63),
    dangerFillDeep: Color(0xFF4E2B3D),
    // Cards are opaque here too. The old 7%-alpha fill made every card a hole
    // in the page — text behind it bled through and the palette washed out.
    glassFill: Color(0xFF1E1E26),
    glassFillStrong: Color(0xFF2A2A34),
    glassBorder: Color(0x1AFFFFFF),
    // The nav pill is the only blurrable surface, and it sits over dark content
    // where a heavy sigma costs more — 14 reads as frosted and stays cheap.
    glassBlur: 14.0,
    // ── glass engine ──
    // In dark mode the edge has to *lighten* — a dark hairline on a dark glass
    // panel is invisible, which is exactly the bug the light theme does not
    // have. So the hairline flips to a faint white.
    // The hairline was 12% white, which vanished against the near-black card.
    // Dark surfaces need a *stronger* edge than light ones, not a weaker one.
    glassHairline: Color(0x24FFFFFF),
    glassSpecular: Color(0x33FFFFFF),
    // Raised/inset slots in dark: one step *lighter* than the card, matching
    // the convention that a filled control sits above the surface.
    glassElevated: Color(0xFF2A2A34),
    glassPress: Color(0x1AFFFFFF),
    glassScrim: Color(0x99000000),
    // Dark mode needs a deeper shadow than light: on a near-black page a
    // low-alpha shadow is invisible, so separation has to come from the
    // hairline and the tone step instead.
    // A 35% black shadow on an already near-black page crushes the card
    // edges and makes the surface look flat and "fully black". Depth in dark
    // comes from the tone step and the hairline, so this is only a light
    // grounding shadow.
    glassShadow: Color(0x2E000000),
    glassInnerGlow: Color(0x1AFFFFFF),
    // Text fields and nested slots: 12% white was invisible on a near-black
    // card, so an input looked identical to the surface behind it.
    glassNested: Color(0x1AFFFFFF),
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
    Color? outline, Color? outlineStrong, Color? controlBorder,
    Color? primary, Color? primaryStrong, Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? accent, Color? onAccent, Color? accentContainer,
    Color? brandSolid, Color? brandSolidStrong, Color? dangerSolid,
    Color? brandFill, Color? brandFillDeep, Color? dangerFill,
    Color? dangerFillDeep,
    Color? glassFill, Color? glassFillStrong,
    Color? glassBorder, double? glassBlur,
    Color? glassHairline, Color? glassSpecular, Color? glassElevated,
    Color? glassPress, Color? glassScrim, Color? glassShadow,
    Color? glassInnerGlow, Color? glassNested,
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
    controlBorder: controlBorder ?? this.controlBorder,
    primary: primary ?? this.primary,
    primaryStrong: primaryStrong ?? this.primaryStrong,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentContainer: accentContainer ?? this.accentContainer,
    brandSolid: brandSolid ?? this.brandSolid,
    brandSolidStrong: brandSolidStrong ?? this.brandSolidStrong,
    brandFill: brandFill ?? this.brandFill,
    brandFillDeep: brandFillDeep ?? this.brandFillDeep,
    dangerFill: dangerFill ?? this.dangerFill,
    dangerFillDeep: dangerFillDeep ?? this.dangerFillDeep,
    dangerSolid: dangerSolid ?? this.dangerSolid,
    glassFill: glassFill ?? this.glassFill,
    glassFillStrong: glassFillStrong ?? this.glassFillStrong,
    glassBorder: glassBorder ?? this.glassBorder,
    glassBlur: glassBlur ?? this.glassBlur,
    glassHairline: glassHairline ?? this.glassHairline,
    glassSpecular: glassSpecular ?? this.glassSpecular,
    glassElevated: glassElevated ?? this.glassElevated,
    glassPress: glassPress ?? this.glassPress,
    glassScrim: glassScrim ?? this.glassScrim,
    glassShadow: glassShadow ?? this.glassShadow,
    glassInnerGlow: glassInnerGlow ?? this.glassInnerGlow,
    glassNested: glassNested ?? this.glassNested,
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
      onPrimary: ac.surface,
      primaryContainer: ac.primaryContainer,
      onPrimaryContainer: ac.onPrimaryContainer,
      secondary: const Color(0xFF3D5387),
      onSecondary: const Color(0xFFF5F2F4),
      secondaryContainer: const Color(0xFF26365F),
      // Was the mauve `#BFA9BA`, which leaked into any container that used it
      // and read as a pink smudge against the blue palette.
      onSecondaryContainer: const Color(0xFFBFC4DE),
      error: ac.dangerFill,
      onError: Colors.white,
      // Also was the mauve. `tertiary` is picked up by Material components
      // (chips, progress, some button states), so a pink value here showed up
      // in places nobody explicitly themed.
      tertiary: const Color(0xFF6E7BA8),
      onTertiary: Colors.white,
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
        // NOTE: the fill must stay *translucent*. It used to be
        // `surfaceContainerLowest` (≈91% opaque white), which painted a
        // near-solid slab with 13px corners inside every glass search pill —
        // that was the "white box floating in the rounded field" bug. A text
        // field is glass too: it lets the blurred backdrop through.
        filled: true,
        fillColor: appColors.glassNested,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: GlassUtil.hairline(appColors.glassHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: GlassUtil.hairline(appColors.glassHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          // Focus is communicated with weight + colour, never by removing the
          // border (the pro-rules forbid dropping focus affordances).
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: cs.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: cs.error, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: inter.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
        hintStyle: inter.bodyMedium?.copyWith(color: appColors.inkFaint, fontWeight: FontWeight.w500),
        helperStyle: inter.bodySmall?.copyWith(color: appColors.inkFaint),
        errorStyle: inter.bodySmall?.copyWith(color: cs.error, fontWeight: FontWeight.w600),
        // Errors belong next to the field that caused them.
        helperMaxLines: 2,
        errorMaxLines: 2,
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