import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

/// A settings row: icon chip, title, optional subtitle, optional trailing.
///
/// Fixes applied:
///  * the icon chip used the *opaque* `surfaceHigh` fill, which punched a solid
///    square out of the surrounding glass. It is now a translucent nested tint,
///    so the card's glass reads continuously behind it,
///  * the row is a real 48dp-minimum tap target with a bounded ink splash, and
///  * a chevron is only shown when the row is actually tappable.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final iconBg = danger ? ac.expenseTint : ac.glassNested;
    final iconFg = danger ? ac.expenseFg : ac.inkSoft;
    final titleColor = danger ? ac.expenseFg : ac.ink;

    return Semantics(
      button: onTap != null,
      label: subtitle == null ? title : '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        splashColor: ac.glassPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppHit.min),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: iconFg.withValues(alpha: 0.14)),
                ),
                child: Icon(icon, size: AppIconSize.sm, color: iconFg),
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
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: ac.inkFaint),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: AppIconSize.sm, color: ac.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Themed switch.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: ac.primary,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: ac.glassNested,
      trackOutlineColor: WidgetStatePropertyAll(ac.glassHairline),
    );
  }
}

/// Section heading with an optional trailing action.
///
/// The label is decorative here - it is a heading, not a control - so it is
/// hidden from the accessibility tree to avoid a redundant announcement before
/// the section's content.
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sectionTop,
        bottom: AppSpacing.md,
        left: AppSpacing.xxs,
        right: AppSpacing.xxs,
      ),
      child: Row(
        children: [
          // `Expanded` must be a *direct* child of the `Row` below. Wrapping it
          // in `ExcludeSemantics` put another widget between the Flex and its
          // child, so the FlexParentData was applied to the wrong RenderObject
          // ("Incorrect use of ParentDataWidget"), the whole section failed to
          // lay out, and every screen containing a SectionLabel rendered with a
          // blank body. Exclude the Text itself instead — same a11y result,
          // correct parent data.
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.06,
                  color: ac.inkFaint,
                ),
              ),
            ),
          ),
          if (actionLabel != null)
            Semantics(
              button: true,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(AppRadii.xs),
                child: Padding(
                  // A generous vertical pad makes this a comfortable target
                  // even though the text itself is 11px.
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ac.primary,
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