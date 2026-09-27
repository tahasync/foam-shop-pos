import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../scale_button.dart' show ScaleButton;
import 'glass_container.dart';

enum AppButtonVariant { primary, outline, ghost, danger, success }

/// Design-system button (`.btn` family): full-width by default, 50px tall,
/// 16px radius, Manrope 800. Primary renders the teal brand gradient; the
/// rest are frosted-glass surfaces.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? leading;
  final AppButtonVariant variant;
  final bool fullWidth;
  final double height;
  final double? fontSize;

  /// Horizontal padding inside the button.
  ///
  /// Defaults to 16. Exposed because a compact inline button ("Change" on the
  /// Sales card) needs more breathing room than its 38—48dp height suggests:
  /// the label ends up touching the rounded edge, because the padding was
  /// sized for full-width buttons rather than short ones.
  final double? horizontalPadding;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.leading,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = true,
    this.height = 50,
    this.fontSize,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color fg;
    // The background is described as *decoration* values, not as a child widget.
    //
    // This is the fix for the "glowing slab" bug. The fill used to be a
    // `DecoratedBox`/`GlassContainer` dropped into a `Stack` as
    // `Positioned.fill`, and the clipping came from the parent `Container`'s
    // `clipBehavior: Clip.antiAlias`. But `Container.clipBehavior` clips to a
    // plain RECTANGLE using the decoration's shape — it does NOT respect
    // `borderRadius` for the clip path, because the gradient child was a
    // separate box with no radius of its own. The result was a square-cornered
    // gradient bleeding out past the rounded button on every filled control in
    // the app ("Done", "Add Customer", "Share PDF"). Painting the fill *on* the
    // same decoration as the radius makes the clip exact by construction.
    Color? bgColor;
    Gradient? bgGradient;
    Border? bgBorder;

    switch (variant) {
      case AppButtonVariant.primary:
        fg = const Color(0xFFFFFFFF);
        // `brandFill`/`brandFillDeep`, not `brandSolid`/`brandSolidStrong`.
        // The latter are *lightened* in dark mode to work as text on a dark
        // surface, so using them as a fill behind white glyphs gave a pale
        // periwinkle->mauve ramp at roughly 2:1 contrast.
        bgGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ac.brandFill, ac.brandFillDeep],
        );
        break;
      case AppButtonVariant.outline:
        fg = ac.ink;
        // An alpha-based wash (`glassNested`), NOT a hardcoded surface colour.
        //
        // This fill used to be `ac.surface` (the *page* colour) so the button
        // would read as inset on a card. But buttons also live on bottom
        // sheets, which are lighter than the page — so the same value became a
        // dark hole punched in the sheet ("+ Add Customer" in the Select
        // Customer sheet). A fill baked from one specific surface can never be
        // right on all three; a low-alpha wash derived from the palette is
        // correct on any background in either theme.
        bgColor = ac.glassNested;
        // `controlBorder`, not `outline`.
        //
        // `outline` is a hairline for large panels. In dark mode it is
        // `#32323E` on a `#1E1E26` card - about 1.2:1, effectively
        // invisible, which left the label looking like loose text floating
        // on the card. An outlined *control* needs a visible edge.
        bgBorder = Border.all(color: ac.controlBorder, width: 1.2);
        break;
      case AppButtonVariant.ghost:
        fg = ac.ink;
        // No fill and no border: a ghost control is the label and nothing else.
        // It previously washed itself in 12% white, which on a dark sheet
        // rendered as an unexplained grey slab sitting next to two proper
        // buttons.
        break;
      case AppButtonVariant.danger:
        fg = const Color(0xFFFFFFFF);
        bgGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ac.dangerFill, ac.dangerFillDeep],
        );
        break;
      case AppButtonVariant.success:
        fg = const Color(0xFFFFFFFF);
        bgGradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF25D366), Color(0xFF1CA355)],
        );
        break;
    }

    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w800,
        fontSize: fontSize ?? 14,
        letterSpacing: -0.01,
        color: fg,
      ),
    );

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        // `Flexible` ONLY when the width is bounded.
        //
        // Bug: this was always `Flexible`, but an inline button
        // (`fullWidth: false`) sits in a `Row`, where the incoming width is
        // unbounded. A flex child under an unbounded main axis resolves to
        // zero, so the button sized itself to just its padding and the label
        // spilled outside the rounded rect — the "Change" button on the Sales
        // screen was rendering as text floating on top of a tiny box.
        if (fullWidth) Flexible(child: labelText) else labelText,
      ],
    );

    final radius = BorderRadius.circular(AppRadii.md);

    Widget button = Container(
      width: fullWidth ? double.infinity : null,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding ?? 16),
      // ONE decoration owns the radius, the fill, the border and the shadow.
      //
      // This is the fix for the square-cornered "glowing slab" that every
      // filled button showed. The fill used to be a separate child box
      // (`DecoratedBox` / `GlassContainer`) dropped into a `Stack` as
      // `Positioned.fill`, and the rounding came from the parent Container's
      // `clipBehavior: Clip.antiAlias`. That clip is applied using the
      // decoration's *shape* (a plain rectangle); it does not round a child
      // carrying no radius of its own. So the gradient child painted square
      // corners that spilled past the 16px radius on "Done", "Add Customer"
      // and "Share PDF". Painting the fill on the same decoration as the radius
      // makes fill and clip the same box, so they cannot disagree.
      decoration: BoxDecoration(
        borderRadius: radius,
        color: bgColor,
        gradient: bgGradient,
        border: bgBorder,
        // A tight, *neutral* contact shadow, not a brand-coloured glow.
        //
        // This was `ac.brandFill` at 28% under a 12px blur, which painted a
        // blue halo bleeding well past the button, most visibly on the "Done"
        // button where it washed into the "Walk-in" button beside it. A
        // coloured glow is also the wrong idea for a flat UI: it reads as a
        // glow, not as the button sitting on the surface. A short black shadow
        // grounded under the shape does the job. It is a little stronger in
        // dark mode because a near-black page swallows a light shadow, and the
        // primary action must stay the brightest object on the sheet.
        boxShadow: variant == AppButtonVariant.primary
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.22),
                  blurRadius: 10,
                  spreadRadius: -3,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      // No white gloss overlay.
      //
      // This painted a 12%-white wash over the top third of every filled
      // button, so the brand gradient was veiled and the top edge looked hazy
      // and slightly dirty. A flat surface already has enough structure from
      // its own gradient; the sheen added cost and no information.
      //
      // `Align` rather than a `Stack`: the content is centred, and now that the
      // fill lives on the decoration above there is no second box to stack.
      // Removing it also retires the whole `StackFit`/unbounded-width bug
      // class (`StackFit.expand` under an unbounded `Row` throws
      // "BoxConstraints forces an infinite width", and a non-positioned
      // `SizedBox.expand()` sibling collapsed the Sales customer card).
      child: Align(
        alignment: Alignment.center,
        // `widthFactor: 1` is load-bearing, not cosmetic.
        //
        // A bare `Align` only shrink-wraps when `maxWidth` is *infinite*; given
        // a bounded width it fills it. An inline (`fullWidth: false`) button
        // wrapped in a `Center`/`Column` would therefore stretch to the full
        // available width and its `horizontalPadding` would stop affecting its
        // size at all. Forcing the factor makes it always hug its content, so
        // padding is honoured everywhere, while the height still fills so the
        // label stays vertically centred.
        widthFactor: 1,
        child: content,
      ),
    );
    if (onTap == null) return button;
    return ScaleButton(onTap: onTap, scale: 0.97, child: button);
  }
}

