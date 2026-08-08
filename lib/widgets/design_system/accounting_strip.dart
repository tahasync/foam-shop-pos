import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'elevation.dart';

/// Horizontal accounting strip (`.hstrip`) of compact value chips.
class AccountingStrip extends StatelessWidget {
  final List<AccountingChipData> items;
  final EdgeInsets padding;

  const AccountingStrip({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.fromLTRB(2, 2, 24, 6),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _AccountingChip(data: items[i]),
          ],
        ],
      ),
    );
  }
}

class AccountingChipData {
  final String label;
  final String value;
  final Color? valueColor;
  const AccountingChipData({required this.label, required this.value, this.valueColor});
}

class _AccountingChip extends StatelessWidget {
  final AccountingChipData data;
  const _AccountingChip({required this.data});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: ac.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.outline),
        boxShadow: appElevationShadows(context),
      ),
      foregroundDecoration: darkTopEdgeHighlight(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          data.label.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ac.inkFaint, letterSpacing: 0.03),
        ),
        const SizedBox(height: 3),
        Text(
          data.value,
          style: TextStyle(
            fontFamily: 'Fraunces',
            fontFamilyFallback: const ['serif'],
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: data.valueColor ?? Theme.of(context).colorScheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ]),
    );
  }
}
