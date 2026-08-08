import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../scale_button.dart' show ScaleButton;

/// A bottom-sheet option row (`.sheet-option`): icon tile + title, optional
/// danger styling.
class SheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  const SheetOption({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.danger = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final color = danger ? ac.expenseFg : ac.inkSoft;
    final tint = danger ? ac.expenseTint : ac.surfaceHigh;
    final titleColor = danger ? ac.expenseFg : ac.ink;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Wraps bottom-sheet content in the mockup sheet chrome: rounded 26px top,
/// drag handle, surface background, bottom safe-area padding.
class AppSheetContent extends StatelessWidget {
  final Widget child;
  final bool showHandle;

  const AppSheetContent({super.key, required this.child, this.showHandle = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, -14)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            const SizedBox(height: 10),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: ac.outlineStrong, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 4),
          ],
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 26),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience helper to open a themed bottom sheet.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x730A0814),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(26),
        topRight: Radius.circular(26),
      ),
    ),
    builder: builder,
  );
}

/// A tap row with scale feedback (press micro-interaction from v1.0.6).
class ScaleRow extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const ScaleRow({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleButton(onTap: onTap, child: child);
  }
}
