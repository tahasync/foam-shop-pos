import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/firebase_providers.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/safe_error_handler.dart';
import '../widgets/design_system/design_system.dart';

const _categories = [
  'Cutting Labor',
  'Transport',
  'Electricity',
  'Packaging',
  'Rent',
  'Tea / Misc',
  'Other'
];

class ExpenseSheetScreen extends ConsumerStatefulWidget {
  const ExpenseSheetScreen({super.key});
  @override
  ConsumerState<ExpenseSheetScreen> createState() => _ExpenseSheetScreenState();
}

class _ExpenseSheetScreenState extends ConsumerState<ExpenseSheetScreen> {
  String _filterCategory = 'All';
  DateTime? _filterFrom, _filterTo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final expAsync = ref.watch(expensesStreamProvider);
    final csym = ref.watch(currencySymbolProvider);
    final fmt = NumberFormat('#,##0');

    return FullScreenOverlay(
      title: 'Expenses',
      actions: [
        // A single filter button. There used to be two stacked here — the first
        // had no `semanticLabel`, so screen readers announced an unnamed button
        // and the toolbar showed the same icon twice.
        AppIconButton(
          icon: Icons.filter_list_rounded,
          semanticLabel: 'Filter expenses',
          onTap: _showFilter,
        ),
        const SizedBox(width: 8),
        AppIconButton(
          semanticLabel: 'Add expense',
          icon: Icons.add_rounded,
          background: ac.brandFill,
          foreground: Colors.white,
          onTap: _addExpense,
        ),
      ],
      child: expAsync.when(
        loading: () => const _LoadingBox(),
        error: (e, _) => _ErrorBox(
            message:
                sanitizeErrorMessage(e, fallback: 'Could not load expenses')),
        data: (expenses) {
          final filtered = expenses.where((e) {
            if (_filterCategory != 'All' && e.category != _filterCategory)
              return false;
            if (_filterFrom != null && e.date.isBefore(_filterFrom!))
              return false;
            if (_filterTo != null &&
                e.date.isAfter(_filterTo!.add(const Duration(days: 1))))
              return false;
            return true;
          }).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final total = filtered.fold(0.0, (s, e) => s + e.amount);
          final filterActive = _filterCategory != 'All' ||
              _filterFrom != null ||
              _filterTo != null;

          if (filtered.isEmpty) {
            return EmptyState(
              icon: Icons.money_off_rounded,
              title: 'No expenses found',
              subtitle: 'Add an expense or change the filter to see entries',
            );
          }

          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filterActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${filtered.length} entr${filtered.length == 1 ? 'y' : 'ies'}',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: ac.inkFaint)),
                          Text('Total: $csym ${fmt.format(total.toInt())}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                        ]),
                  ),
                const SectionLabel(title: 'Recent'),
                FoamCard(
                  foam: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: ac.outline),
                      _ExpenseRow(
                        expense: filtered[i],
                        csym: csym,
                        fmt: fmt,
                        icon: _categoryIcon(filtered[i].category),
                        tint: ac.expenseTint,
                        fg: ac.expenseFg,
                      ),
                    ],
                  ]),
                ),
              ]);
        },
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String label) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ac.inkSoft,
              letterSpacing: 0.03)),
    );
  }

  Widget _dateButton(
      BuildContext context, DateTime date, ValueChanged<DateTime> onPicked) {
    final ac = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime.now());
        if (d != null) onPicked(d);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ac.glassFill,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: ac.glassBorder, width: 1.5),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 18, color: ac.inkFaint),
          const SizedBox(width: 8),
          Text('${date.day}/${date.month}/${date.year}',
              style: TextStyle(fontSize: 13.5, color: ac.ink)),
        ]),
      ),
    );
  }

  Widget _filterDateButton(BuildContext context, String prefix, DateTime? date,
      ValueChanged<DateTime> onPicked) {
    final ac = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now());
        if (d != null) onPicked(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ac.glassFill,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: ac.glassBorder, width: 1.5),
        ),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(prefix,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ac.inkSoft)),
          Text(date != null ? '${date.day}/${date.month}/${date.year}' : 'Any',
              style: TextStyle(fontSize: 12.5, color: ac.ink)),
        ]),
      ),
    );
  }

  void _showFilter() {
    String cat = _filterCategory;
    DateTime? from = _filterFrom, to = _filterTo;
    showAppSheet(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: StatefulBuilder(
          builder: (ctx, setSD) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Filter expenses',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 14),
            _fieldLabel(context, 'Category'),
            ChipRow(
                values: ['All', ..._categories],
                selected: cat,
                onSelected: (v) => setSD(() => cat = v)),
            const SizedBox(height: 14),
            _fieldLabel(context, 'Date range'),
            Row(children: [
              Expanded(
                  child: _filterDateButton(
                      ctx, 'From', from, (d) => setSD(() => from = d))),
              const SizedBox(width: 8),
              Expanded(
                  child: _filterDateButton(
                      ctx, 'To', to, (d) => setSD(() => to = d))),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: AppButton(
                  label: 'Clear',
                  variant: AppButtonVariant.ghost,
                  onTap: () => setSD(() {
                    cat = 'All';
                    from = null;
                    to = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Apply',
                  icon: Icons.check_rounded,
                  onTap: () {
                    setState(() {
                      _filterCategory = cat;
                      _filterFrom = from;
                      _filterTo = to;
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _addExpense() {
    final csym = ref.read(currencySymbolProvider);
    final fmt = NumberFormat('#,##0');
    final amtC = TextEditingController();
    final noteC = TextEditingController();
    String cat = _categories[0];
    DateTime date = DateTime.now();

    showAppSheet(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: StatefulBuilder(
          builder: (ctx, setSD) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Expense',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 14),
            _fieldLabel(context, 'Category'),
            ChipRow(
                values: _categories,
                selected: cat,
                onSelected: (v) => setSD(() => cat = v)),
            const SizedBox(height: 4),
            AppField(
                label: 'Amount ($csym)',
                controller: amtC,
                keyboardType: TextInputType.number),
            AppField(
                label: 'Note',
                controller: noteC,
                maxLines: 3,
                hintText: 'Optional description'),
            _fieldLabel(context, 'Date'),
            _dateButton(ctx, date, (d) => setSD(() => date = d)),
            const SizedBox(height: 4),
            AppButton(
              label: 'Save Expense',
              icon: Icons.check_rounded,
              onTap: () async {
                final a = double.tryParse(amtC.text) ?? 0;
                if (a <= 0) {
                  showAppToast(ctx, 'Enter a positive amount');
                  return;
                }
                final s = ref.read(firestoreServiceProvider);
                final cat2 = cat;
                await s.addExpense(Expense(
                    id: s.generateId(),
                    date: date,
                    category: cat2,
                    description: noteC.text.trim(),
                    amount: a));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  // Uses the shared design-system SuccessSheet like every other
                  // save in the app. The previous call went through
                  // `SaveSuccessSheet`, a second, older success dialog that only
                  // this screen still used. It was being driven with
                  // `paid == total` and `printLabel: ''`, so it rendered a
                  // pointless "Change: Rs 0" row and a duplicate Total for a
                  // plain expense confirmation.
                  SuccessSheet.show(
                    context: context,
                    title: 'Expense Saved',
                    subtitle: '$cat2 \u00b7 $csym ${fmt.format(a.toInt())}',
                    primaryLabel: '+ Add Expense',
                  );
                }
              },
            ),
          ]),
        ),
      ),
    ).then((_) {
      amtC.dispose();
      noteC.dispose();
    });
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Cutting Labor':
      return Icons.content_cut_rounded;
    case 'Transport':
      return Icons.local_shipping_rounded;
    case 'Electricity':
      return Icons.bolt_rounded;
    case 'Packaging':
      return Icons.inventory_2_rounded;
    case 'Rent':
      return Icons.home_rounded;
    case 'Tea / Misc':
      return Icons.local_cafe_rounded;
    default:
      return Icons.more_horiz_rounded;
  }
}

class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  final String csym;
  final NumberFormat fmt;
  final IconData icon;
  final Color tint;
  final Color fg;

  const _ExpenseRow({
    required this.expense,
    required this.csym,
    required this.fmt,
    required this.icon,
    required this.tint,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final cs = Theme.of(context).colorScheme;
    final title =
        expense.description.isNotEmpty ? expense.description : expense.category;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: tint, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 17, color: fg),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(height: 1),
            Text(
                '${expense.category} \u00b7 ${DateFormat('d MMM y').format(expense.date)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
          ]),
        ),
        const SizedBox(width: 8),
        Text('$csym ${fmt.format(expense.amount.toInt())}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: fg)),
      ]),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
        height: 260, child: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      ),
    );
  }
}
