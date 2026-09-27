import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Floating frosted-glass bottom nav: a sliding active pill, four icon+label
/// destinations, and notification dots.
///
/// Fixes applied:
///  * **Text ghosting.** The pill was too transparent, so list content scrolling
///    underneath stayed readable *through* the labels and the bar looked broken.
///    The bar now sits on the `raised` glass level, which is dense enough to
///    isolate the labels from whatever is behind them.
///  * **Unreadable inactive state.** `inkFaint` on glass failed contrast, so
///    inactive labels are now `inkSoft`, which clears 4.5:1 in both themes.
///  * **Touch targets.** Each destination is a full-height tap target rather
///    than an icon-sized one, and has a real ink splash.
///  * **State exposure.** `Semantics(selected:)` announces the active tab.
class CustomNavBar extends StatelessWidget {
  const CustomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showInventoryDot = false,
    this.showKhataDot = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showInventoryDot;
  final bool showKhataDot;

  static const int _itemCount = 4;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final activeColor = ac.brandSolid;
    // `inkFaint` was too low-contrast over glass; `inkSoft` clears 4.5:1.
    final inactiveColor = ac.inkSoft;

    final items = <_NavItemData>[
      const _NavItemData(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        semantics: 'Dashboard tab',
      ),
      const _NavItemData(
        icon: Icons.sell_rounded,
        label: 'Sales',
        semantics: 'Sales tab',
      ),
      _NavItemData(
        icon: Icons.inventory_2_rounded,
        label: 'Inventory',
        showDot: showInventoryDot,
        semantics: 'Inventory tab',
      ),
      _NavItemData(
        icon: Icons.people_rounded,
        label: 'Khata',
        showDot: showKhataDot,
        semantics: 'Khata tab',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / _itemCount;
        return Stack(
          children: [
            // The sliding active indicator. `spring` gives a small overshoot
            // that makes the movement feel physical rather than mechanical.
            //
            // It now fills the pill's inner padding exactly (4dp on each side),
            // which is what makes the shorter bar read as one continuous strip
            // rather than a pill with a floating chip inside it.
            AnimatedPositioned(
              duration: AppMotion.base,
              curve: AppMotion.spring,
              left: currentIndex * itemWidth + AppSpacing.xs,
              top: AppSpacing.xs,
              width: itemWidth - AppSpacing.sm,
              height: constraints.maxHeight - AppSpacing.sm,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ac.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: ac.primary.withValues(alpha: 0.22)),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  _NavItem(
                    icon: items[i].icon,
                    label: items[i].label,
                    semantics: items[i].semantics,
                    showDot: items[i].showDot,
                    isActive: i == currentIndex,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.label,
    required this.semantics,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final String semantics;
  final bool showDot;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.semantics,
    required this.showDot,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semantics;
  final bool showDot;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final color = isActive ? activeColor : inactiveColor;

    return Expanded(
      child: Semantics(
        label: semantics,
        button: true,
        selected: isActive,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          // A real pressed state, rather than relying on scale alone.
          splashColor: ac.primary.withValues(alpha: 0.08),
          highlightColor: ac.primary.withValues(alpha: 0.05),
          child: SizedBox(
            // Fills the bar, so the target stays above the 48dp minimum even
            // though the bar itself is now slimmer.
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 19, color: color),
                    if (showDot)
                      Positioned(
                        top: -2,
                        right: -7,
                        child: _NotificationDot(color: AppTheme.amber),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.01,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The unread dot. It carries a contrasting ring so it stays visible on both the
/// active pill and the plain bar background. Colour is not the only signal — the
/// destination label is always present alongside it.
class _NotificationDot extends StatelessWidget {
  const _NotificationDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: surface, width: 1.5),
      ),
    );
  }
}