import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../providers/customer_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/firebase_providers.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../widgets/torn_receipt_card.dart';
import '../widgets/save_success_sheet.dart';
import '../providers/shop_provider.dart';
import '../utils/safe_error_handler.dart';

class CustomerKhataScreen extends ConsumerWidget {
  const CustomerKhataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final customersAsync = ref.watch(customersStreamProvider);
    final salesAsync = ref.watch(salesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final csym = ref.watch(currencySymbolProvider);

    final combined = customersAsync.when(
      data: (csList) => salesAsync.when(
        data: (sales) => paymentsAsync.when(
          data: (payments) => csList.map((c) {
            final cSales = sales.where((s) => s.customerId == c.id && !s.isVoided && !s.isQuote);
            final cPayments = payments.where((p) => p.customerId == c.id);
            final total = cSales.fold(0.0, (s, x) => s + x.amount);
            final paid = cSales.fold(0.0, (s, x) => s + x.paid);
            final recv = cPayments.fold(0.0, (s, x) => s + x.amountCollected);
            return _CustBal(customer: c, balance: (total - paid - recv).clamp(0, double.infinity));
          }).toList(),
          loading: () => null, error: (_, __) => null,
        ),
        loading: () => null, error: (_, __) => null,
      ),
      loading: () => null, error: (e, _) => <_CustBal>[],
    );

    if (combined == null) {
      return Scaffold(appBar: AppBar(title: const Text('Customer Khata')),
          body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Khata')),
      body: combined.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.people_outline_rounded, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No customers yet', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurface)),
            ]))
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + MediaQuery.of(context).padding.bottom),
              itemCount: combined.length,
              itemBuilder: (_, i) {
                final item = combined[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => _CustDetail(customer: item.customer))),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: item.balance > 0 ? ac.expenseTint : ac.profitTint,
                            child: Text((item.customer.name.isNotEmpty ? item.customer.name[0] : '?').toUpperCase(),
                                style: TextStyle(fontWeight: FontWeight.w700,
                                    color: item.balance > 0 ? ac.expenseFg : ac.profitFg)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.customer.name,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                              if (item.customer.phone.isNotEmpty)
                                Text(item.customer.phone,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                            ],
                          )),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('$csym. ${item.balance.toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700, fontFeatures: [FontFeature('tnum')],
                                    color: item.balance > 0 ? ac.expenseFg : ac.profitFg)),
                            Text(item.balance <= 0 ? 'Clear' : 'Baqaya',
                                style: TextStyle(fontSize: 11, color: item.balance > 0 ? ac.expenseFg : ac.profitFg)),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CustBal {
  final Customer customer; final double balance;
  const _CustBal({required this.customer, required this.balance});
}

