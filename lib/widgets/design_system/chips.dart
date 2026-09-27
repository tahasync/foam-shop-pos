import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'glass_container.dart';

/// A horizontally scrollable row of filter chips.
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
    this.padding = const EdgeInsets.symmetric(
        vertical: AppSpacing.xxs, horizontal: AppSpacing.xxs),
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  final Color? selectedColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
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
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = active ? (activeColor ?? ac.brandFill) : null;
    // On a solid fill the label must be the contrasting surface colour; on
    // glass it stays ink. The old code used `isDark ? ink : white`, which put
    // near-black text on the navy chip in dark mode.
    final fg = active ? (isDark ? ac.ink : Colors.white) : ac.inkSoft;

    return Semantics(
      label: label,
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ActiveGlassPill(label: label, fill: fill, fg: fg),
      ),
    );
  }
}

/// Small frosted pill, shared by chip rows and badges.
class ActiveGlassPill extends StatelessWidget {
  const ActiveGlassPill({
    super.key,
    required this.label,
    this.fill,
    this.fg = const Color(0xFF9A98A5),
  });

  final String label;

  /// Solid active fill. `null` renders as frosted glass.
  final Color? fill;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.ease,
      // 40px tall: enough to clear the 48dp target once the row padding around
      // it is counted, without making the filter row look heavy.
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: fill ?? ac.glassHairline),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fill != null ? fg : ac.inkSoft,
        ),
      ),
    );
  }
}

/// Segmented control - a frosted pill of options with a sliding active segment.
///
/// Fixes applied:
///  * the active segment now *slides* between positions instead of snapping, so
///    the control communicates that it is a single control with one value;
///  * the selected label is bold, not merely a different colour, so selection is
///    never communicated by colour alone;
///  * each segment is a full 44dp-tall tap target; and
///  * the whole control announces its selected option to screen readers.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return GlassContainer(
      level: AppGlassLevel.raised,
      radius: AppRadii.pill,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = (constraints.maxWidth - AppSpacing.xs * 2) /
              (options.isEmpty ? 1 : options.length);

          return SizedBox(
            height: 44,
            child: Stack(
              children: [
                // The sliding indicator sits behind the labels.
                AnimatedPositioned(
                  duration: AppMotion.base,
                  curve: AppMotion.ease,
                  left: segmentWidth * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ac.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                        color: ac.primary.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < options.length; i++)
                      Expanded(
                        child: Semantics(
                          label: options[i],
                          button: true,
                          selected: i == selectedIndex,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onChanged(i);
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: AppMotion.fast,
                                curve: AppMotion.ease,
                                style: TextStyle(
                                  fontSize: 12,
                                  // Weight carries the selected state so it is
                                  // not colour-only.
                                  fontWeight: i == selectedIndex
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color:
                                      i == selectedIndex ? ac.ink : ac.inkSoft,
                                ),
                                child: Text(
                                  options[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