/// Icon button (`.icon-btn`) \u2192 frosted-glass circle.
///
/// Sized to the 48dp minimum touch target by default. The visual glyph and the
/// icon chip scale with [size], but the *hit area* is always at least
/// [AppHit.min] \u2192 the pro-rules require a 44pt iOS / 48dp Android target even
/// when the icon itself is small.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.background,
    this.foreground,
    this.size = AppIconSize.xxl + 10,
    this.badge,
    this.semanticLabel,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? background;
  final Color? foreground;
  final double size;
  final Widget? badge;

  /// Required for icon-only controls \u2192 without it a screen reader announces an
  /// unlabelled button.
  final String? semanticLabel;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final bg = background;
    final fg = foreground ?? ac.inkSoft;
    final chipSize = size.clamp(AppIconSize.lg, 64.0);

    Widget button = GlassContainer(
      radius: AppRadii.icon(chipSize),
      level: AppGlassLevel.base,
      tint: bg,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: chipSize,
        height: chipSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, size: chipSize * 0.44, color: fg)),
            if (badge != null) Positioned(top: -2, right: -2, child: badge!),
          ],
        ),
      ),
    );

    if (onTap != null) {
      button = ScaleButton(onTap: onTap, child: button);
      // Guarantee the hit target even when the visual chip is smaller.
      final hit = chipSize < AppHit.min ? AppHit.min : chipSize;
      button = SizedBox(
        width: hit,
        height: hit,
        child: Center(child: button),
      );
    }

    if (semanticLabel != null) {
      button = Semantics(
        label: semanticLabel,
        button: true,
        child: button,
      );
    }

    if (tooltip != null && onTap != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Floating action button - a solid brand capsule.
///
/// Fixes applied:
///  * 60x60 (was 58) so it clears the 48dp target with room to spare and reads
///    as a deliberate primary action,
///  * the glyph is `brandSolidStrong` on the brand gradient rather than pure
///    white, which keeps the contrast ratio up on the lighter half of the
///    gradient, and
///  * a semantic label is required, since a FAB is icon-only.
class AppFab extends StatelessWidget {
  const AppFab({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// Screen-reader name, e.g. "Add product".
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Semantics(
      label: semanticLabel,
      button: true,
      child: ScaleButton(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              // `brandFill`/`brandFillDeep` — NOT `brandSolid`/`brandSolidStrong`.
              // In dark mode those are *lightened* foreground colours and
              // `brandSolidStrong` is the mauve `#BFA9BA`, so the FAB rendered
              // as a blue-to-**pink** capsule with a white glyph on the pale
              // half at roughly 1.6:1 contrast.
              colors: [ac.brandFill, ac.brandFillDeep],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            // A tight contact shadow rather than a wide soft glow.
            //
            // This was `blurRadius: 24, offset (0,12), alpha 0.42` of the brand
            // colour. Spread that far from a 60dp shape it stops reading as the
            // button lifting off the page and becomes a hazy brand-coloured
            // smear around it — the "blurry FAB" look. Short, low-alpha and
            // anchored close to the shape separates it without fogging.
            boxShadow: [
              // Neutral, matching the buttons. A brand-tinted shadow under a
              // brand-coloured shape adds no information - on the near-black
              // dark page it just reads as a blue light leak around the FAB.
              // A genuinely floating element earns a real shadow, so this one
              // is kept, but it is black and tight.
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.38
                      : 0.24,
                ),
                blurRadius: 16,
                spreadRadius: -6,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: AppIconSize.lg + 2, color: Colors.white),
        ),
      ),
    );
  }
}
