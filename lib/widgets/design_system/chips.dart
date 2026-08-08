import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'elevation.dart';

/// A horizontally scrollable row of pills (`.chip-row` / `.chip`).
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: active ? (activeColor ?? ac.primary) : ac.surface,
          borderRadius: BorderRadius.circular(999),
          border: active ? Border.all(color: Colors.transparent) : Border.all(color: ac.outline, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Theme.of(context).colorScheme.onPrimary : ac.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// Segmented control (`.segmented`) — a pill of options with a sliding active
/// segment.
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ac.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
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
                    color: i == selectedIndex ? cs.surfaceContainerLowest : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: i == selectedIndex ? appElevationShadows(context) : null,
                  ),
                  foregroundDecoration: i == selectedIndex ? darkTopEdgeHighlight(context) : null,
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: i == selectedIndex ? ac.primary : ac.inkSoft,
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
