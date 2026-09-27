import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

enum BadgeType { quote, void_, paid }

/// Status pill for quote / void / paid states.
///
/// Fixes applied:
///  * the tint is no longer used as a *text* colour. The old code used
///    `ac.purchaseTint` / `ac.expenseTint` (which are ~80% opaque fills) as the
///    foreground, so "DUE" and "VOID" rendered as pale, washed-out text that
///    failed contrast. Foregrounds are now the matching `-Fg` tokens.
///  * the void state keeps its strikethrough *and* gains a distinct border, so
///    the state is not signalled by decoration alone.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.type, required this.label});

  factory StatusBadge.quote(String label) =>
      StatusBadge(type: BadgeType.quote, label: label);

  factory StatusBadge.voided(String label) =>
      StatusBadge(type: BadgeType.void_, label: label);

  factory StatusBadge.paid(String label) =>
      StatusBadge(type: BadgeType.paid, label: label);

  final BadgeType type;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    final Color bg;
    final Color fg;
    switch (type) {
      case BadgeType.quote:
        bg = ac.purchaseTint;
        fg = ac.purchaseFg;
      case BadgeType.void_:
        bg = ac.expenseTint;
        fg = ac.expenseFg;
      case BadgeType.paid:
        bg = ac.saleTint;
        fg = ac.saleFg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.04,
          color: fg,
          decoration:
              type == BadgeType.void_ ? TextDecoration.lineThrough : null,
          decorationColor: fg,
        ),
      ),
    );
  }
}

/// Alert banner for outstanding balances, low stock, and similar notices.
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final tint = danger ? ac.expenseTint : ac.purchaseTint;
    final fg = danger ? ac.expenseFg : ac.purchaseFg;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Semantics(
        container: true,
        label: subtitle == null ? title : '$title. $subtitle',
        button: onTap != null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            splashColor: ac.glassPress,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: fg.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ac.glassElevated,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Icon(icon, size: AppIconSize.sm, color: fg),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: ac.ink,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ac.inkSoft,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded,
                        size: AppIconSize.md, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact label/value row used inside receipts and summary cards.
class MiniRow extends StatelessWidget {
  const MiniRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Renders the row as a total: heavier type and extra top spacing.
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: emphasise ? AppSpacing.md : AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: emphasise ? 13 : 11.5,
                fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
                color: emphasise ? ac.ink : ac.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasise ? 14 : 11.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? (emphasise ? ac.ink : ac.ink),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
