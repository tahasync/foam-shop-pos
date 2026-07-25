import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class SaveSuccessSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<SheetLineItem> items;
  final double paid;
  final double total;
  final VoidCallback? onPrint;
  final VoidCallback? onNew;
  final String printLabel;
  final String newLabel;
  final Color? accentColor;
  final String csym;

  const SaveSuccessSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.paid,
    required this.total,
    this.onPrint,
    this.onNew,
    this.printLabel = 'Print Receipt',
    this.newLabel = '+ New',
    this.accentColor,
    this.csym = 'Rs',
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<SheetLineItem> items,
    required double paid,
    required double total,
    VoidCallback? onPrint,
    VoidCallback? onNew,
    String printLabel = 'Print Receipt',
    String newLabel = '+ New',
    String csym = 'Rs',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaveSuccessSheet(
        title: title,
        subtitle: subtitle,
        items: items,
        paid: paid,
        total: total,
        onPrint: onPrint,
        onNew: onNew,
        printLabel: printLabel,
        newLabel: newLabel,
        csym: csym,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final fmt = NumberFormat('#,##0');
    final accent = accentColor ?? AppTheme.teal;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, -10)),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 22,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: ac.profitTint, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, size: 28, color: ac.profitFg),
        ),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800, fontSize: 19)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(children: [
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(item.label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                Text(item.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()], color: cs.onSurface)),
              ]),
            )),
            Container(height: 1, color: cs.outlineVariant, margin: const EdgeInsets.symmetric(vertical: 8)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
              Text('$csym ${fmt.format(total.toInt())}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()], color: accent)),
            ]),
            const SizedBox(height: 5),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Paid', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              Text('$csym ${fmt.format(paid.toInt())}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()], color: cs.onSurface)),
            ]),
            const SizedBox(height: 5),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(paid >= total ? 'Change' : 'Balance Due',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                      color: paid >= total ? ac.profitFg : ac.expenseFg)),
              Text('$csym ${fmt.format((paid - total).abs().toInt())}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: paid >= total ? ac.profitFg : ac.expenseFg)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          if (onPrint != null)
            Expanded(
              child: FilledButton.tonal(
                onPressed: () { Navigator.pop(context); onPrint!(); },
                style: FilledButton.styleFrom(
                  backgroundColor: ac.inventoryTint,
                  foregroundColor: ac.inventoryFg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(printLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ),
          if (onPrint != null) const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () { Navigator.pop(context); onNew?.call(); },
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(newLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class SheetLineItem {
  final String label;
  final String value;
  const SheetLineItem({required this.label, required this.value});
}
