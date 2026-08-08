import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Floating capsule bottom nav matching the mockup's `.bottom-nav`: a sliding
/// `primaryContainer` indicator pill behind the active item, spring-eased.
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
  static const _indicatorInset = 5.0;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final activeColor = ac.primary;
    final inactiveColor = ac.inkFaint;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / _itemCount;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              left: currentIndex * itemWidth + _indicatorInset,
              top: 9,
              width: itemWidth - _indicatorInset * 2,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  color: ac.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Row(
              children: [
                _NavItem(index: 0, icon: Icons.dashboard_rounded, label: 'Dashboard', showDot: false,
                    isActive: 0 == currentIndex, activeColor: activeColor, inactiveColor: inactiveColor,
                    onTap: () => onTap(0)),
                _NavItem(index: 1, icon: Icons.sell_rounded, label: 'Sales', showDot: false,
                    isActive: 1 == currentIndex, activeColor: activeColor, inactiveColor: inactiveColor,
                    onTap: () => onTap(1)),
                _NavItem(index: 2, icon: Icons.inventory_2_rounded, label: 'Inventory', showDot: showInventoryDot,
                    isActive: 2 == currentIndex, activeColor: activeColor, inactiveColor: inactiveColor,
                    onTap: () => onTap(2)),
                _NavItem(index: 3, icon: Icons.people_rounded, label: 'Khata', showDot: showKhataDot,
                    isActive: 3 == currentIndex, activeColor: activeColor, inactiveColor: inactiveColor,
                    onTap: () => onTap(3)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool showDot;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
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
