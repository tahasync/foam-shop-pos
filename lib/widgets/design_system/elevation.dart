import 'package:flutter/material.dart';

/// Shared elevation for design-system surfaces, matching the mockup's
/// `--shadow-1` token (light and dark). Dark mode layers an extra faint inset
/// top-edge highlight (a standard dark-UI depth cue) on top of the elevation
/// shadow — additive, not a replacement. No color tokens are changed.
List<BoxShadow> appElevationShadows(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return const [
      BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(
          color: Color(0x8C000000),
          blurRadius: 20,
          spreadRadius: -10,
          offset: Offset(0, 8)),
    ];
  }
  return const [
    BoxShadow(color: Color(0x0F0E0D15), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
        color: Color(0x290E0D15),
        blurRadius: 20,
        spreadRadius: -10,
        offset: Offset(0, 8)),
  ];
}

/// Dark-mode-only faint inset top-edge highlight (`inset 0 1px 0
/// rgba(255,255,255,.07)`). Returns null in light mode so no dark rule can
/// leak into light theme. Applied as a `foregroundDecoration`.
BoxDecoration? darkTopEdgeHighlight(BuildContext context) {
  if (Theme.of(context).brightness != Brightness.dark) return null;
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x12FFFFFF), Color(0x00FFFFFF)],
      stops: [0, 0.06],
    ),
  );
}
