import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../providers/supplier_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/supplier_payment_provider.dart';
import '../providers/firebase_providers.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../widgets/initial_avatar.dart';
import '../utils/safe_error_handler.dart';

class SupplierKhataScreen extends ConsumerWidget {
  const SupplierKhataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final csym = ref.watch(currencySymbolProvider);
    final suppAsync = ref.watch(suppliersStreamProvider);
    final purchAsync = ref.watch(purchasesStreamProvider);
    final spPayAsync = ref.watch(supplierPaymentsStreamProvider);

    final combined = suppAsync.when(
      data: (suppliers) => purchAsync.when(
        data: (purchases) => spPayAsync.when(
          data: (spPay) {
            return suppliers.map((s) {
              final sp = purchases.where((p) => p.supplierId == s.id).fold(0.0, (sum, p) => sum + p.costAmount);
              final paid = purchases.where((p) => p.supplierId == s.id).fold(0.0, (sum, p) => sum + p.paid);
              final pa = spPay.where((p) => p.supplierId == s.id).fold(0.0, (sum, p) => sum + p.amountPaid);
              return _SupBal(supplier: s, balance: sp - paid - pa);
            }).toList();
          }, loading: () => null, error: (_, __) => null,
        ), loading: () => null, error: (_, __) => null,
      ), loading: () => null, error: (e, _) => <_SupBal>[],
    );

    if (combined == null) {
      return Scaffold(appBar: AppBar(title: const Text('Supplier Khata')),
          body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Khata'),
        actions: [IconButton(icon: const Icon(Icons.person_add_rounded), onPressed: () => _addSupplier(context, ref))],
      ),
      body: combined.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.people_outline_rounded, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No suppliers yet', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurface)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: combined.length,
              itemBuilder: (_, i) {
                final item = combined[i];
                return Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(context, slideUpRoute(
                        _SupDetail(supplier: item.supplier))),
                    child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                      InitialAvatar(
                        name: item.supplier.name,
                        size: 44,
                        backgroundColor: item.balance > 0 ? ac.purchaseTint : ac.profitTint,
                        foregroundColor: item.balance > 0 ? ac.purchaseFg : ac.profitFg),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.supplier.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                        if (item.supplier.phone.isNotEmpty)
                          Text(item.supplier.phone, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('$csym. ${item.balance.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontFeatures: [FontFeature('tnum')],
                                color: item.balance > 0 ? ac.purchaseFg : ac.profitFg)),
                        Text(item.balance <= 0 ? 'Clear' : 'Baqaya',
                            style: TextStyle(fontSize: 11, color: item.balance > 0 ? ac.purchaseFg : ac.profitFg)),
                      ]),
                    ])),
                  ),
                ));
              },
            ),
    );
  }

  void _addSupplier(BuildContext context, WidgetRef ref) {
    final nc = TextEditingController(); final pc = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Supplier'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nc, decoration: const InputDecoration(labelText: 'Name', filled: true)),
        const SizedBox(height: 8),
        TextField(controller: pc, decoration: const InputDecoration(labelText: 'Phone', filled: true), keyboardType: TextInputType.phone),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (nc.text.trim().isEmpty) return;
          final supplier = Supplier(id: ref.read(firestoreServiceProvider).generateId(), name: nc.text.trim(), phone: pc.text.trim());
          Navigator.of(ctx).pop();
          ref.read(firestoreServiceProvider).addSupplier(supplier).catchError((e, st) {
          logSecureError(e, st, tag: 'supplier_add');
        });
        }, child: const Text('Save')),
      ],
    )).whenComplete(() { nc.dispose(); pc.dispose(); });
  }
}

class _SupBal {
  final Supplier supplier; final double balance;
  const _SupBal({required this.supplier, required this.balance});
}

