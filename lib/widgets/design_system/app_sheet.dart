import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
    final tint = danger ? ac.expenseTint : ac.glassGloss.withValues(alpha: 0.35);
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
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ac.glassBorder),
              ),
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

/// Wraps bottom-sheet content in frosted-glass sheet chrome: rounded 26px
/// top, drag handle, blurred translucent fill, bottom safe-area padding.
class AppSheetContent extends StatelessWidget {
  final Widget child;
  final bool showHandle;

  const AppSheetContent({super.key, required this.child, this.showHandle = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFFFFFFF)),
          left: BorderSide(color: isDark ? const Color(0x1FFFFFFF) : const Color(0x99FFFFFF)),
          right: BorderSide(color: isDark ? const Color(0x1FFFFFFF) : const Color(0x99FFFFFF)),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 44, offset: const Offset(0, -14)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [
                      Color(0xF20E0D15),
                      Color(0xF2141A2A),
                    ]
                  : const [
                      Color(0xFAFFFFFF),
                      Color(0xF7F7F4F2),
                    ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle) ...[
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x4DFFFFFF) : const Color(0xFFC2C0C8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
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
        ),
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
    barrierColor: const Color(0x730E0D15),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
    ),
    builder: builder,
  );
}