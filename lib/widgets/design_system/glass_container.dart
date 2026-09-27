import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../scale_button.dart' show ScaleButton;

/// How much presence a surface has.
///
/// The old system made translucency the default for *everything*, which is
/// what made the app read as "washed out" and expensive: every card, chip and
/// search field installed a `BackdropFilter`, and each one is a separate
/// offscreen render pass. The ui-ux-pro-max style database rates Liquid Glass
/// as "Performance: Moderate-Poor / A11y: text-contrast risk", so glass is now
/// rationed down to exactly one surface in the app — the floating nav pill,
/// where the frosted edge is the entire point.
enum AppGlassLevel {
  /// Content cards. Solid fill, hairline edge, whisper-soft shadow. This is
  /// what 95% of the app is built from.
  base,

  /// Filled/inset *controls* — search fields, chips, icon tiles, segmented
  /// tracks. One tone step away from [base] so "control" and "content" are
  /// distinguishable without lifting a shadow.
  raised,

  /// A slot *inside* another surface. No shadow, no border, no blur — it is a
  /// wash, not a panel.
  nested,

  /// The floating nav pill, and nothing else. The only level that blurs the
  /// backdrop, because it genuinely floats over scrolling content and the
  /// refraction is what separates it from the page.
  floating,
}

/// The core liquid-glass surface.
///
/// Painted in this order (the order matters — see the inline notes):
///  1. shadow    — cast by a wrapper, *never* by the clipped box
///  2. backdrop  — `BackdropFilter` inside the clip, so blur stays bounded
///  3. fill      — translucent, optionally blended with a semantic tint
///  4. specular  — bevel highlight along the top edge (foreground layer)
///  5. hairline  — the outer edge
///
/// Why the shadow lives on a wrapper: previously the shadow, the border and the
/// `ClipRRect` radius were declared on two different boxes. When those radii
/// drifted the renderer emitted a rectangular shadow that no longer lined up
/// with the rounded panel — the "ghost rectangle behind the card" on the
/// dashboard. One radius, one source of truth, no drift.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.radius = AppRadii.lg,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.tint,
    this.tintStrength = 1.0,
    this.fill,
    this.blur,
    this.level = AppGlassLevel.base,
    this.gloss = true,
    this.border,
    this.shadow,
    this.onTap,
    this.semanticLabel,
    this.selected = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// Optional semantic colour washed over the glass. Kept translucent so the
  /// blurred backdrop still reads through — an opaque tint is just a coloured
  /// card, not glass.
  final Color? tint;
  final double tintStrength;

  /// Overrides the level's default fill.
  final Color? fill;

  /// Overrides the level's default backdrop blur sigma.
  final double? blur;

  final AppGlassLevel level;

  /// The top-edge bevel highlight. Disable for very small or nested surfaces
  /// where the highlight is sub-pixel noise.
  final bool gloss;

  final Border? border;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  /// Read out by screen readers, required for icon-only controls.
  final String? semanticLabel;

  /// Exposes selected state to assistive tech (nav bar, chips, segments).
  final bool selected;

  Color _fillFor(AppColors ac) {
    final explicit = fill;
    if (explicit != null) return explicit;
    return switch (level) {
      AppGlassLevel.base => ac.glassFill,
      AppGlassLevel.raised => ac.glassElevated,
      AppGlassLevel.nested => ac.glassNested,
      // The pill is translucent on purpose — that is what you are seeing
      // through. It stays high-alpha so list content scrolling underneath
      // never collides with the nav labels.
      AppGlassLevel.floating => ac.glassElevated.withValues(alpha: 0.82),
    };
  }

  double _blurFor(AppColors ac) {
    final explicit = blur;
    if (explicit != null) return explicit;
    return switch (level) {
      AppGlassLevel.nested => 0,
      // Solid surfaces never blur. A `BackdropFilter` is not free — it forces
      // Flutter to snapshot and re-blur everything painted behind it, so
      // having one per card is what made scrolling stutter on low-end phones.
      AppGlassLevel.base => 0,
      AppGlassLevel.raised => 0,
      AppGlassLevel.floating => ac.glassBlur,
    };
  }

  /// Shadow policy per level.
  ///
  /// Minimal design separates layers with *tone and a hairline*, not with
  /// drop shadows — a 22px/10px-offset shadow under every card is what made
  /// the old UI look heavy. So:
  ///  * [AppGlassLevel.nested] — no shadow, it's a wash inside a panel.
  ///  * [AppGlassLevel.floating] — a real shadow, because it genuinely floats.
  ///  * [AppGlassLevel.base] / [AppGlassLevel.raised] — a tight 1px-ish
  ///    contact shadow, just enough to lift the card off the page.
  List<BoxShadow>? _shadowFor(AppColors ac, bool isDark) {
    switch (level) {
      case AppGlassLevel.nested:
        return null;
      case AppGlassLevel.floating:
        return [
          BoxShadow(
            color: ac.glassShadow,
            blurRadius: isDark ? 28 : 22,
            // Negative spread keeps the shadow tucked under the panel instead
            // of haloing outward past the rounded edge.
            spreadRadius: isDark ? -8 : -12,
            offset: const Offset(0, 10),
          ),
        ];
      case AppGlassLevel.base:
      case AppGlassLevel.raised:
        return [
          BoxShadow(
            color: ac.glassShadow,
            blurRadius: 10,
            // Heavily negative: reads as a hairline of contact rather than a
            // cast shadow, and costs no extra blur pass to rasterise.
            spreadRadius: -6,
            offset: const Offset(0, 2),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radiusBR = BorderRadius.circular(radius);

    // 1. Fill. Blend the tint *over* the base fill rather than replacing it, so
    //    the underlying glass value still contributes.
    final base = _fillFor(ac);
    final t = tint;
    final fillColor = t == null
        ? base
        : Color.alphaBlend(t.withValues(alpha: t.a * tintStrength), base);

    // 2. Blur. Only the floating nav pill reaches a non-zero sigma; everything
    //    else resolves to 0 and skips the `BackdropFilter` branch entirely.
    //    Small surfaces also get a proportionally smaller sigma — a chip is
    //    ~40px tall, so a large sigma is invisible work.
    final sigma = _blurFor(ac);
    final effectiveBlur =
        level == AppGlassLevel.nested ? 0.0 : sigma.clamp(0.0, radius * 0.9);

    // 3. Edge. Explicit override wins, otherwise a themed hairline. Light mode
    //    needs a *dark* hairline to be visible at all; dark mode needs a light
    //    one. Both are already handled by the token.
    final edge = border ?? Border.all(color: ac.glassHairline, width: 1);

    // 4. Specular bevel. Painted in the foreground so it sits *on top of* the
    //    fill and never tints the child's text. Restricted to [AppGlassLevel
    //    .floating]: on a flat card a bright top-edge wash just looks like a
    //    rendering seam, and it was the reason every tinted card converged on
    //    the same pale grey.
    final bevel = gloss && level == AppGlassLevel.floating
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isDark ? ac.glassInnerGlow : ac.glassSpecular,
                const Color(0x00FFFFFF),
              ],
              stops: const [0.0, 0.08],
            ),
          )
        : null;

    Widget panel = Container(
      decoration: BoxDecoration(color: fillColor),
      foregroundDecoration: bevel,
      padding: padding,
      child: child,
    );

    if (effectiveBlur > 0) {
      panel = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: effectiveBlur,
          sigmaY: effectiveBlur,
        ),
        child: panel,
      );
    }

    // Clip *after* the blur so frosted pixels never bleed past the corners.
    panel = ClipRRect(borderRadius: radiusBR, child: panel);

    // 5. Shadow + hairline on a single wrapper sharing the exact same radius.
    panel = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radiusBR,
        border: edge,
        boxShadow: shadow ?? _shadowFor(ac, isDark),
      ),
      child: panel,
    );

    if (semanticLabel != null) {
      panel = Semantics(
        label: semanticLabel,
        button: onTap != null,
        selected: selected,
        child: panel,
      );
    }

    if (onTap == null) return panel;
    return ScaleButton(onTap: onTap, child: panel);
  }
}
