import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum BadgeType { quote, void_, paid }

/// Status pill (`.badge-pill`) for quote / void / paid states.
class StatusBadge extends StatelessWidget {
  final BadgeType type;
  final String label;

  const StatusBadge({super.key, required this.type, required this.label});

  factory StatusBadge.quote(String label) => StatusBadge(type: BadgeType.quote, label: label);
  factory StatusBadge.voided(String label) => StatusBadge(type: BadgeType.void_, label: label);
  factory StatusBadge.paid(String label) => StatusBadge(type: BadgeType.paid, label: label);

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final Color bg, fg;
    switch (type) {
      case BadgeType.quote:
        bg = ac.purchaseTint;
        fg = ac.purchaseFg;
        break;
      case BadgeType.void_:
        bg = ac.expenseTint;
        fg = ac.expenseFg;
        break;
      case BadgeType.paid:
        bg = ac.saleTint;
        fg = ac.saleFg;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.03,
          color: fg,
          decoration: type == BadgeType.void_ ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

/// Alert banner (`.alert` / `.alert.danger`).
class AlertBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  const AlertBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final tint = danger ? ac.expenseTint : ac.purchaseTint;
    final fg = danger ? ac.expenseFg : ac.purchaseFg;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fg.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: ac.surface, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 16, color: fg),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.ink)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(subtitle!,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ac.inkSoft)),
                  ),
              ]),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: ac.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Mini summary row used inside receipts and cards (`.mini-row`).
class MiniRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const MiniRow({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: ac.inkSoft)),
          Text(value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: valueColor ?? ac.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}
