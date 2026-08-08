import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Section label with an optional trailing action (`.section-label`).
class SectionLabel extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionLabel({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10, left: 2, right: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.05,
                color: ac.inkFaint,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ac.primary),
              ),
            ),
        ],
      ),
    );
  }
}
