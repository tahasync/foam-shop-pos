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
import '../utils/animations.dart';
import 'package:intl/intl.dart';
import '../widgets/initial_avatar.dart';
import '../providers/shop_provider.dart';
import '../utils/safe_error_handler.dart';
import '../widgets/design_system/design_system.dart';
import '../widgets/add_customer_sheet.dart';
import 'customer_recovery_screen.dart';
import 'supplier_khata_screen.dart';

class CustomerKhataScreen extends ConsumerStatefulWidget {
  /// Bottom space reserved for the floating nav pill. Supplied by
  /// `HomeScreen.contentBottomInset` so every tab agrees.
  final double bottomInset;

  const CustomerKhataScreen({super.key, this.bottomInset = 120});
  @override
  ConsumerState<CustomerKhataScreen> createState() =>
      _CustomerKhataScreenState();
}

class _CustomerKhataScreenState extends ConsumerState<CustomerKhataScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCustomer() async {
    final result = await showAddCustomerSheet(context, ref);
    if (result != null && mounted) {
      showAppToast(context, '${result.name} added to ledger');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final customersAsync = ref.watch(customersStreamProvider);
    final salesAsync = ref.watch(salesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final csym = ref.watch(currencySymbolProvider);
    final bottom = widget.bottomInset;

    String _fmt(double v) => '$csym ${NumberFormat('#,##0').format(v.toInt())}';

    final combined = customersAsync.when(
      data: (csList) => salesAsync.when(
        data: (sales) => paymentsAsync.when(
          data: (payments) {
            final balList = csList.map((c) {
              final cSales = sales.where(
                  (s) => s.customerId == c.id && !s.isVoided && !s.isQuote);
              final cPayments = payments.where((p) => p.customerId == c.id);
              final total = cSales.fold(0.0, (s, x) => s + x.amount);
              final paid = cSales.fold(0.0, (s, x) => s + x.paid);
              final recv = cPayments.fold(0.0, (s, x) => s + x.amountCollected);
              final lastSale = cSales.fold<DateTime?>(
                  null,
                  (prev, s) =>
                      prev == null || s.date.isAfter(prev) ? s.date : prev);
              final lastPayment = cPayments.fold<DateTime?>(
                  null,
                  (prev, p) =>
                      prev == null || p.date.isAfter(prev) ? p.date : prev);
              final lastActivity = [lastSale, lastPayment]
                  .whereType<DateTime>()
                  .fold<DateTime?>(null,
                      (prev, d) => prev == null || d.isAfter(prev) ? d : prev);
              return _CustBal(
                customer: c,
                balance: (total - paid - recv).clamp(0, double.infinity),
                lastActivity: lastActivity ?? DateTime(0),
                lastSale: lastSale,
                lastPayment: lastPayment,
              );
            }).toList();
            balList.sort((a, b) {
              final cmp = b.lastActivity.compareTo(a.lastActivity);
              if (cmp != 0) return cmp;
              return a.customer.name.compareTo(b.customer.name);
            });
            return balList;
          },
          loading: () => null,
          error: (_, __) => null,
        ),
        loading: () => null,
        error: (_, __) => null,
      ),
      loading: () => null,
      error: (e, _) => <_CustBal>[],
    );

    final payments = paymentsAsync.asData?.value ?? [];
    final now = DateTime.now();
    final todayPayments = payments
        .where((p) =>
            p.date.year == now.year &&
            p.date.month == now.month &&
            p.date.day == now.day)
        .toList();
    final collectedToday =
        todayPayments.fold(0.0, (s, p) => s + p.amountCollected);
    final summary = ref.watch(accountingSummaryProvider).asData?.value;
    final dueCount =
        combined == null ? 0 : combined.where((b) => b.balance > 0).length;
    final double totalReceivable;
    if (summary != null) {
      totalReceivable = summary.totalCustomerBaqaya;
    } else if (combined != null) {
      totalReceivable = combined.fold(0.0, (s, b) => s + b.balance);
    } else {
      totalReceivable = 0.0;
    }

    final filtered = combined == null
        ? null
        : combined
            .where((b) =>
                _query.isEmpty ||
                b.customer.name.toLowerCase().contains(_query))
            .toList();

    return GlassScaffold(
      safeBottom: false,
      child: Column(children: [
        AppBarRow(
          showBrand: false,
          title: 'Khata',
          trailing: [
            AppIconButton(
              icon: Icons.currency_exchange_rounded,
              semanticLabel: 'Customer recovery',
              onTap: () => Navigator.push(
                  context, slideUpRoute(const CustomerRecoveryScreen())),
            ),
            const SizedBox(width: 8),
            AppIconButton(
              semanticLabel: 'Supplier khata',
              icon: Icons.business_rounded,
              onTap: () => Navigator.push(
                  context, slideUpRoute(const SupplierKhataScreen())),
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: Icons.add_rounded,
              semanticLabel: 'Add customer',
              background: ac.brandFill,
              foreground: Colors.white,
              onTap: _addCustomer,
            ),
          ],
        ),
        Expanded(
          child: combined == null
              ? const Center(child: CircularProgressIndicator())
              : filtered!.isEmpty
                  ? (combined.isEmpty
                      ? EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'No customers yet',
                          subtitle:
                              'Add a customer to start tracking their khata',
                        )
                      : NoResults(
                          title: 'No customers match',
                          subtitle: 'Try a different search term',
                        ))
                  : ListView(
                      padding: EdgeInsets.fromLTRB(18, 0, 18, bottom),
                      children: [
                        AppKpiRow(tiles: [
                          KpiTile(
                            label: 'Total receivable',
                            value: _fmt(totalReceivable),
                            sub:
                                'From $dueCount customer${dueCount == 1 ? '' : 's'}',
                            icon: Icons.account_balance_wallet_rounded,
                            tint: ac.expenseTint,
                            iconColor: ac.expenseFg,
                          ),
                          KpiTile(
                            label: 'Collected today',
                            value: _fmt(collectedToday),
                            sub:
                                '${todayPayments.length} payment${todayPayments.length == 1 ? '' : 's'}',
                            icon: Icons.savings_rounded,
                            tint: ac.saleTint,
                            iconColor: ac.saleFg,
                          ),
                        ]),
                        const SizedBox(height: 14),
                        AppSearchField(
                          controller: _searchCtrl,
                          hintText: 'Search customers\u2026',
                          onChanged: (v) =>
                              setState(() => _query = v.toLowerCase()),
                        ),
                        const SectionLabel(title: 'Customer ledger'),
                        for (final item in filtered)
                          _buildRow(item, cs, ac, csym),
                      ],
                    ),
        ),
      ]),
    );
  }

