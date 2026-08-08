import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Menu row (`.menu-row`) used in settings lists: icon tile + title + optional
/// subtitle + trailing widget.
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final iconBg = danger ? ac.expenseTint : ac.surfaceHigh;
    final iconFg = danger ? ac.expenseFg : ac.inkSoft;
    final titleColor = danger ? ac.expenseFg : ac.ink;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 16, color: iconFg),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: titleColor)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
                    ),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(Icons.chevron_right_rounded, size: 16, color: ac.inkFaint)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

/// Themed switch matching the mockup `.switch`.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const AppSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: ac.primary,
      activeThumbColor: Colors.white,
    );
  }
}
