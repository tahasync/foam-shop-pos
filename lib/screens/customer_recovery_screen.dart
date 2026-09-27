import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../providers/customer_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/firebase_providers.dart';
import '../providers/dashboard_provider.dart';
import '../providers/shop_provider.dart';
import '../services/accounting_service.dart';
import '../theme/app_theme.dart';
import '../utils/safe_error_handler.dart';
import '../widgets/initial_avatar.dart';
import '../widgets/design_system/design_system.dart';

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
    final customersAsync = ref.watch(customersStreamProvider);
    final salesAsync = ref.watch(salesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final csym = ref.watch(currencySymbolProvider);
    final fmt = NumberFormat('#,##0');

    return FullScreenOverlay(
      title: 'Customer Recovery',
      child: customersAsync.when(
        loading: () => const _LoadingBox(),
        error: (e, _) => _ErrorBox(message: sanitizeErrorMessage(e, fallback: 'Could not load data')),
        data: (customers) => salesAsync.when(
          loading: () => const _LoadingBox(),
          error: (e, _) => _ErrorBox(message: sanitizeErrorMessage(e, fallback: 'Could not load data')),
          data: (sales) => paymentsAsync.when(
            loading: () => const _LoadingBox(),
            error: (e, _) => _ErrorBox(message: sanitizeErrorMessage(e, fallback: 'Could not load data')),
            data: (payments) {
              final balList = customers.map((c) {
                final cSales = sales.where((s) => s.customerId == c.id && !s.isVoided && !s.isQuote);
                final cPayments = payments.where((p) => p.customerId == c.id);
                final total = cSales.fold(0.0, (s, x) => s + x.amount);
                final paid = cSales.fold(0.0, (s, x) => s + x.paid);
                final recv = cPayments.fold(0.0, (s, x) => s + x.amountCollected);
                final lastPayment = cPayments.fold<DateTime?>(null, (prev, p) =>
                    prev == null || p.date.isAfter(prev) ? p.date : prev);
                return _RecoBal(
                  customer: c,
                  outstanding: (total - paid - recv).clamp(0, double.infinity),
                  lastPayment: lastPayment,
                );
              }).toList();

              final due = balList.where((b) => b.outstanding > 0).toList();
              final totalOutstanding = due.fold(0.0, (s, b) => s + b.outstanding);
              final filtered = balList
                  .where((b) => _searchQuery.isEmpty || b.customer.name.toLowerCase().contains(_searchQuery))
                  .where((b) => b.outstanding > 0 || _searchQuery.isNotEmpty)
                  .toList();

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AlertBanner(
                  danger: true,
                  icon: Icons.info_outline_rounded,
                  title: '$csym ${fmt.format(totalOutstanding.toInt())} outstanding',
                  subtitle: 'Across ${due.length} customer${due.length == 1 ? '' : 's'} with balances',
                ),
                const SizedBox(height: 14),
                AppSearchField(
                  controller: _searchCtrl,
                  hintText: 'Search customers\u2026',
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
                const SectionLabel(title: 'Needs follow-up'),
                if (filtered.isEmpty)
                  FoamCard(
                    foam: true,
                    child: _searchQuery.isNotEmpty
                        ? NoResults(title: 'No customers match', subtitle: 'Try a different search term')
                        : EmptyState(
                            celebrate: true,
                            compact: true,
                            icon: Icons.check_circle_rounded,
                            title: 'No outstanding baqaya!',
                            subtitle: 'All customers are settled — great work.',
                          ),
                  )
                else
                  for (final item in filtered)
                    _buildRow(context, cs, ac, csym, fmt, item),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    ColorScheme cs,
    AppColors ac,
    String csym,
    NumberFormat fmt,
    _RecoBal item,
  ) {
    String sub;
    final lastPayment = item.lastPayment;
    if (lastPayment != null) {
      final days = DateTime.now().difference(lastPayment).inDays;
      sub = days <= 0
          ? 'Last payment today'
          : (days == 1 ? 'Last payment yesterday' : 'Last payment $days days ago');
    } else if (item.customer.phone.isNotEmpty) {
      sub = item.customer.phone;
    } else {
      sub = 'Due';
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      radius: 18,
      level: AppGlassLevel.raised,
      gloss: false,
      onTap: () => _collectPayment(context, ref, item.customer, item.outstanding),
      child: Row(children: [
          InitialAvatar(
            name: item.customer.name,
            size: 42,
            borderRadius: 13,
            fontSize: 14,
            backgroundColor: ac.expenseTint,
            foregroundColor: ac.expenseFg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: cs.onSurface)),
              const SizedBox(height: 1),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: ac.inkFaint)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$csym ${fmt.format(item.outstanding.toInt())}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: ac.expenseFg)),
            Text('Collect', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ac.inkFaint)),
          ]),
        ],
      ),
    );
  }

  void _collectPayment(BuildContext context, WidgetRef ref, Customer customer, double outstanding) {
    final csym = ref.read(currencySymbolProvider);
    final fmt = NumberFormat('#,##0');
    final ctrl = TextEditingController(text: outstanding.toStringAsFixed(0));

    showAppSheet(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Collect from ${customer.name}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text('Outstanding: $csym ${fmt.format(outstanding.toInt())}',
              style: TextStyle(fontSize: 11, color: AppColors.of(context).inkFaint)),
          const SizedBox(height: 14),
          AppField(
            label: 'Amount received ($csym)',
            controller: ctrl,
            keyboardType: TextInputType.number,
          ),
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
                label: 'Record Payment',
                icon: Icons.check_rounded,
                onTap: () {
                  final amt = double.tryParse(ctrl.text) ?? 0;
                  final err = AccountingService().validatePayment(amt, outstanding);
                  if (err != null) {
                    showAppToast(ctx, err);
                    return;
                  }
                  final s = ref.read(firestoreServiceProvider);
                  final payment = Payment(
                      id: s.generateId(), date: DateTime.now(), customerId: customer.id, amountCollected: amt);
                  Navigator.pop(ctx);
                  s.savePaymentTransaction(payment).then((_) {
                    ref.invalidate(accountingSummaryProvider);
                    if (context.mounted) {
                      final csym2 = ref.read(currencySymbolProvider);
                      SuccessSheet.show(
                        context: context,
                        title: 'Payment Collected',
                        subtitle: '${customer.name} \u00b7 $csym2 ${fmt.format(amt.toInt())}',
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
}

class _RecoBal {
  final Customer customer;
  final double outstanding;
  final DateTime? lastPayment;
  const _RecoBal({required this.customer, required this.outstanding, this.lastPayment});
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
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
        child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      ),
    );
  }
}