  Widget _buildRow(_CustBal item, ColorScheme cs, AppColors ac, String csym) {
    final fmt = NumberFormat('#,##0');
    final due = item.balance > 0;
    String sub;
    if (item.lastActivity == DateTime(0)) {
      sub = item.customer.phone.isNotEmpty
          ? item.customer.phone
          : 'Fully settled';
    } else {
      final days = DateTime.now().difference(item.lastActivity).inDays;
      final ago =
          days <= 0 ? 'today' : (days == 1 ? 'yesterday' : '$days days ago');
      final isPayment = item.lastPayment != null &&
          (item.lastSale == null || item.lastPayment!.isAfter(item.lastSale!));
      sub = isPayment ? 'Last payment $ago' : 'Last sale $ago';
    }
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      radius: 18,
      level: AppGlassLevel.raised,
      gloss: false,
      tint: due ? ac.expenseFg.withValues(alpha: 0.06) : null,
      onTap: () => Navigator.push(
          context, slideUpRoute(_CustDetail(customer: item.customer))),
      child: Row(
        children: [
          InitialAvatar(
            name: item.customer.name,
            size: 42,
            borderRadius: 13,
            fontSize: 14,
            backgroundColor: due ? ac.expenseTint : ac.saleTint,
            foregroundColor: due ? ac.expenseFg : ac.saleFg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.customer.name,
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
                    color: due ? ac.expenseFg : ac.saleFg)),
            Text(due ? 'Due' : 'Clear',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: ac.inkFaint)),
          ]),
        ],
      ),
    );
  }
}

class _CustBal {
  final Customer customer;
  final double balance;
  final DateTime lastActivity;
  final DateTime? lastSale;
  final DateTime? lastPayment;
  const _CustBal({
    required this.customer,
    required this.balance,
    required this.lastActivity,
    this.lastSale,
    this.lastPayment,
  });
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

