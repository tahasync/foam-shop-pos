import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'glass_container.dart';

class HeroPill {
  const HeroPill({required this.label, required this.value});

  final String label;
  final String value;
}

/// The hero balance card - the single most important surface on the dashboard.
///
/// Now a solid tinted panel rather than glass:
///  * a `GlassContainer` at the `base` level, so the headline number sits on an
///    opaque surface instead of a frosted one,
///  * nested pills for the stat row instead of a hand-rolled gradient, and
///  * a `FittedBox` on the headline amount so a seven-figure balance shrinks
///    rather than overflowing.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.eyebrow,
    required this.amount,
    this.chip,
    this.pills = const [],
    this.amountSize = AppTypeScale.hero,
  });

  final String eyebrow;
  final String amount;
  final String? chip;
  final List<HeroPill> pills;
  final double amountSize;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountColor = isDark ? Colors.white : ac.brandSolidStrong;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: GlassContainer(
        radius: AppRadii.xxl,
        level: AppGlassLevel.base,
        // A lightly tinted panel, so the headline reads as the hero while still
        // being unmistakably glass rather than a painted card.
        tint: ac.primary.withValues(alpha: isDark ? 0.16 : 0.08),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xxl,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        shadow: [
          BoxShadow(
            color: ac.brandFill.withValues(alpha: isDark ? 0.34 : 0.16),
            blurRadius: 34,
            spreadRadius: -10,
            offset: const Offset(0, 16),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.09,
                          color: ac.inkSoft,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Never let a large balance overflow the card.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          amount,
                          maxLines: 1,
                          style: AppTheme.display(
                            context,
                            size: amountSize,
                            color: amountColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (chip != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  _TrendChip(label: chip!),
                ],
              ],
            ),
            if (pills.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  for (var i = 0; i < pills.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: _StatPill(
                            label: pills[i].label, value: pills[i].value)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The small trend badge beside the headline.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: ac.glassNested,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: ac.saleFg.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_upward_rounded,
              size: AppIconSize.xs - 1, color: ac.saleFg),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: ac.saleFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A nested glass stat pill inside the hero.
class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GlassContainer(
      level: AppGlassLevel.nested,
      radius: AppRadii.lg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.06,
              color: ac.inkFaint,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTheme.display(context,
                  size: AppTypeScale.stat, color: ac.ink),
            ),
          ),
        ],
      ),
    );
  }
}
