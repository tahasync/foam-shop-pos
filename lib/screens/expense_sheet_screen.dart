import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/firebase_providers.dart';
import 'package:intl/intl.dart';
import '../widgets/save_success_sheet.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/safe_error_handler.dart';

const _categories = ['Cutting Labor', 'Transport', 'Electricity', 'Packaging', 'Rent', 'Tea / Misc', 'Other'];

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Sheet'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list_rounded), onPressed: _showFilter),
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addExpense),
        ],
      ),
      body: expAsync.when(
        data: (expenses) {
          var filtered = expenses.where((e) {
            if (_filterCategory != 'All' && e.category != _filterCategory) return false;
            if (_filterFrom != null && e.date.isBefore(_filterFrom!)) return false;
            if (_filterTo != null && e.date.isAfter(_filterTo!.add(const Duration(days: 1)))) return false;
            return true;
          }).toList()..sort((a, b) => b.date.compareTo(a.date));
          final total = filtered.fold(0.0, (s, e) => s + e.amount);

          if (filtered.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.money_off_rounded, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No expenses found', style: Theme.of(context).textTheme.bodyLarge),
            ]));
          }

          return Column(children: [
            if (_filterCategory != 'All' || _filterFrom != null)
              Container(width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: cs.primaryContainer.withValues(alpha: 0.3),
                child: Text('Filter: $_filterCategory${_filterFrom != null ? ' | From: ${_filterFrom!.day}/${_filterFrom!.month}' : ''}${_filterTo != null ? ' To: ${_filterTo!.day}/${_filterTo!.month}' : ''}',
                    style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${filtered.length} entries', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                Text('Total: $csym. ${total.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
              ]),
            ),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final e = filtered[i];
                return Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(
                  child: ListTile(
                    leading: Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: ac.expenseTint, borderRadius: BorderRadius.circular(10)),
                      child: Text(e.category[0], textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700, color: ac.expenseFg))),
                    title: Text('${e.category} — $csym. ${e.amount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: cs.onSurface)),
                    subtitle: Text(e.description.isNotEmpty
                        ? '${e.description} | ${e.date.day}/${e.date.month}/${e.date.year}'
                        : '${e.date.day}/${e.date.month}/${e.date.year}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                ));
              },
            )),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load expenses'),
                    style: TextStyle(color: cs.onSurface))),
            ),
      ),
    );
  }

  void _showFilter() {
    String cat = _filterCategory;
    DateTime? from = _filterFrom, to = _filterTo;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSD) => AlertDialog(
        title: const Text('Filter'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: cat, decoration: const InputDecoration(labelText: 'Category', filled: true),
              items: ['All', ..._categories].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setSD(() => cat = v ?? 'All')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () async {
              final d = await showDatePicker(context: ctx, initialDate: from ?? DateTime.now(),
                  firstDate: DateTime(2020), lastDate: DateTime.now());
              if (d != null) setSD(() => from = d);
            }, child: Text(from != null ? 'From: ${from!.day}/${from!.month}' : 'From'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () async {
              final d = await showDatePicker(context: ctx, initialDate: to ?? DateTime.now(),
                  firstDate: DateTime(2020), lastDate: DateTime.now());
              if (d != null) setSD(() => to = d);
            }, child: Text(to != null ? 'To: ${to!.day}/${to!.month}' : 'To'))),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => setSD(() { cat = 'All'; from = null; to = null; }), child: const Text('Clear')),
          FilledButton(onPressed: () { setState(() { _filterCategory = cat; _filterFrom = from; _filterTo = to; }); Navigator.pop(ctx); }, child: const Text('Apply')),
        ],
      ),
    ));
  }

  void _addExpense() {
    final csym = ref.read(currencySymbolProvider);
    final ac = TextEditingController(); final dc = TextEditingController();
    String cat = _categories[0]; DateTime date = DateTime.now();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSD) => AlertDialog(
        title: const Text('Add Expense'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: cat, decoration: const InputDecoration(labelText: 'Category', filled: true),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => cat = v ?? cat),
          const SizedBox(height: 8),
          TextField(controller: dc, decoration: const InputDecoration(labelText: 'Description', filled: true)),
          const SizedBox(height: 8),
          TextField(controller: ac, decoration: InputDecoration(labelText: 'Amount ($csym)', filled: true), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () async {
            final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setSD(() => date = d);
          }, icon: const Icon(Icons.calendar_today_rounded), label: Text('${date.day}/${date.month}/${date.year}')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            final a = double.tryParse(ac.text) ?? 0;
            if (a <= 0) return;
            final s = ref.read(firestoreServiceProvider);
            final cat2 = cat;
            await s.addExpense(Expense(id: s.generateId(), date: date, category: cat2, description: dc.text.trim(), amount: a));
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              SaveSuccessSheet.show(
                context: context,
                title: 'Expense Saved',
                subtitle: '$cat2 \u00b7 $csym ${NumberFormat('#,##0').format(a.toInt())}',
                items: [SheetLineItem(label: dc.text.trim().isEmpty ? cat2 : dc.text.trim(), value: '$csym ${NumberFormat('#,##0').format(a.toInt())}')],
                paid: a,
                total: a,
                printLabel: '',
                newLabel: '+ Add Expense',
                onNew: () {},
                csym: csym,
              );
            }
          }, child: const Text('Save')),
        ],
      ),
    )).then((_) { ac.dispose(); dc.dispose(); });
  }
}
