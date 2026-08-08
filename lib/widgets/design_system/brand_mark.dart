import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'elevation.dart';

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
        color: ac.brandSolid,
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

/// App bar used across the main tabs: brand row + leading/trailing buttons.
class AppBarRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? trailing;
  final bool showBrand;

  const AppBarRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.showBrand = true,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          if (showBrand) ...[
            const BrandMark(),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.appTitleStyle.copyWith(fontSize: 19, color: ac.ink)),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ac.inkFaint)),
              ],
            ),
          ),
          if (trailing != null) ...trailing!,
        ],
      ),
    );
  }
}
