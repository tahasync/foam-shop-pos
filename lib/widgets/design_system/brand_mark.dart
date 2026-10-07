import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../utils/brand.dart';
import 'app_button.dart';
import 'elevation.dart';

/// The 2027 floating glass top bar.
///
/// This replaces the two divergent headers the app had (`AppBarRow` and the
/// inline bar inside `FullScreenOverlay`) with one component, because the two
/// implementations had drifted apart and only one of them respected the status
/// bar.
///
/// Three bugs are fixed structurally here, not patched:
///
///  1. **Status-bar collision.** The bar is a `SafeArea`-aware floating pill
///     that is laid out *below* the top inset. The previous overlay bar painted
///     its row into the inset region, so the title and the clock overlapped.
///  2. **Back button washing out the title.** A 15px button was given a
///     `blurRadius: 20` white glow, and that glow bled onto the first letters of
///     the title. The back button is now a full-size [AppIconButton] whose
///     shadow is scoped to its own bounds.
///  3. **Unbounded actions.** Trailing actions are laid out after an `Expanded`
///     title that ellipsises, so a long title can never push the buttons off
///     screen or overlap them.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.leading,
    this.actions = const [],
    this.showBrand = false,
    this.onBack,
  });

  final String title;
  final String? subtitle;

  /// A structured replacement for [subtitle], for headers whose sub-line carries
  /// more than one fact.
  ///
  /// A single `maxLines: 1` string cannot hold a date *and* an address: the
  /// address is the longer of the two, so it is the one that gets cut, and
  /// Flutter's `ellipsis` breaks mid-word. "Opposite Meezan Ba…" reads as a
  /// rendering fault rather than as a deliberate truncation. Passing a widget
  /// lets the caller decide how many facts the sub-line holds and give the
  /// important one room to wrap.
  ///
  /// Ignored when [subtitle] is also set.
  final Widget? subtitleWidget;

  final Widget? leading;
  final List<Widget> actions;

  /// Show the foam brand mark to the left of the title (dashboard only).
  final bool showBrand;

  /// Defaults to popping the route when [leading] is not supplied.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final sub = subtitleWidget ??
        (subtitle == null
            ? null
            : Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ac.inkFaint,
                ),
              ));

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          // The title must never be allowed to push the actions off-screen or
          // collide with the leading button.
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.appTitleStyle.copyWith(
            // Slightly smaller when a sub-line is present. At 20 the shop name
            // out-shouted the two lines beneath it, and a long name could not
            // shrink because the line was already at its ceiling.
            fontSize: sub == null ? 19 : 18.5,
            color: ac.ink,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 3),
          sub,
        ],
      ],
    );

    return Padding(
      // Top inset first, then the bar's own breathing room. This is the line
      // that keeps the header clear of the clock and the notch.
      //
      // The bar is deliberately *not* wrapped in a surface. It used to sit
      // inside a `GlassContainer` (rounded box + fill + hairline + shadow),
      // which boxed the shop name, the bell and the avatar into a slab and
      // added a second floating element competing with the nav pill. The
      // content now sits directly on the page; only the individual controls
      // carry their own surface, so the eye reads one floating nav, not two.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topInset > 0 ? topInset + AppSpacing.xs : AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ] else if (onBack != null) ...[
            _BackButton(onTap: onBack!),
            const SizedBox(width: AppSpacing.md),
          ],
          if (showBrand) ...[
            const BrandMark(),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(child: titleBlock),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            // Actions must never be squeezed to zero width by a long title.
            Row(mainAxisSize: MainAxisSize.min, children: _withGaps(actions)),
          ],
        ],
      ),
    );
  }

  static List<Widget> _withGaps(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const SizedBox(width: AppSpacing.sm));
      out.add(items[i]);
    }
    return out;
  }
}

/// A correctly sized back button.
///
/// Sized to the 48dp minimum target with a 20px glyph — the previous 15px
/// version failed the touch-target rule *and* produced an oversized glow.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: Icons.arrow_back_ios_new_rounded,
      semanticLabel: 'Back',
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}

/// Geometry shared by the in-app painter and the checked-in brand kit.
class MarkGeometry {
  const MarkGeometry._();

  static const double space = 1024;
  static const double slabW = 600;
  static const double slabH = 224;
  static const double slabR = 80;
  static const double gap = 24;

  /// bottom, middle, top
  static const List<Offset> slabOrigins = [
    Offset(178, 528),
    Offset(212, 404),
    Offset(246, 280),
  ];

