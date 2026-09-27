import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'foam_card.dart';

/// A KPI tile — tinted icon chip, uppercase label, tabular-figure value and a
/// faint sub-label.
///
/// Bug fixed here: tiles were laid out in a `Row` with
/// `CrossAxisAlignment.start`, so two tiles whose labels wrapped to different
/// line counts ended up visibly different heights and the row looked broken.
/// [AppKpiRow] now stretches the row with an [IntrinsicHeight] so every tile in
/// a row shares exactly the same box.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.tint,
    required this.iconColor,
    this.valueColor,
    this.foam = true,
    this.onTap,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final Color? valueColor;
  final bool foam;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: iconColor.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: AppIconSize.sm - 1, color: iconColor),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ac.inkSoft,
            height: 1.25,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // `FittedBox` guarantees a long figure (e.g. "Rs 1,234,567") shrinks to
        // fit rather than overflowing the card — the number is the point of the
        // tile, so it must never be clipped.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: AppTheme.display(
              context,
              size: AppTypeScale.kpi,
              color: valueColor,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: ac.inkFaint),
        ),
      ],
    );

    return FoamCard(
      foam: foam,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      // Announced as one unit: "Revenue, Rs 176,000, 3 sales".
      semanticLabel: '$label, $value, $sub',
      child: content,
    );
  }
}

/// A row of two KPI tiles that always share one height.
///
/// The previous pattern (`Row(crossAxisAlignment: start, [Expanded, SizedBox,
/// Expanded])`) let tiles size independently. `IntrinsicHeight` forces the row to
/// the tallest child's height and `crossAxisAlignment: stretch` makes each tile
/// fill it, so the pair always reads as one deliberate block.
class AppKpiRow extends StatelessWidget {
  const AppKpiRow({super.key, required this.tiles, this.gap = AppSpacing.md});

  final List<Widget> tiles;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}
