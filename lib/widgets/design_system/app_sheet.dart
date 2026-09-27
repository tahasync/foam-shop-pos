import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

/// A bottom-sheet option row: icon chip + title, with optional danger styling.
class SheetOption extends StatelessWidget {
  const SheetOption({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.danger = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final color = danger ? ac.expenseFg : ac.inkSoft;
    final tint = danger ? ac.expenseTint : ac.glassNested;
    final titleColor = danger ? ac.expenseFg : ac.ink;

    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        splashColor: ac.glassPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppHit.min),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: color.withValues(alpha: 0.16)),
                ),
                child: Icon(icon, size: AppIconSize.sm, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
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
      ),
    );
  }
}

/// Frosted sheet chrome: rounded top, drag handle, a dense blurred fill so the
/// content behind never competes with the sheet content, and bottom safe-area
/// padding.
class AppSheetContent extends StatelessWidget {
  const AppSheetContent({
    super.key,
    required this.child,
    this.showHandle = true,
  });

  final Widget child;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadii.xxl),
          topRight: Radius.circular(AppRadii.xxl),
        ),
        boxShadow: [
          BoxShadow(
            color: ac.glassShadow,
            blurRadius: 48,
            spreadRadius: -12,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // No `BackdropFilter` here. The sheet's fill is fully opaque now, so the
      // blur was both invisible *and* the most expensive filter in the app — it
      // ran across the entire screen area on every sheet open. Separation from
      // the page below comes from the scrim and the shadow instead.
      child: Container(
          // `glassElevated` rather than a hand-picked near-opaque white: the
          // sheet now isolates its content in both themes from one token.
          decoration: BoxDecoration(
            color: ac.glassElevated,
            border: Border(
              top: BorderSide(color: ac.glassHairline),
              left: BorderSide(color: ac.glassHairline),
              right: BorderSide(color: ac.glassHairline),
            ),
          ),
          foregroundDecoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isDark ? ac.glassInnerGlow : ac.glassSpecular,
                const Color(0x00FFFFFF),
              ],
              stops: const [0.0, 0.05],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ac.inkFaint.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    // Clear the keyboard as well as the home indicator.
                    MediaQuery.viewInsetsOf(context).bottom +
                        MediaQuery.paddingOf(context).bottom +
                        AppSpacing.xxl,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
    );
  }
}

/// Opens a themed bottom sheet.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final ac = AppColors.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    // Themed scrim. The old hardcoded value dimmed the light background to a
    // muddy grey and shifted the perceived hue of the palette.
    barrierColor: ac.glassScrim,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppRadii.xxl),
        topRight: Radius.circular(AppRadii.xxl),
      ),
    ),
    builder: builder,
  );
}