class _CustDetail extends ConsumerWidget {
  final Customer customer;
  const _CustDetail({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final csym = ref.watch(currencySymbolProvider);
    final salesAsync = ref.watch(salesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
      ),
      body: salesAsync.when(
        data: (sales) => paymentsAsync.when(
          data: (payments) {
            final cSales = sales.where((s) => s.customerId == customer.id && !s.isVoided && !s.isQuote);
            final cPayments = payments.where((p) => p.customerId == customer.id);
            final total = cSales.fold(0.0, (s, x) => s + x.amount);
            final paid = cSales.fold(0.0, (s, x) => s + x.paid);
            final recv = cPayments.fold(0.0, (s, x) => s + x.amountCollected);
            final balance = (total - paid - recv).clamp(0, double.infinity);

            final txns = <_Txn>[
              ...cSales.map((s) {
                final items = s.lineItems.map((li) => li.name ?? li.productId).where((n) => n.isNotEmpty).toList();
                final desc = items.isEmpty ? 'Sale #${s.id.substring(0, 6)}'
                    : items.length == 1 ? 'Sale — ${items.first}'
                    : 'Sale — ${items.first} (+${items.length - 1} items)';
                return _Txn(date: s.date, desc: desc, isSale: true, amount: s.amount);
              }),
              ...cPayments.map((p) => _Txn(date: p.date, desc: 'Payment Collected', isSale: false, amount: p.amountCollected)),
            ];
            txns.sort((a, b) => b.date.compareTo(a.date));

            final saleCount = cSales.length;

            final bottomPad = MediaQuery.of(context).padding.bottom;
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 100 + bottomPad),
              children: [
                Row(children: [
                  Container(width: 38, height: 38,
                    decoration: BoxDecoration(color: ac.inventoryTint, borderRadius: BorderRadius.circular(12)),
                    child: Text((customer.name.isNotEmpty ? customer.name[0] : '?').toUpperCase(), textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ac.inventoryFg))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(customer.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('${customer.phone.isNotEmpty ? '${customer.phone} · ' : ''}$saleCount sales',
                        style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
                  ])),
                ]),
                const SizedBox(height: 14),
                TornReceiptCard(
                  label: 'Outstanding Baqaya',
                  amount: '$csym ${balance.toStringAsFixed(0)}',
                  gradientStart: AppTheme.terracotta,
                  gradientEnd: const Color(0xFF8C3324),
                  stubLeft: 'Customer slip',
                  stubRight: customer.name,
                  bottomAction: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: balance <= 0 ? null : AppTheme.teal,
                        foregroundColor: balance <= 0 ? null : Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        elevation: 0,
                        shadowColor: AppTheme.teal.withValues(alpha: 0.32),
                      ),
                      onPressed: balance <= 0 ? null : () => _collectPayment(context, ref, customer, currentBalance: balance.toDouble()),
                      icon: Icon(balance <= 0 ? Icons.check_circle_rounded : Icons.credit_card_rounded, size: 16),
                      label: Text(balance <= 0 ? 'Khata Cleared' : 'Collect Payment',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ),
                Row(children: [
                  Text('History', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 0.06, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 1, decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: cs.outlineVariant, width: 1))),
                      margin: const EdgeInsets.only(top: 6))),
                ]),
                const SizedBox(height: 9),
                if (txns.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text('No transactions', style: TextStyle(color: cs.onSurfaceVariant))))
                else
                  ...txns.map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [BoxShadow(color: cs.shadow, blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -4)],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.desc, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
                        const SizedBox(height: 1),
                        Text('${t.date.day}/${t.date.month}/${t.date.year}', style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
                    ])),
                    Text(
                      '${t.isSale ? '+' : '-'} $csym. ${t.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: t.isSale ? ac.expenseFg : ac.profitFg,
                      ),
                    ),
                  ]),
                )),
            ],
          );
        },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load data'),
                    style: TextStyle(color: cs.onSurface))),
            ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load data'),
                    style: TextStyle(color: cs.onSurface))),
            ),
      ),
    );
  }
}

void _collectPayment(BuildContext context, WidgetRef ref, Customer customer, {double currentBalance = 0}) {
  final csym = ref.read(currencySymbolProvider);
  final ctrl = TextEditingController(text: currentBalance > 0 ? currentBalance.toStringAsFixed(0) : '');
  final formKey = GlobalKey<FormState>();
    showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text('Collect Payment'),
    content: SingleChildScrollView(child: Form(
      key: formKey,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (currentBalance > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Outstanding: $csym. ${currentBalance.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
          ),
        TextFormField(
          controller: ctrl,
          decoration: InputDecoration(labelText: 'Amount ($csym)', filled: true),
          keyboardType: TextInputType.number,
          validator: (v) {
            final amt = double.tryParse(v ?? '') ?? 0;
            if (amt <= 0) return 'Enter a positive amount';
            if (amt > currentBalance) return 'Cannot exceed $csym. ${currentBalance.toStringAsFixed(0)}';
            return null;
          },
        ),
      ]),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (!formKey.currentState!.validate()) return;
        final amt = double.tryParse(ctrl.text) ?? 0;
        final s = ref.read(firestoreServiceProvider);
        final payment = Payment(id: s.generateId(), date: DateTime.now(), customerId: customer.id, amountCollected: amt);
        Navigator.of(ctx).pop();
        s.savePaymentTransaction(payment).then((_) {
          ref.invalidate(accountingSummaryProvider);
          if (context.mounted) {
            final csym2 = ref.read(currencySymbolProvider);
            SaveSuccessSheet.show(
              context: context,
              title: 'Payment Collected',
              subtitle: '${customer.name} \u00b7 $csym2 ${NumberFormat('#,##0').format(amt.toInt())}',
              items: [SheetLineItem(label: customer.name, value: '$csym2 ${NumberFormat('#,##0').format(amt.toInt())}')],
              paid: amt,
              total: amt,
              newLabel: '+ Collect Again',
              onNew: () {},
              csym: csym2,
            );
          }
        }).catchError((e, st) {
          logSecureError(e, st, tag: 'payment');
        });
      }, child: const Text('Save')),
    ],
  )).then((_) => ctrl.dispose());
}

class _Txn {
  final DateTime date; final String desc; final bool isSale; final double amount;
  const _Txn({required this.date, required this.desc, required this.isSale, required this.amount});
}
