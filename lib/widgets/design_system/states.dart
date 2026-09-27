import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'glass_container.dart';

/// Empty state.
///
/// Previously this was a bare icon and two lines of text floating directly on
/// the page background, which made every empty screen look unfinished (the
/// "No outstanding baqaya!" and "No items added yet." panels in particular). It
/// is now a proper glass card with the icon in a tinted chip, so an empty state
/// reads as a deliberate, designed moment rather than a gap in the data.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.celebrate = false,
    this.tint,
    this.tintStrength = 1.0,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Success framing (a "nothing outstanding" state) vs neutral.
  final bool celebrate;

  final Color? tint;
  final double tintStrength;

  /// Drops the card chrome for use *inside* an existing card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final fg = celebrate ? ac.saleFg : ac.inkSoft;
    final chipTint = tint ?? (celebrate ? ac.saleTint : ac.glassNested);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: chipTint,
            shape: BoxShape.circle,
            border: Border.all(color: fg.withValues(alpha: 0.16)),
          ),
          child: Icon(
            icon,
            size: AppIconSize.xxl - 6,
            color: celebrate ? fg : ac.inkFaint,
          ),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.01,
            color: ac.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          // Keeps the supporting line to a comfortable measure instead of
          // running edge-to-edge on a wide screen.
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: ac.inkFaint,
            ),
          ),
        ),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: content,
      );
    }

    return GlassContainer(
      level: AppGlassLevel.base,
      radius: AppRadii.xl,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      tint: tint,
      tintStrength: tintStrength,
      child: Center(child: content),
    );
  }
}

/// No-results state for filtered lists.
class NoResults extends StatelessWidget {
  const NoResults({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.search_off_rounded,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ac.glassNested,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppIconSize.lg, color: ac.inkFaint),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ac.inkSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: ac.inkFaint),
          ),
        ],
      ),
    );
  }
}
