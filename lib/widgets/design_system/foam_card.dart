import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'elevation.dart';

/// The signature "foam layer" stacked card: a `surfaceHighest` underlay
/// peeking out behind the card's bottom edge. When [foam] is false it renders
/// as a plain [Container] matching `.card` in the mockup (radius 22).
///
/// The decorative underlay (mockup `.foam::before`) is a proportions fix: only
/// its bottom two corners are rounded (14px) and it carries a hairline
/// left/right/bottom border, so it reads as a crisp second card edge rather
/// than a rounded pill. The card's own face carries the `--shadow-1` elevation
/// and a dark-mode inset top-edge highlight.
class FoamCard extends StatelessWidget {
  final Widget child;
  final bool foam;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const FoamCard({
    super.key,
    required this.child,
    this.foam = false,
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final cs = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(this.radius);
    final fill = color ?? cs.surfaceContainerLowest;
    final isDark = cs.brightness == Brightness.dark;

    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: ac.outline),
        boxShadow: appElevationShadows(context),
      ),
      foregroundDecoration: darkTopEdgeHighlight(context),
      child: child,
    );

    if (onTap != null) {
      card = Material(color: Colors.transparent, child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: card,
      ));
    }

    if (!foam) return card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 8,
          right: 8,
          top: 8,
          bottom: -5,
          child: Opacity(
            opacity: isDark ? 0.75 : 0.9,
            child: Container(
              decoration: BoxDecoration(
                color: ac.surfaceHighest,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(
                  left: BorderSide(color: ac.outlineStrong),
                  right: BorderSide(color: ac.outlineStrong),
                  bottom: BorderSide(color: ac.outlineStrong),
                ),
              ),
              foregroundDecoration: isDark
                  ? const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x0DFFFFFF), Color(0x00FFFFFF)],
                        stops: [0, 0.08],
                      ),
                    )
                  : null,
            ),
          ),
        ),
        card,
      ],
    );
  }
}