  /// (dx, dy, r) from the top slab's origin
  static const List<(double, double, double)> pores = [
    (470, 120, 26),
    (520, 82, 15),
    (428, 88, 10),
  ];
  static const double tileRadius = 232;
  static const (double, double, double) accent = (968, 996, 262);
  static const double adaptiveScale = 0.86;

  static const Color ink = Color(0xFF0E0D15);
  static const Color navy = Color(0xFF182346);
  static const Color slate = Color(0xFF3D5387);
  static const Color periwinkle = Color(0xFF7C83AD);
  static const Color mauve = Color(0xFFBFA9BA);
  static const Color foam = Color(0xFFF7F4F2);
}

/// Paints the foam layers synchronously, using the mark.json design space.
class FoamMarkPainter extends CustomPainter {
  const FoamMarkPainter({this.showField = false});

  final bool showField;

  Path _slab(Offset origin, {double inflate = 0}) {
    final rect = Rect.fromLTWH(
      origin.dx - inflate,
      origin.dy - inflate,
      MarkGeometry.slabW + inflate * 2,
      MarkGeometry.slabH + inflate * 2,
    );
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
        rect,
        Radius.circular(MarkGeometry.slabR + inflate),
      ));
  }

  void _drawLayers(Canvas canvas) {
    final bottom = _slab(MarkGeometry.slabOrigins[0]);
    final middle = _slab(MarkGeometry.slabOrigins[1]);
    final top = _slab(MarkGeometry.slabOrigins[2]);
    final middleGap =
        _slab(MarkGeometry.slabOrigins[1], inflate: MarkGeometry.gap);
    final topGap =
        _slab(MarkGeometry.slabOrigins[2], inflate: MarkGeometry.gap);
    final lowerCutouts = Path.combine(PathOperation.union, middleGap, topGap);
    final visibleBottom =
        Path.combine(PathOperation.difference, bottom, lowerCutouts);
    final visibleMiddle =
        Path.combine(PathOperation.difference, middle, topGap);
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = MarkGeometry.periwinkle;
    canvas.drawPath(visibleBottom, paint);
    paint.color = MarkGeometry.mauve;
    canvas.drawPath(visibleMiddle, paint);
    paint.color = MarkGeometry.foam;
    canvas.drawPath(top, paint);

    final topOrigin = MarkGeometry.slabOrigins[2];
    paint.color = MarkGeometry.mauve;
    for (final (dx, dy, radius) in MarkGeometry.pores) {
      canvas.drawCircle(
        Offset(topOrigin.dx + dx, topOrigin.dy + dy),
        radius,
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / MarkGeometry.space;
    canvas.save();
    canvas.scale(scale);

    if (showField) {
      final tile = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, MarkGeometry.space, MarkGeometry.space),
        const Radius.circular(MarkGeometry.tileRadius),
      );
      canvas.save();
      canvas.clipRRect(tile, doAntiAlias: true);
      canvas.drawRRect(tile, Paint()..color = MarkGeometry.navy);
      final (cx, cy, radius) = MarkGeometry.accent;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()..color = MarkGeometry.slate,
      );
      _drawLayers(canvas);
      canvas.restore();
    } else {
      _drawLayers(canvas);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(FoamMarkPainter oldDelegate) =>
      oldDelegate.showField != showField;
}

/// The foam brand mark (`.brand-mark`): flat Foam Layers on a Deep Navy tile.
class BrandMark extends StatelessWidget {
  final double size;
  final double iconSize;
  const BrandMark({super.key, this.size = 38, this.iconSize = 18});

  @override
  Widget build(BuildContext context) {
    // Retained for source compatibility; the complete mark uses its 1024-space.
    final _ = iconSize;
    return Semantics(
      label: AppBrand.name,
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
              size * MarkGeometry.tileRadius / MarkGeometry.space),
          boxShadow: appElevationShadows(context),
        ),
        child: SizedBox.square(
          dimension: size,
          child: const CustomPaint(
            painter: FoamMarkPainter(showField: true),
          ),
        ),
      ),
    );
  }
}

/// App bar used across the main tabs.
///
/// Thin compatibility wrapper over [AppTopBar] so existing call sites keep
/// working while there is exactly one header implementation in the codebase.
class AppBarRow extends StatelessWidget {
  const AppBarRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.leading,
    this.trailing,
    this.showBrand = true,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? leading;
  final List<Widget>? trailing;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    return AppTopBar(
      title: title,
      subtitle: subtitle,
      subtitleWidget: subtitleWidget,
      leading: leading,
      actions: trailing ?? const [],
      showBrand: showBrand,
    );
  }
}
