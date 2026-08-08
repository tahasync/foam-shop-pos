import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../scale_button.dart' show ScaleButton;
import 'elevation.dart';

enum AppButtonVariant { primary, outline, ghost, danger, success }

/// Design-system button (`.btn` family): full-width by default, 50px tall,
/// 16px radius, Manrope 800.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? leading;
  final AppButtonVariant variant;
  final bool fullWidth;
  final double height;
  final double? fontSize;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.leading,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = true,
    this.height = 50,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final cs = Theme.of(context).colorScheme;

    Color bg, fg;
    Border? border;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = ac.primary;
        fg = cs.onPrimary;
        break;
      case AppButtonVariant.outline:
        bg = ac.surface;
        fg = ac.primary;
        border = Border.all(color: ac.outlineStrong, width: 1.5);
        break;
      case AppButtonVariant.ghost:
        bg = ac.surfaceHigh;
        fg = ac.ink;
        break;
      case AppButtonVariant.danger:
        bg = ac.dangerSolid;
        fg = const Color(0xFFFFFFFF);
        break;
      case AppButtonVariant.success:
        bg = const Color(0xFF25D366);
        fg = const Color(0xFFFFFFFF);
        break;
    }

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w800,
              fontSize: fontSize ?? 14,
              letterSpacing: -0.01,
              color: fg,
            ),
          ),
        ),
      ],
    );

    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: fullWidth ? double.infinity : null,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: variant == AppButtonVariant.primary
            ? [BoxShadow(color: ac.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))]
            : null,
      ),
      child: Center(child: content),
    );

    if (onTap == null) return button;
    return ScaleButton(onTap: onTap, scale: 0.97, child: button);
  }
}

/// Icon button (`.icon-btn`).
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? background;
  final Color? foreground;
  final double size;
  final Widget? badge;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.background,
    this.foreground,
    this.size = 38,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final bg = background ?? ac.surface;
    final fg = foreground ?? ac.inkSoft;
    return ScaleButton(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: appElevationShadows(context),
        ),
        foregroundDecoration: darkTopEdgeHighlight(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, size: size * 0.44, color: fg)),
            if (badge != null)
              Positioned(
                top: -3,
                right: -3,
                child: badge!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Floating action button (`.fab`) — accent capsule.
class AppFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const AppFab({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ScaleButton(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: ac.accent,
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Icon(icon, size: 24, color: ac.onAccent),
      ),
    );
  }
}
