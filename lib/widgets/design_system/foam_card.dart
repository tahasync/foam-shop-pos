import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import 'glass_container.dart';

/// The signature frosted card.
///
/// [foam] is kept as the public knob because it reads well at call sites
/// ("this is a foam card"), but it now maps onto an explicit
/// [AppGlassLevel] instead of a bag of unrelated side effects.
class FoamCard extends StatelessWidget {
  const FoamCard({
    super.key,
    required this.child,
    this.foam = false,
    this.radius = AppRadii.lg,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.color,
    this.onTap,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;

  /// `true` → a denser, raised panel (used for the prominent cards);
  /// `false` → a standard base-level card.
  final bool foam;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: borderRadius?.topLeft.x ?? radius,
      padding: padding,
      margin: margin,
      fill: color,
      level: foam ? AppGlassLevel.raised : AppGlassLevel.base,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}
