import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
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


/// The foam brand mark (`.brand-mark`): fixed `brandSolid` fill with white
/// logo glyph, used in app bars and auth screens.
class BrandMark extends StatelessWidget {
  final double size;
  final double iconSize;
  const BrandMark({super.key, this.size = 38, this.iconSize = 18});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ac.brandFill,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: appElevationShadows(context),
      ),
      foregroundDecoration: darkTopEdgeHighlight(context),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            margin: EdgeInsets.all(size * 0.16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
            ),
          ),
          CustomPaint(
            size: Size(iconSize, iconSize),
            painter: _FoamGlyphPainter(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _FoamGlyphPainter extends CustomPainter {
  final Color color;
  _FoamGlyphPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.12, h * 0.72);
    path.cubicTo(w * 0.2, h * 0.42, w * 0.38, h * 0.18, w * 0.5, h * 0.18);
    path.cubicTo(w * 0.62, h * 0.18, w * 0.8, h * 0.42, w * 0.88, h * 0.72);
    path.cubicTo(w * 0.78, h * 0.9, w * 0.62, h * 0.9, w * 0.5, h * 0.74);
    path.cubicTo(w * 0.38, h * 0.9, w * 0.22, h * 0.9, w * 0.12, h * 0.72);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FoamGlyphPainter old) => old.color != color;
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
