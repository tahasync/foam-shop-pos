import 'package:flutter/material.dart';

/// 2027 structural design tokens for the liquid-glass system.
///
/// IMPORTANT: this file introduces **no new colours**. Every hue still comes
/// from `AppColors` in `app_theme.dart` (the existing slate-blue / periwinkle
/// / dusty-mauve family). These are the *structural* tokens the glass system
/// needs in order to be consistent: a radius scale, a 4/8dp spacing rhythm, a
/// shared motion vocabulary, minimum hit targets and an icon-size scale.
///
/// The motion values mirror the UCP Photography Club house system
/// (`cubic-bezier(0.16, 1, 0.3, 1)` / 180 · 320 · 520ms) so both projects feel
/// like the same design language.
class AppRadii {
  const AppRadii._();

  /// Chips, tags, tiny pills.
  static const double xs = 8;

  /// Small controls, icon chips.
  static const double sm = 12;

  /// Inputs, compact buttons.
  static const double md = 16;

  /// Default card radius.
  static const double lg = 20;

  /// Feature cards, hero-adjacent surfaces.
  static const double xl = 24;

  /// Sheets, the top bar pill, FABs.
  static const double xxl = 28;

  /// Pills and fully rounded chips.
  static const double pill = 999;

  /// Icon-button corner radius derived from its size, so a 40px button and a
  /// 52px button share the same optical language instead of drifting apart.
  static double icon(double size) => size * 0.32;
}

/// 4/8dp spacing rhythm. Page gutters are 18 so they sit on the same rhythm
/// while matching the existing layouts.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 18;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal page gutter.
  static const double gutter = 18;

  /// Space above the first section label so it never crowds the header.
  static const double sectionTop = 22;
}

/// Shared motion vocabulary.
///
/// One duration per *intent* rather than one duration for everything — the
/// pro-rules call this out explicitly as an anti-pattern. Enter/exit are
/// deliberately asymmetric (exit is faster than enter) so screens never feel
/// like they are dragging on the way out.
class AppMotion {
  const AppMotion._();

  /// The house curve: a fast start that settles very slowly. Feels expensive.
  static const Curve ease = Cubic(0.16, 1, 0.3, 1);

  /// A gentle overshoot for small, direct elements (chips, nav indicator).
  static const Curve spring = Cubic(0.34, 1.32, 0.64, 1);

  /// Chips, badges, small state swaps.
  static const Duration fast = Duration(milliseconds: 180);

  /// Default for most transitions.
  static const Duration base = Duration(milliseconds: 320);
}

/// Minimum touch targets. The pro-rules require 44pt on iOS and 48dp on
/// Android; we always satisfy the larger of the two so a single layout is
/// correct on both platforms.
class AppHit {
  const AppHit._();

  /// The value every tappable control must reach.
  static const double min = 48;
}

/// Icon sizes as tokens, so the visual language stays rhythmic instead of
/// drifting through arbitrary 15/17/20/24 values.
class AppIconSize {
  const AppIconSize._();

  /// Inline with 11–12px text.
  static const double xs = 14;

  /// Inside small chips and dense list rows.
  static const double sm = 17;

  /// Default in buttons and list rows.
  static const double md = 20;

  /// Standalone icon buttons.
  static const double lg = 22;

  /// Section-level emphasis.
  static const double xl = 26;

  /// Empty-state illustration.
  static const double xxl = 34;
}

/// Shared vertical scale for numeric readouts (money). Centralised so the
/// hero card, KPI tiles, stat pills and sheet totals all feel like one family.
class AppTypeScale {
  const AppTypeScale._();

  /// Hero card headline amount.
  static const double hero = 34;

  /// KPI tile value.
  static const double kpi = 21;

  /// Compact stat pill value.
  static const double stat = 14.5;

  /// Dense chip value.
  static const double chip = 16;
}

/// Utilities shared by the glass surfaces.
class GlassUtil {
  const GlassUtil._();

  /// A hairline (1px) border that stays exactly 1 physical pixel regardless of
  /// device density, so edges never look chunky on a 3x screen.
  static BorderSide hairline(Color color) => BorderSide(color: color, width: 1);
}
