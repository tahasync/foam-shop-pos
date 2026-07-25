import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/sale.dart';
import '../providers/customer_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/firebase_providers.dart';
import '../providers/dashboard_provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/save_success_sheet.dart';
import '../widgets/app_search_bar.dart';
import '../providers/shop_provider.dart';
import '../utils/safe_error_handler.dart';

class CustomerRecoveryScreen extends ConsumerStatefulWidget {
  const CustomerRecoveryScreen({super.key});
  @override
  ConsumerState<CustomerRecoveryScreen> createState() => _CustomerRecoveryScreenState();
}

class _CustomerRecoveryScreenState extends ConsumerState<CustomerRecoveryScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final customersAsync = ref.watch(customersWithBaqayaProvider);
    final salesAsync = ref.watch(salesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Recovery'),
      ),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load data'),
                    style: TextStyle(color: cs.onSurface))),
            ),
        data: (csList) => salesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load data'),
                    style: TextStyle(color: cs.onSurface))),
            ),
          data: (sales) => paymentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load data'),
                    style: TextStyle(color: cs.onSurface))),
            ),
            data: (payments) {
              final withBaqaya = csList
                  .where((c) => _searchQuery.isEmpty || c.name.toLowerCase().contains(_searchQuery))
                  .map((c) {
                final total = sales
                    .where((s) => s.customerId == c.id && !s.isVoided && !s.isQuote)
                    .fold(0.0, (s, x) => s + x.amount);
                return (customer: c, outstanding: c.baqaya, totalDue: total);
              }).where((x) => x.outstanding > 0 || _searchQuery.isNotEmpty).toList();

              return Column(children: [
                AppSearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search customers\u2026',
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  onClear: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                ),
                Expanded(
                  child: withBaqaya.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.check_circle_rounded, size: 72, color: ac.profitFg),
                          const SizedBox(height: 16),
                          Text('No outstanding baqaya!', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurface)),
                          const SizedBox(height: 8),
                          Text('All customers are settled', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                        ]))
                      : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: withBaqaya.length,
                itemBuilder: (_, i) {
                  final item = withBaqaya[i];
                  final customerSales = sales
                      .where((s) => s.customerId == item.customer.id && !s.isVoided && !s.isQuote)
                      .toList();
                  final customerPayments = payments
                      .where((p) => p.customerId == item.customer.id)
                      .toList();
                  final csym = ref.read(currencySymbolProvider);
                  return _CustomerCard(
                    csym: csym,
                    customer: item.customer,
                    outstanding: item.outstanding,
                    totalDue: item.totalDue,
                    sales: customerSales,
                    payments: customerPayments,
                    onCollect: () => _collectPayment(context, ref, item.customer, item.outstanding),
                  );
                },
              ),
            ),
          ]);
          },
          ),
        ),
      ),
    );
  }

  void _collectPayment(BuildContext context, WidgetRef ref, Customer customer, double outstanding) {
    final csym = ref.read(currencySymbolProvider);
    final ctrl = TextEditingController(text: outstanding.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Collect from ${customer.name}'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Outstanding: $csym. ${outstanding.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrl,
                decoration: InputDecoration(labelText: 'Amount ($csym)', filled: true),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final amt = double.tryParse(v ?? '') ?? 0;
                  if (amt <= 0) return 'Enter a positive amount';
                  if (amt > outstanding) return 'Cannot exceed ${ref.read(currencySymbolProvider)}. ${outstanding.toStringAsFixed(0)}';
                  return null;
                },
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final amt = double.tryParse(ctrl.text) ?? 0;
            final s = ref.read(firestoreServiceProvider);
            await s.savePaymentTransaction(Payment(
                id: s.generateId(), date: DateTime.now(), customerId: customer.id, amountCollected: amt));
            ref.invalidate(accountingSummaryProvider);
            if (ctx.mounted) Navigator.pop(ctx);
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
          }, child: const Text('Record Payment')),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }
}

class _CustomerCard extends StatelessWidget {
  final String csym;
  final Customer customer;
  final double outstanding;
  final double totalDue;
  final List<Sale> sales;
  final List<Payment> payments;
  final VoidCallback onCollect;

  const _CustomerCard({
    required this.csym,
    required this.customer,
    required this.outstanding,
    required this.totalDue,
    required this.sales,
    required this.payments,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);

    final txns = <_RecoTxn>[
      ...sales.map((s) => _RecoTxn(
          date: s.date, desc: 'Sale #${s.id.substring(0, 6)}', amount: s.amount, isDebit: true)),
      ...payments.map((p) => _RecoTxn(
          date: p.date, desc: 'Payment Received', amount: -p.amountCollected, isDebit: false)),
    ];
    txns.sort((a, b) => b.date.compareTo(a.date));
    final recentTxns = txns.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: ac.expenseTint,
                child: Text((customer.name.isNotEmpty ? customer.name[0] : '?').toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w700, color: ac.expenseFg)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(customer.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                if (customer.phone.isNotEmpty)
                  Text(customer.phone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Outstanding', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text('$csym. ${outstanding.toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFeatures: [FontFeature('tnum')], color: ac.expenseFg)),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Total Due', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text('$csym. ${totalDue.toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFeatures: [FontFeature('tnum')], color: cs.onSurface)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            if (recentTxns.isNotEmpty) ...[
              Text('Recent Activity', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              ...recentTxns.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Text('${t.desc}  \u2022  ${t.date.day}/${t.date.month}',
                        style: TextStyle(fontSize: 11.5, color: cs.onSurface)),
                  ),
                  Text('${t.isDebit ? '+' : '-'} $csym. ${t.amount.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        fontFeatures: [FontFeature('tnum')],
                        color: t.isDebit ? ac.expenseFg : ac.profitFg,
                      )),
                ]),
              )),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: outstanding <= 0 ? null : onCollect,
                icon: Icon(outstanding <= 0 ? Icons.check_circle_rounded : Icons.payments_rounded, size: 16),
                label: Text(outstanding <= 0 ? 'Khata Cleared' : 'Collect Payment',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RecoTxn {
  final DateTime date;
  final String desc;
  final double amount;
  final bool isDebit;

  const _RecoTxn({required this.date, required this.desc, required this.amount, required this.isDebit});
}
