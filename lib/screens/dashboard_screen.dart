import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/accounting_service.dart' show AccountingSummary;
import '../providers/dashboard_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/product_provider.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../widgets/design_system/design_system.dart';
import 'account_settings_screen.dart';
import 'billing_screen.dart';
import 'expense_sheet_screen.dart';
import 'notification_settings_screen.dart';
import 'reports_screen.dart';

class DashboardScreen extends ConsumerWidget {
  final VoidCallback? onLowStockTap;
  final VoidCallback? onNewSale;

  /// Bottom space reserved for the floating nav pill. Supplied by
  /// `HomeScreen.contentBottomInset` so every tab agrees.
  final double bottomInset;

  const DashboardScreen({
    super.key,
    this.onLowStockTap,
    this.onNewSale,
    this.bottomInset = 120,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final as = ref.watch(accountingSummaryProvider);
    final bottom = bottomInset;

    return GlassScaffold(
      safeBottom: false,
      child: as.when(
        // The hero card (and the whole dashboard chrome) renders
        // unconditionally — even while the accounting summary is still
        // resolving we show the layout with a zeroed summary, so a fresh
        // all-zero account always sees "Cash in hand: Rs 0" directly under
        // the header, exactly like the KPI tiles below it.
        loading: () => _buildDashboard(context, ref, _zeroSummary(), bottom, isLoading: true),
        error: (e, _) => _buildDashboard(context, ref, _zeroSummary(), bottom, errorMessage: 'Could not load dashboard'),
        data: (d) => _buildDashboard(context, ref, d, bottom),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, AccountingSummary d, double bottom,
      {bool isLoading = false, String? errorMessage}) {
    final ac = AppColors.of(context);
    final csym = ref.watch(currencySymbolProvider);
    final shopAsync = ref.watch(shopProfileProvider);
    final profile = shopAsync.asData?.value;
    final products = ref.watch(productsStreamProvider).asData?.value ?? [];
    final customers = ref.watch(customersStreamProvider).asData?.value ?? [];
    final suppliers = ref.watch(suppliersStreamProvider).asData?.value ?? [];
    final sales = ref.watch(salesStreamProvider).asData?.value ?? [];
    final purchases = ref.watch(purchasesStreamProvider).asData?.value ?? [];
    final expenses = ref.watch(expensesStreamProvider).asData?.value ?? [];
    final payments = ref.watch(paymentsStreamProvider).asData?.value ?? [];

          String _fmt(double v) => '$csym ${NumberFormat('#,##0').format(v.toInt())}';

          final productMap = {for (final p in products) p.id: p};
          final customerMap = {for (final c in customers) c.id: c};
          final supplierMap = {for (final s in suppliers) s.id: s};
          final dateFmt = DateFormat('d MMM, h:mm a');
          final timeFmt = NumberFormat('#,##0');

          final activities = <_Activity>[
            for (final s in sales)
              if (!s.isVoided && !s.isQuote)
                _Activity(
                  date: s.date,
                  icon: Icons.receipt_long_rounded,
                  tint: ac.saleTint,
                  iconColor: ac.saleFg,
                  title: 'Sale \u00b7 ${(s.customerName?.isNotEmpty ?? false) ? s.customerName! : 'Walk-in'}',
                  sub: dateFmt.format(s.date),
                  amount: '+${timeFmt.format(s.amount.toInt())}',
                  amountColor: ac.saleFg,
                ),
            for (final p in purchases)
              _Activity(
                date: p.date,
                icon: Icons.inventory_2_rounded,
                tint: ac.purchaseTint,
                iconColor: ac.purchaseFg,
                title: 'Restock \u00b7 ${productMap[p.productId]?.name ?? 'product'}',
                sub: p.supplierId.isNotEmpty
                    ? '${supplierMap[p.supplierId]?.name ?? 'Supplier'} \u00b7 ${dateFmt.format(p.date)}'
                    : dateFmt.format(p.date),
                amount: timeFmt.format(p.costAmount.toInt()),
                amountColor: ac.ink,
              ),
            for (final e in expenses)
              _Activity(
                date: e.date,
                icon: Icons.receipt_rounded,
                tint: ac.expenseTint,
                iconColor: ac.expenseFg,
                title: 'Expense \u00b7 ${e.category}',
                sub: dateFmt.format(e.date),
                amount: '\u2212${timeFmt.format(e.amount.toInt())}',
                amountColor: ac.expenseFg,
              ),
            for (final pay in payments)
              _Activity(
                date: pay.date,
                icon: Icons.savings_rounded,
                tint: ac.khataTint,
                iconColor: ac.khataFg,
                title: 'Payment \u00b7 ${customerMap[pay.customerId]?.name ?? 'customer'}',
                sub: dateFmt.format(pay.date),
                amount: '+${timeFmt.format(pay.amountCollected.toInt())}',
                amountColor: ac.khataFg,
              ),
          ]..sort((a, b) => b.date.compareTo(a.date));
          final recent = activities.take(5).toList();

          final saleCount =
              sales.where((s) => !s.isVoided && !s.isQuote).length;

          final today = DateTime.now();
          final dateStr = DateFormat('EEE, d MMM').format(today);
          final location = profile?.location ?? '';
          final subLabel =
              location.trim().isEmpty ? dateStr : '$dateStr \u00b7 $location';
          final shopName = profile?.shopName ?? 'Digital Register';

          return Column(
              children: [
                AppBarRow(
                  title: shopName,
                  subtitle: subLabel,
                  trailing: [
                    AppIconButton(
                      icon: Icons.notifications_none_rounded,
                        semanticLabel: 'Notification settings',
                      onTap: () => _push(context, const NotificationSettingsScreen()),
                      badge: d.lowStockCount > 0
                          ? Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: ac.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    AppIconButton(
                        semanticLabel: 'Account settings',
                      icon: Icons.person_rounded,
                      background: ac.primaryContainer,
                      foreground: ac.onPrimaryContainer,
                      onTap: () => _push(context, const AccountSettingsScreen()),
                    ),
                  ],
                ),
                if (isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                    child: Text(errorMessage,
                        style: TextStyle(fontSize: 12, color: ac.expenseFg)),
                  ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, bottom),
                    children: [
                      HeroCard(
                        eyebrow: 'Cash in hand',
                        amount: _fmt(d.cashInHand),
                        pills: [
                          HeroPill(label: 'Revenue', value: _fmt(d.revenue)),
                          HeroPill(label: 'Net profit', value: _fmt(d.netProfit)),
                          HeroPill(label: 'Baqaya', value: _fmt(d.totalCustomerBaqaya)),
                        ],
                      ),
                      if (d.lowStockCount > 0)
                        AlertBanner(
                          icon: Icons.warning_amber_rounded,
                          title: '${d.lowStockCount} ${d.lowStockCount == 1 ? 'item' : 'items'} low on stock',
                          subtitle: 'Reorder soon',
                          onTap: onLowStockTap,
                        ),
                      SectionLabel(title: 'Cash & accounting'),
                      AccountingStrip(items: [
                        AccountingChipData(
                            label: 'Cash in hand',
                            value: _fmt(d.cashInHand),
                            valueColor: ac.cashFg),
                        AccountingChipData(label: 'Opening capital', value: _fmt(d.openingCapital)),
                        AccountingChipData(
                            label: 'Customer baqaya',
                            value: _fmt(d.totalCustomerBaqaya),
                            valueColor: ac.expenseFg),
                        AccountingChipData(
                            label: 'Supplier baqaya',
                            value: _fmt(d.totalSupplierBaqaya),
                            valueColor: ac.purchaseFg),
                      ]),
                      SectionLabel(title: 'Business snapshot'),
                      // AppKpiRow forces both tiles to one height. The previous
                      // `Row(crossAxisAlignment: start)` let them size
                      // independently, which is what made this grid look
                      // misaligned whenever one label wrapped to two lines.
                      AppKpiRow(tiles: [
                        KpiTile(
                          label: 'Revenue',
                          value: _fmt(d.revenue),
                          sub: '$saleCount ${saleCount == 1 ? 'sale' : 'sales'}',
                          icon: Icons.trending_up_rounded,
                          tint: ac.saleTint,
                          iconColor: ac.saleFg,
                        ),
                        KpiTile(
                          label: 'COGS',
                          value: _fmt(d.cogs),
                          sub: 'Cost of goods sold',
                          icon: Icons.receipt_rounded,
                          tint: ac.purchaseTint,
                          iconColor: ac.purchaseFg,
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.md),
                      AppKpiRow(tiles: [
                        KpiTile(
                          label: 'Gross Profit',
                          value: _fmt(d.grossProfit),
                          sub: 'Revenue \u2212 COGS',
                          icon: Icons.account_balance_rounded,
                          tint: ac.profitTint,
                          iconColor: ac.profitFg,
                        ),
                        KpiTile(
                          label: 'Expenses',
                          value: _fmt(d.totalExpenses),
                          sub: '${expenses.length} record${expenses.length == 1 ? '' : 's'}',
                          icon: Icons.trending_down_rounded,
                          tint: ac.expenseTint,
                          iconColor: ac.expenseFg,
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.md),
                      KpiTile(
                        label: 'Inventory value on hand',
                        value: _fmt(d.inventoryValue),
                        sub: '${d.totalProducts} product${d.totalProducts == 1 ? '' : 's'}',
                        icon: Icons.inventory_2_rounded,
                        tint: ac.inventoryTint,
                        iconColor: ac.inventoryFg,
                      ),
                      SectionLabel(title: 'Quick actions'),
                      Row(children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.add_rounded,
                            label: 'New Sale',
                            onTap: onNewSale,
                          ),
                        ),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.receipt_rounded,
                            label: 'Expense',
                            onTap: () => _push(context, const ExpenseSheetScreen()),
                          ),
                        ),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.bar_chart_rounded,
                            label: 'Reports',
                            onTap: () => _push(context, const ReportsScreen()),
                          ),
                        ),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.receipt_long_rounded,
                            label: 'Receipts',
                            onTap: () => _push(context, const BillingScreen()),
                          ),
                        ),
                      ]),
                      SectionLabel(title: 'Recent activity'),
                      if (recent.isEmpty)
                        FoamCard(
                          foam: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: EmptyState(
                            icon: Icons.receipt_long_rounded,
                            title: 'No activity yet',
                            subtitle: 'Sales, expenses and payments will appear here',
                            compact: true,
                          ),
                        )
                      else
                        FoamCard(
                          foam: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Column(children: [
                            for (var i = 0; i < recent.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: ac.outline),
                              _ActivityRow(activity: recent[i]),
                            ],
                          ]),
                        ),
                    ],
                  ),
                ),
              ],
            );
  }

  AccountingSummary _zeroSummary() => AccountingSummary(
        revenue: 0,
        cogs: 0,
        grossProfit: 0,
        totalExpenses: 0,
        netProfit: 0,
        cashInHand: 0,
        openingCapital: 0,
        cashFromSales: 0,
        cashFromRecoveries: 0,
        cashPaidForPurchases: 0,
        cashPaidToSuppliers: 0,
        totalCustomerBaqaya: 0,
        totalSupplierBaqaya: 0,
        inventoryValue: 0,
        lowStockCount: 0,
        totalProducts: 0,
        categoryCount: 0,
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _QuickAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return TapScale(
      onTap: onTap,
      child: Column(children: [
        SizedBox(
          width: 52,
          height: 52,
          child: GlassContainer(
            padding: EdgeInsets.zero,
            radius: 16,
            level: AppGlassLevel.raised,
            gloss: false,
            tint: ac.primary.withValues(alpha: 0.18),
            child: Icon(icon, size: 20, color: ac.primary),
          ),
        ),
        const SizedBox(height: 7),
        Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ac.inkSoft)),
      ]),
    );
  }
}

class _Activity {
  final DateTime date;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String sub;
  final String amount;
  final Color amountColor;
  const _Activity({
    required this.date,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.sub,
    required this.amount,
    required this.amountColor,
  });
}

class _ActivityRow extends StatelessWidget {
  final _Activity activity;
  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: activity.tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(activity.icon, size: 17, color: activity.iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(activity.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ac.ink)),
            const SizedBox(height: 1),
            Text(activity.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: ac.inkFaint)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(activity.amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: activity.amountColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
      ]),
    );
  }
}

void _push(BuildContext context, Widget screen) =>
    Navigator.push(context, slideUpRoute(screen));