    return salesAsync.when(
      data: (sales) => paymentsAsync.when(
        data: (payments) {
          final cSales = sales.where(
              (s) => s.customerId == customer.id && !s.isVoided && !s.isQuote);
          final cPayments = payments.where((p) => p.customerId == customer.id);
          final total = cSales.fold(0.0, (s, x) => s + x.amount);
          final paid = cSales.fold(0.0, (s, x) => s + x.paid);
          final recv = cPayments.fold(0.0, (s, x) => s + x.amountCollected);
          final balance = (total - paid - recv).clamp(0, double.infinity);

          final txns = <_Txn>[
            ...cSales.map((s) {
              final items = s.lineItems
                  .map((li) => li.name ?? li.productId)
                  .where((n) => n.isNotEmpty)
                  .toList();
              final itemNames = items.length <= 2
                  ? items.join(', ')
                  : '${items.first} (+${items.length - 1} items)';
              return _Txn(
                date: s.date,
                title: 'Sale invoice',
                sub: itemNames.isEmpty
                    ? DateFormat('d MMM, h:mm a').format(s.date)
                    : '${DateFormat('d MMM, h:mm a').format(s.date)} \u00b7 $itemNames',
                isSale: true,
                amount: s.amount,
              );
            }),
            ...cPayments.map((p) => _Txn(
                  date: p.date,
                  title: 'Payment received',
                  sub:
                      '${DateFormat('d MMM, h:mm a').format(p.date)} \u00b7 cash',
                  isSale: false,
                  amount: p.amountCollected,
                )),
          ];
          txns.sort((a, b) => b.date.compareTo(a.date));

          final fmt = NumberFormat('#,##0');

          return FullScreenOverlay(
            title: customer.name,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              HeroCard(
                eyebrow: 'Balance due',
                amount: '$csym ${fmt.format(balance.toInt())}',
                pills: [
                  HeroPill(
                      label: 'Total billed',
                      value: '$csym ${fmt.format(total.toInt())}'),
                  HeroPill(
                      label: 'Paid',
                      value: '$csym ${fmt.format((paid + recv).toInt())}'),
                ],
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: 'Record Payment',
                    icon: Icons.credit_card_rounded,
                    onTap: balance > 0
                        ? () => _collectPayment(context, ref, customer,
                            currentBalance: balance.toDouble())
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: '',
                  icon: Icons.call_rounded,
                  variant: AppButtonVariant.outline,
                  fullWidth: false,
                  onTap: customer.phone.isNotEmpty
                      ? () => showAppToast(context, customer.phone)
                      : null,
                ),
              ]),
              const SectionLabel(title: 'Transaction history'),
              if (txns.isEmpty)
                FoamCard(
                  foam: true,
                  child: EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No transactions',
                    subtitle:
                        'Sales and payments for this customer will appear here',
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
                              color:
                                  txns[i].isSale ? ac.saleTint : ac.khataTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              txns[i].isSale
                                  ? Icons.receipt_long_rounded
                                  : Icons.savings_rounded,
                              size: 17,
                              color: txns[i].isSale ? ac.saleFg : ac.khataFg,
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
                                  Text(txns[i].sub,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 10.5, color: ac.inkFaint)),
                                ]),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${txns[i].isSale ? '+' : '\u2212'}$csym ${fmt.format(txns[i].amount.toInt())}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: txns[i].isSale ? ac.expenseFg : ac.saleFg,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                  sanitizeErrorMessage(e, fallback: 'Could not load data'),
                  style: TextStyle(color: cs.onSurface))),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
                sanitizeErrorMessage(e, fallback: 'Could not load data'),
                style: TextStyle(color: cs.onSurface))),
      ),
    );
  }
}

void _collectPayment(BuildContext context, WidgetRef ref, Customer customer,
    {double currentBalance = 0}) {
  final csym = ref.read(currencySymbolProvider);
  final fmt = NumberFormat('#,##0');
  final ctrl = TextEditingController(
      text: currentBalance > 0 ? currentBalance.toStringAsFixed(0) : '');

  showAppSheet(
    context: context,
    builder: (ctx) => AppSheetContent(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Collect from ${customer.name}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 2),
        Text('Outstanding: $csym ${fmt.format(currentBalance.toInt())}',
            style:
                TextStyle(fontSize: 11, color: AppColors.of(context).inkFaint)),
        const SizedBox(height: 14),
        Text('Amount received ($csym)',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.of(context).inkSoft,
                letterSpacing: 0.03)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 13.5, color: AppColors.of(context).ink),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.of(context).surface2,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.of(context).outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.of(context).outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.of(context).primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
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
              label: 'Record Payment',
              icon: Icons.check_rounded,
              onTap: () {
                final amt = double.tryParse(ctrl.text) ?? 0;
                if (amt <= 0) {
                  showAppToast(context, 'Enter a positive amount');
                  return;
                }
                if (currentBalance > 0 && amt > currentBalance) {
                  showAppToast(
                      context, 'Cannot exceed the outstanding balance');
                  return;
                }
                final s = ref.read(firestoreServiceProvider);
                final payment = Payment(
                    id: s.generateId(),
                    date: DateTime.now(),
                    customerId: customer.id,
                    amountCollected: amt);
                Navigator.pop(ctx);
                s.savePaymentTransaction(payment).then((_) {
                  ref.invalidate(accountingSummaryProvider);
                  if (context.mounted) {
                    final csym2 = ref.read(currencySymbolProvider);
                    SuccessSheet.show(
                      context: context,
                      title: 'Payment Collected',
                      subtitle:
                          '${customer.name} \u00b7 $csym2 ${fmt.format(amt.toInt())}',
                      primaryLabel: 'Done',
                    );
                  }
                }).catchError((e, st) {
                  logSecureError(e, st, tag: 'payment');
                });
              },
            ),
          ),
        ]),
      ]),
    ),
  ).then((_) => ctrl.dispose());
}

class _Txn {
  final DateTime date;
  final String title;
  final String sub;
  final bool isSale;
  final double amount;
  const _Txn({
    required this.date,
    required this.title,
    required this.sub,
    required this.isSale,
    required this.amount,
  });
}