class _SupDetail extends ConsumerWidget {
  final Supplier supplier;
  const _SupDetail({required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final csym = ref.watch(currencySymbolProvider);
    final purchAsync = ref.watch(purchasesStreamProvider);
    final spPayAsync = ref.watch(supplierPaymentsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(supplier.name)),
      body: purchAsync.when(
        data: (purchases) => spPayAsync.when(
          data: (spPay) {
            final sp = purchases.where((p) => p.supplierId == supplier.id);
            final pa = spPay.where((p) => p.supplierId == supplier.id);
            final totalP = sp.fold(0.0, (s, x) => s + x.costAmount);
            final paidAtPurchase = sp.fold(0.0, (s, x) => s + x.paid);
            final totalPaid = pa.fold(0.0, (s, x) => s + x.amountPaid);
            final balance = totalP - paidAtPurchase - totalPaid;

            final txns = <_SupTxn>[
                ...sp.map((p) => _SupTxn(date: p.date, desc: 'Purchase — $csym.${p.costAmount.toStringAsFixed(0)}', isPurchase: true, amount: p.costAmount)),
                ...pa.map((p) => _SupTxn(date: p.date, desc: 'Payment — $csym.${p.amountPaid.toStringAsFixed(0)}', isPurchase: false, amount: p.amountPaid)),
            ];
            txns.sort((a, b) => b.date.compareTo(a.date));

            return Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: balance > 0 ? ac.purchaseTint : ac.profitTint,
                child: Column(children: [
                  Text('Current Baqaya',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.05,
                          color: balance > 0 ? ac.purchaseFg : ac.profitFg)),
                  const SizedBox(height: 4),
                  Text('$csym. ${balance.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800, fontFeatures: [FontFeature('tnum')],
                          color: balance > 0 ? ac.purchaseFg : ac.profitFg)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        shadowColor: AppTheme.teal.withValues(alpha: 0.3),
                      ),
                      onPressed: () => _pay(context, ref),
                      icon: const Icon(Icons.payments_rounded, size: 16),
                      label: const Text('Pay Supplier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Transaction History',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.06, color: cs.onSurfaceVariant)),
                ),
              ),
              Expanded(child: txns.isEmpty
                  ? Center(child: Text('No transactions', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurface)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: txns.length,
                      itemBuilder: (_, i) {
                        final t = txns[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outlineVariant),
                            boxShadow: [BoxShadow(color: cs.shadow, blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -4)],
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(t.desc,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
                                const SizedBox(height: 1),
                                Text('${t.date.day}/${t.date.month}/${t.date.year}',
                                    style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
                              ]),
                            ),
                            Text(
                               '${t.isPurchase ? '+' : '-'} $csym. ${t.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                fontFeatures: [FontFeature('tnum')],
                                color: t.isPurchase ? ac.purchaseFg : ac.profitFg,
                              ),
                            ),
                          ]),
                        );
                      },
                    )),
            ]);
          }, loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load data'),
                    style: TextStyle(color: cs.onSurface))),
            ),
        ), loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load data'),
                    style: TextStyle(color: cs.onSurface))),
            ),
      ),
    );
  }

  void _pay(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Pay Supplier'),
      content: SingleChildScrollView(child: TextField(controller: ctrl, decoration: InputDecoration(labelText: 'Amount (${ref.read(currencySymbolProvider)})', filled: true), keyboardType: TextInputType.number)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final amt = double.tryParse(ctrl.text) ?? 0;
          if (amt <= 0) return;
          final s = ref.read(firestoreServiceProvider);
          final payment = SupplierPayment(id: s.generateId(), date: DateTime.now(), supplierId: supplier.id, amountPaid: amt);
          Navigator.of(ctx).pop();
          s.addSupplierPayment(payment).catchError((_) {});
        }, child: const Text('Pay')),
      ],
    )).whenComplete(() => ctrl.dispose());
  }
}

class _SupTxn {
  final DateTime date; final String desc; final bool isPurchase; final double amount;
  const _SupTxn({required this.date, required this.desc, required this.isPurchase, required this.amount});
}
