import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'glass_container.dart';

/// A horizontally scrollable row of glass pills (`.chip-row` / `.chip`).
class ChipRow extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  final Color? selectedColor;
  final EdgeInsets padding;

  const ChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
    this.padding = const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _Chip(
              label: values[i],
              active: values[i] == selected,
              onTap: () => onSelected(values[i]),
              activeColor: selectedColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  const _Chip({required this.label, required this.active, required this.onTap, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = active ? (activeColor ?? ac.brandSolid) : null;
    final fg = active
        ? (isDark ? ac.ink : Colors.white)
        : ac.inkSoft;
    return GestureDetector(
      onTap: onTap,
      child: ActiveGlassPill(label: label, fill: fill, fg: fg),
    );
  }
}

/// Small frosted pill — shared by chip rows and badges.
class ActiveGlassPill extends StatelessWidget {
  final String label;
  final Color? fill; // solid active fill (null → frosted glass)
  final Color fg;
  const ActiveGlassPill({
    super.key,
    required this.label,
    this.fill,
    this.fg = const Color(0xFF9A98A5),
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: fill ?? ac.glassBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fill != null ? fg : ac.inkSoft,
        ),
      ),
    );
  }
}

/// Segmented control (`.segmented`) — a frosted-glass pill of options with a
/// tinted active segment.
class SegmentedControl extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const SegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GlassContainer(
      padding: const EdgeInsets.all(4),
      blur: 12,
      strong: true,
      gloss: false,
      tint: Colors.white.withValues(alpha: 0.1),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: i == selectedIndex ? ac.ink : ac.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}