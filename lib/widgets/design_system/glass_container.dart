import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../scale_button.dart' show ScaleButton;

/// The core liquid-glass surface (`.g` in the mockup): ClipRRect +
/// BackdropFilter frosted layer with a translucent fill, optional semantic
/// tint overlay, 1px glass edge and soft top-side gloss line.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? tint;
  final double tintStrength;
  final Color? fill;
  final double? blur;
  final bool strong;
  final bool gloss;
  final Border? border;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.radius = 18,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.tint,
    this.tintStrength = 1.0,
    this.fill,
    this.blur,
    this.strong = false,
    this.gloss = true,
    this.border,
    this.shadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radiusBR = BorderRadius.circular(radius);

    // 1. Base glass fill, with an optional semantic tint blended over it.
    final base = fill ?? (strong ? ac.glassFillStrong : ac.glassFill);
    final t = tint;
    final tintFill = t == null
        ? base
        : Color.alphaBlend(t.withValues(alpha: t.a * tintStrength), base);

    final edge = border ??
        Border.all(
          color: strong ? ac.glassGloss.withValues(alpha: 0.6) : ac.glassBorder,
        );

    Widget surface = ClipRRect(
      borderRadius: radiusBR,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: blur ?? ac.glassBlur,
          sigmaY: blur ?? ac.glassBlur,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: tintFill,
            gradient: isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.4),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                    stops: const [0.0, 0.7],
                  ),
          ),
          foregroundDecoration: gloss
              ? const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
                    stops: [0, 0.06],
                  ),
                )
              : null,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    surface = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radiusBR,
        border: edge,
        boxShadow: shadow ??
            (isDark
                ? const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10)),
                  ]
                : const [
                    BoxShadow(color: Color(0x1F182346), blurRadius: 20, offset: Offset(0, 8)),
                  ]),
      ),
      child: surface,
    );

    if (onTap == null) return surface;
    return ScaleButton(onTap: onTap, child: surface);
  }
}