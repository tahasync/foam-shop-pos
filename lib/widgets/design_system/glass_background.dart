import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// The app background.
///
/// This used to be an animated "liquid glass" backdrop: three large radial
/// gradient orbs, each on its own infinite `AnimationController`, drifting
/// behind the content for as long as the screen was open. That cost three
/// permanently-ticking animators plus a full-screen repaint every frame, for
/// a decorative effect that made a data-dense POS harder to read.
///
/// It is now a flat, static surface. The visual hierarchy comes from the
/// surface tokens instead, and the frame budget goes back to the content.
class GlassBackground extends StatelessWidget {
  final Widget child;

  /// Retained for call-site compatibility. The background is always opaque now,
  /// so this no longer changes anything.
  final bool transparent;

  const GlassBackground({
    super.key,
    required this.child,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    // Read from the theme rather than hardcoding, so the page colour can never
    // drift from `AppColors.surface` again. It previously pinned its own
    // #0E0D15 while the dark theme moved to a different neutral ramp, which is
    // how you end up with a page that is a different colour from the theme's
    // own `scaffoldBackgroundColor`.
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Painted directly, with no Stack: the old `Stack(fit: StackFit.expand)`
    // forced a full-screen layer purely to hold decorative orbs.
    return ColoredBox(
      color: isDark ? ac.surface : const Color(0xFFF7F4F2),
      child: child,
    );
  }
}

/// Convenience scaffold: `GlassBackground` behind an optional [SafeArea].
class GlassScaffold extends StatelessWidget {
  final Widget child;
  final bool safeTop;
  final bool safeBottom;

  const GlassScaffold({
    super.key,
    required this.child,
    this.safeTop = true,
    this.safeBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: SafeArea(
          top: safeTop,
          bottom: safeBottom,
          child: child,
        ),
      ),
    );
  }
}
