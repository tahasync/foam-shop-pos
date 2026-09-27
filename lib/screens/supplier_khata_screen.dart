import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../providers/supplier_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/supplier_payment_provider.dart';
import '../providers/firebase_providers.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/safe_error_handler.dart';
import '../widgets/initial_avatar.dart';
import '../widgets/design_system/design_system.dart';

class SupplierKhataScreen extends ConsumerWidget {
  const SupplierKhataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final csym = ref.watch(currencySymbolProvider);
    final fmt = NumberFormat('#,##0');
    final suppAsync = ref.watch(suppliersStreamProvider);
    final purchAsync = ref.watch(purchasesStreamProvider);
    final spPayAsync = ref.watch(supplierPaymentsStreamProvider);

    final combined = suppAsync.when(
      data: (suppliers) => purchAsync.when(
        data: (purchases) => spPayAsync.when(
          data: (spPay) {
            return suppliers.map((s) {
              final sp = purchases
                  .where((p) => p.supplierId == s.id)
                  .fold(0.0, (sum, p) => sum + p.costAmount);
              final paid = purchases
                  .where((p) => p.supplierId == s.id)
                  .fold(0.0, (sum, p) => sum + p.paid);
              final pa = spPay
                  .where((p) => p.supplierId == s.id)
                  .fold(0.0, (sum, p) => sum + p.amountPaid);
              return _SupBal(supplier: s, balance: sp - paid - pa);
            }).toList();
          },
          loading: () => null,
          error: (_, __) => null,
        ),
        loading: () => null,
        error: (_, __) => null,
      ),
      loading: () => null,
      error: (e, _) => <_SupBal>[],
    );

    final totalPayable = combined == null
        ? 0.0
        : combined
            .where((b) => b.balance > 0)
            .fold(0.0, (s, b) => s + b.balance);

    return FullScreenOverlay(
      title: 'Supplier Khata',
      actions: [
        AppIconButton(
          icon: Icons.person_add_rounded,
          semanticLabel: 'Add supplier',
          onTap: () => _addSupplier(context, ref),
        ),
      ],
      child: combined == null
          ? const _LoadingBox()
          : combined.isEmpty
              ? EmptyState(
                  icon: Icons.business_rounded,
                  title: 'No suppliers yet',
                  subtitle: 'Add a supplier to track purchases and payables',
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FoamCard(
                    foam: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total payable',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: ac.inkSoft)),
                              const SizedBox(height: 4),
                              Text('$csym ${fmt.format(totalPayable.toInt())}',
                                  style: AppTheme.display(context,
                                      size: 24, color: ac.purchaseFg)),
                            ]),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: ac.purchaseTint,
                            borderRadius: BorderRadius.circular(13)),
                        child: Icon(Icons.shopping_bag_rounded,
                            size: 18, color: ac.purchaseFg),
                      ),
                    ]),
                  ),
                  const SectionLabel(title: 'Suppliers'),
                  for (final item in combined)
                    _buildRow(context, ref, cs, ac, csym, fmt, item),
                ]),
    );
  }

  Widget _buildRow(
    BuildContext context,
    WidgetRef ref,
    ColorScheme cs,
    AppColors ac,
    String csym,
    NumberFormat fmt,
    _SupBal item,
  ) {
    final due = item.balance > 0;
    final sub = item.supplier.phone.isNotEmpty
        ? item.supplier.phone
        : (due ? 'Payable' : 'Clear');
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      radius: 18,
      level: AppGlassLevel.raised,
      gloss: false,
      tint: due ? ac.purchaseFg.withValues(alpha: 0.06) : null,
      onTap: () => Navigator.push(
          context, slideUpRoute(_SupDetail(supplier: item.supplier))),
      child: Row(
        children: [
          InitialAvatar(
            name: item.supplier.name,
            size: 42,
            borderRadius: 13,
            fontSize: 14,
            backgroundColor: due ? ac.purchaseTint : ac.profitTint,
            foregroundColor: due ? ac.purchaseFg : ac.profitFg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.supplier.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: cs.onSurface)),
              const SizedBox(height: 1),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: ac.inkFaint)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$csym ${fmt.format(item.balance.toInt())}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: due ? ac.purchaseFg : ac.profitFg)),
            Text(due ? 'Payable' : 'Clear',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: due ? ac.purchaseFg : ac.inkFaint)),
          ]),
        ],
      ),
    );
  }

  void _addSupplier(BuildContext context, WidgetRef ref) {
    final nc = TextEditingController();
    final pc = TextEditingController();
    showAppSheet(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Supplier',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 14),
          AppField(label: 'Name', controller: nc),
          AppField(
              label: 'Phone',
              controller: pc,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.ghost,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Save',
                icon: Icons.check_rounded,
                onTap: () {
                  if (nc.text.trim().isEmpty) {
                    showAppToast(ctx, 'Enter a supplier name');
                    return;
                  }
                  final name = nc.text.trim();
                  final supplier = Supplier(
                      id: ref.read(firestoreServiceProvider).generateId(),
                      name: name,
                      phone: pc.text.trim());
                  Navigator.pop(ctx);
                  ref
                      .read(firestoreServiceProvider)
                      .addSupplier(supplier)
                      .catchError((e, st) {
                    logSecureError(e, st, tag: 'supplier_add');
                  });
                  if (context.mounted)
                    showAppToast(context, '$name added to ledger');
                },
              ),
            ),
          ]),
        ]),
      ),
    ).then((_) {
      nc.dispose();
      pc.dispose();
    });
  }
}

