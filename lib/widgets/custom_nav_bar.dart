import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Floating frosted-glass bottom nav (`.nav-bar` in the liquid-glass mockup):
/// translucent blur, 1px glass edge, teal active state with a soft indicator.
class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showInventoryDot;
  final bool showKhataDot;

  const CustomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showInventoryDot = false,
    this.showKhataDot = false,
  });

  static const _itemCount = 4;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = ac.brandSolid;
    final inactiveColor = ac.inkFaint;

    final items = <_NavItemData>[
      _NavItemData(icon: Icons.dashboard_rounded, label: 'Dashboard', showDot: false),
      _NavItemData(icon: Icons.sell_rounded, label: 'Sales', showDot: false),
      _NavItemData(icon: Icons.inventory_2_rounded, label: 'Inventory', showDot: showInventoryDot),
      _NavItemData(icon: Icons.people_rounded, label: 'Khata', showDot: showKhataDot),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / _itemCount;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              left: currentIndex * itemWidth + 8,
              top: 7,
              width: itemWidth - 16,
              height: constraints.maxHeight - 14,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x243D5387)
                      : const Color(0x33DEE3F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0x333D5387) : const Color(0x993D5387),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  _NavItem(
                    icon: items[i].icon,
                    label: items[i].label,
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
  final IconData icon;
  final String label;
  final bool showDot;
  const _NavItemData({required this.icon, required this.label, this.showDot = false});
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showDot;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.showDot,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: color),
                if (showDot)
                  Positioned(
                    top: 8,
                    right: 24,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: AppTheme.amber, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}