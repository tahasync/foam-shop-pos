import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system/design_system.dart';

/// Notification history. The app fires on-device local notifications only and
/// does not persist a log, so this view surfaces the CURRENT active alert
/// conditions computed live from the real data (low-stock products and
/// overdue-baqaya customers). Nothing here is invented.
class NotificationHistoryScreen extends ConsumerWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);
    final csym = ref.watch(currencySymbolProvider);
    final products = ref.watch(productsStreamProvider).asData?.value ?? [];
    final sales = ref.watch(salesStreamProvider).asData?.value ?? [];
    final payments = ref.watch(paymentsStreamProvider).asData?.value ?? [];
    final customers = ref.watch(customersStreamProvider).asData?.value ?? [];
    final customerMap = {for (final c in customers) c.id: c};

    final lowStock = products.where((p) => p.isLowStock).toList();

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final overdue = <({String name, double balance, int days})>[];
    final overdueIds = <String>{
      for (final s in sales)
        if (!s.isVoided && !s.isQuote && s.customerId.isNotEmpty) s.customerId,
      for (final p in payments)
        if (p.customerId.isNotEmpty) p.customerId,
    };
    for (final cid in overdueIds) {
      final cSales =
          sales.where((s) => s.customerId == cid && !s.isVoided && !s.isQuote);
      final cPayments = payments.where((p) => p.customerId == cid);
      final total = cSales.fold(0.0, (s, x) => s + x.amount);
      final paid = cSales.fold(0.0, (s, x) => s + x.paid);
      final recv = cPayments.fold(0.0, (s, x) => s + x.amountCollected);
      final bal = total - paid - recv;
      final lastActivity = cSales.fold<DateTime?>(null,
          (prev, s) => prev == null || s.date.isAfter(prev) ? s.date : prev);
      if (bal > 0 &&
          lastActivity != null &&
          lastActivity.isBefore(thirtyDaysAgo)) {
        final name = customerMap[cid]?.name ??
            (cSales.isNotEmpty
                ? cSales.first.customerName ?? 'Customer'
                : 'Customer');
        final days = DateTime.now().difference(lastActivity).inDays;
        overdue.add((name: name, balance: bal, days: days));
      }
    }
    overdue.sort((a, b) => b.days.compareTo(a.days));

    final isEmpty = lowStock.isEmpty && overdue.isEmpty;

    return FullScreenOverlay(
      title: 'Notifications',
      child: isEmpty
          ? EmptyState(
              icon: Icons.check_circle_rounded,
              title: 'No alerts yet',
              subtitle: 'You\u2019re all clear \u2014 nothing needs attention',
              celebrate: true,
            )
          : FoamCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  for (final p in lowStock)
                    _NotifRow(
                      icon: Icons.warning_amber_rounded,
                      tint: ac.purchaseTint,
                      fg: ac.purchaseFg,
                      title: 'Low stock: ${p.name}',
                      subtitle: '${p.currentStock.toInt()} ${p.unitLabel} left',
                    ),
                  for (final o in overdue)
                    _NotifRow(
                      icon: Icons.schedule_rounded,
                      tint: ac.expenseTint,
                      fg: ac.expenseFg,
                      title: 'Overdue baqaya: ${o.name}',
                      subtitle:
                          '$csym ${o.balance.toInt()} \u00b7 ${o.days} days overdue',
                    ),
                ],
              ),
            ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final Color fg;
  final String title;
  final String subtitle;

  const _NotifRow({
    required this.icon,
    required this.tint,
    required this.fg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
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
                      color: ac.ink)),
              const SizedBox(height: 1),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: ac.inkFaint)),
            ]),
          ),
        ],
      ),
    );
  }
}
