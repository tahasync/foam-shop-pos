import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'glass_container.dart';

/// Horizontal accounting strip of compact glass value chips.
///
/// Bug fixed here: the strip was a bare `SingleChildScrollView`, so the last
/// chip was sliced off exactly at the page gutter. That read as a rendering
/// glitch ("CUSTOMER BAQ…" cut in half) rather than as an invitation to scroll.
/// Two changes fix it honestly:
///  * a short fade at the trailing edge signals "there is more", and
///  * the chips get a fixed width so the row stays rhythmic as values change
///    length instead of jittering.
class AccountingStrip extends StatelessWidget {
  const AccountingStrip({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.sm),
  });

  final List<AccountingChipData> items;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final surface = Theme.of(context).colorScheme.surface;

    return ClipRect(
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: padding,
            physics: const BouncingScrollPhysics(),
            // No `CrossAxisAlignment.stretch` here. A horizontal
            // SingleChildScrollView hands its child an *unbounded* cross-axis
            // (height) constraint, so `stretch` resolved to `h=Infinity` and threw
            // "BoxConstraints forces an infinite height". That killed layout for
            // the whole ListView this strip lives in, leaving the dashboard body
            // blank. The chips are already fixed-width and self-sizing, so they
            // need no cross-axis stretch to line up.
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  _AccountingChip(data: items[i]),
                ],
              ],
            ),
          ),
          // Trailing fade — a deliberate "keep scrolling" affordance instead of
          // a card that looks accidentally broken in half.
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: AppSpacing.xxl,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      surface.withValues(alpha: 0),
                      surface.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountingChipData {
  const AccountingChipData({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
}

class _AccountingChip extends StatelessWidget {
  const _AccountingChip({required this.data});

  final AccountingChipData data;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GlassContainer(
      radius: AppRadii.lg,
      level: AppGlassLevel.base,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: SizedBox(
        // Fixed width keeps the strip rhythmic.
        width: 152,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: ac.inkFaint,
                letterSpacing: 0.03,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // A seven-figure amount must shrink, never overflow.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.value,
                maxLines: 1,
                style: AppTheme.display(
                  context,
                  size: AppTypeScale.chip,
                  color: data.valueColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