class _SupBal {
  final Supplier supplier;
  final double balance;
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
    final fmt = NumberFormat('#,##0');
    final purchAsync = ref.watch(purchasesStreamProvider);
    final spPayAsync = ref.watch(supplierPaymentsStreamProvider);

    return purchAsync.when(
      data: (purchases) => spPayAsync.when(
        data: (spPay) {
          final sp = purchases.where((p) => p.supplierId == supplier.id);
          final pa = spPay.where((p) => p.supplierId == supplier.id);
          final totalP = sp.fold(0.0, (s, x) => s + x.costAmount);
          final paidAtPurchase = sp.fold(0.0, (s, x) => s + x.paid);
          final totalPaid = pa.fold(0.0, (s, x) => s + x.amountPaid);
          final balance = totalP - paidAtPurchase - totalPaid;

          final txns = <_SupTxn>[
            ...sp.map((p) => _SupTxn(
                date: p.date,
                title: 'Purchase',
                isPurchase: true,
                amount: p.costAmount)),
            ...pa.map((p) => _SupTxn(
                date: p.date,
                title: 'Payment',
                isPurchase: false,
                amount: p.amountPaid)),
          ];
          txns.sort((a, b) => b.date.compareTo(a.date));

          return FullScreenOverlay(
            title: supplier.name,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              HeroCard(
                eyebrow: 'Balance due',
                amount: '$csym ${fmt.format(balance.toInt())}',
                pills: [
                  HeroPill(
                      label: 'Total purchased',
                      value: '$csym ${fmt.format(totalP.toInt())}'),
                  HeroPill(
                      label: 'Paid',
                      value:
                          '$csym ${fmt.format((paidAtPurchase + totalPaid).toInt())}'),
                ],
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Pay Supplier',
                icon: Icons.payments_rounded,
                onTap: balance > 0 ? () => _pay(context, ref, balance) : null,
              ),
              const SectionLabel(title: 'Transaction history'),
              if (txns.isEmpty)
                FoamCard(
                  foam: true,
                  child: EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No transactions',
                    subtitle:
                        'Purchases and payments for this supplier will appear here',
                    compact: true,
                  ),
                )
              else
                FoamCard(
                  foam: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(children: [
                    for (var i = 0; i < txns.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: ac.outline),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 4),
                        child: Row(children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: txns[i].isPurchase
                                  ? ac.purchaseTint
                                  : ac.profitTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              txns[i].isPurchase
                                  ? Icons.shopping_bag_rounded
                                  : Icons.savings_rounded,
                              size: 17,
                              color: txns[i].isPurchase
                                  ? ac.purchaseFg
                                  : ac.profitFg,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(txns[i].title,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurface)),
                                  const SizedBox(height: 1),
                                  Text(
                                      '${txns[i].date.day}/${txns[i].date.month}/${txns[i].date.year}',
                                      style: TextStyle(
                                          fontSize: 10.5, color: ac.inkFaint)),
                                ]),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${txns[i].isPurchase ? '+' : '\u2212'}$csym ${fmt.format(txns[i].amount.toInt())}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: txns[i].isPurchase
                                  ? ac.purchaseFg
                                  : ac.profitFg,
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ]),
                ),
            ]),
          );
        },
        loading: () => const _LoadingBox(),
        error: (e, _) => _ErrorBox(
            message: sanitizeErrorMessage(e, fallback: 'Could not load data')),
      ),
      loading: () => const _LoadingBox(),
      error: (e, _) => _ErrorBox(
          message: sanitizeErrorMessage(e, fallback: 'Could not load data')),
    );
  }

  void _pay(BuildContext context, WidgetRef ref, double balance) {
    final csym = ref.read(currencySymbolProvider);
    final fmt = NumberFormat('#,##0');
    final ctrl = TextEditingController();

    showAppSheet(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pay Supplier — ${supplier.name}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text('Outstanding: $csym ${fmt.format(balance.toInt())}',
              style: TextStyle(
                  fontSize: 11, color: AppColors.of(context).inkFaint)),
          const SizedBox(height: 14),
          AppField(
              label: 'Amount ($csym)',
              controller: ctrl,
              keyboardType: TextInputType.number),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.ghost,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Pay',
                icon: Icons.check_rounded,
                onTap: () {
                  final amt = double.tryParse(ctrl.text) ?? 0;
                  if (amt <= 0) {
                    showAppToast(ctx, 'Enter a positive amount');
                    return;
                  }
                  if (amt > balance) {
                    showAppToast(ctx, 'Cannot exceed the outstanding balance');
                    return;
                  }
                  final s = ref.read(firestoreServiceProvider);
                  final payment = SupplierPayment(
                      id: s.generateId(),
                      date: DateTime.now(),
                      supplierId: supplier.id,
                      amountPaid: amt);
                  Navigator.pop(ctx);
                  s.addSupplierPayment(payment).catchError((_) {});
                  if (context.mounted)
                    showAppToast(
                        context, 'Payment recorded for ${supplier.name}');
                },
              ),
            ),
          ]),
        ]),
      ),
    ).then((_) => ctrl.dispose());
  }
}

class _SupTxn {
  final DateTime date;
  final String title;
  final bool isPurchase;
  final double amount;
  const _SupTxn({
    required this.date,
    required this.title,
    required this.isPurchase,
    required this.amount,
  });
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
