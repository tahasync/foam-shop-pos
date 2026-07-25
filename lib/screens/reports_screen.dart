import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../providers/sale_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/product_provider.dart';
import '../providers/shop_provider.dart';
import '../utils/currency.dart';
import '../theme/app_theme.dart';

enum ReportsPeriod { daily, weekly, monthly, yearly }

class _PeriodReport {
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final int salesCount;
  final double avgSaleValue;

  _PeriodReport({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.salesCount,
    required this.avgSaleValue,
  });
}

_PeriodReport _computeReport(
  List<Sale> sales,
  List<Expense> expenses,
  List<Product> products,
  DateTimeRange range,
) {
  final productMap = {for (final p in products) p.id: p};
  final endOfDay = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);

  double revenue = 0;
  double cogs = 0;
  int salesCount = 0;

  for (final sale in sales) {
    if (sale.isVoided || sale.isQuote) continue;
    if (sale.date.isBefore(range.start) || sale.date.isAfter(endOfDay)) continue;
    revenue += sale.amount;
    salesCount++;
    for (final li in sale.lineItems) {
      final product = productMap[li.productId];
      if (product != null) {
        cogs += li.qtyOrArea * product.costPrice;
      }
    }
  }

  final periodExpenses = expenses
      .where((e) => !e.date.isBefore(range.start) && !e.date.isAfter(endOfDay))
      .fold(0.0, (s, e) => s + e.amount);

  final grossProfit = revenue - cogs;
  final netProfit = grossProfit - periodExpenses;
  final avgSaleValue = salesCount > 0 ? revenue / salesCount : 0.0;

  return _PeriodReport(
    revenue: revenue,
    cogs: cogs,
    grossProfit: grossProfit,
    expenses: periodExpenses,
    netProfit: netProfit,
    salesCount: salesCount,
    avgSaleValue: avgSaleValue,
  );
}

DateTimeRange _dateRangeFor(ReportsPeriod period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final eod = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  switch (period) {
    case ReportsPeriod.daily:
      return DateTimeRange(start: today, end: eod);
    case ReportsPeriod.weekly:
      return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: eod);
    case ReportsPeriod.monthly:
      final first = DateTime(now.year, now.month, 1);
      final last = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
      return DateTimeRange(start: first, end: last);
    case ReportsPeriod.yearly:
      return DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year, 12, 31, 23, 59, 59, 999),
      );
  }
}

String _periodLabel(ReportsPeriod period) {
  switch (period) {
    case ReportsPeriod.daily: return 'Today';
    case ReportsPeriod.weekly: return 'This Week';
    case ReportsPeriod.monthly: return 'This Month';
    case ReportsPeriod.yearly: return 'This Year';
  }
}

String _format(double v, {String csym = 'Rs'}) => '$csym ${v.toStringAsFixed(0)}';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportsPeriod _period = ReportsPeriod.daily;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);

    final salesAsync = ref.watch(salesStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.onSurface))),
        data: (sales) => expensesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.onSurface))),
          data: (expenses) => productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.onSurface))),
            data: (products) => _buildBody(context, cs, ac, sales, expenses, products),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme cs, AppColors ac,
      List<Sale> sales, List<Expense> expenses, List<Product> products) {
    final range = _dateRangeFor(_period);
    final report = _computeReport(sales, expenses, products, range);
    final csym = ref.read(shopProfileProvider).asData?.value != null
        ? currencySymbolFromCode(ref.read(shopProfileProvider).asData!.value!.currency)
        : 'Rs';
    String _fmtLocal(double v) => _format(v, csym: csym);

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ReportsPeriod>(
              segments: const [
                ButtonSegment(value: ReportsPeriod.daily, label: Text('Daily')),
                ButtonSegment(value: ReportsPeriod.weekly, label: Text('Weekly')),
                ButtonSegment(value: ReportsPeriod.monthly, label: Text('Monthly')),
                ButtonSegment(value: ReportsPeriod.yearly, label: Text('Yearly')),
              ],
              selected: {_period},
              onSelectionChanged: (v) => setState(() => _period = v.first),
              style: SegmentedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: ac.saleTint, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: AppTheme.sage, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  _periodLabel(_period),
                  style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: ac.saleFg,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (report.salesCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('No data for this period', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.teal, AppTheme.tealDark]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.teal.withValues(alpha: 0.35),
                        blurRadius: 24, offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Period Summary', style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.06,
                      color: Colors.white.withValues(alpha: 0.85),
                    )),
                    const SizedBox(height: 8),
                    Row(children: [
                      _heroStat('Revenue', _fmtLocal(report.revenue)),
                      const SizedBox(width: 16),
                      _heroStat('Net Profit', _fmtLocal(report.netProfit)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      _heroStat('Sales', '${report.salesCount}'),
                      const SizedBox(width: 16),
                      _heroStat('Avg Sale', _fmtLocal(report.avgSaleValue)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _statCard(context, 'Revenue', _fmtLocal(report.revenue),
                        'Gross: ${_fmtLocal(report.grossProfit)}', Icons.trending_up_rounded, ac.saleTint, ac.saleFg),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(context, 'COGS', _fmtLocal(report.cogs),
                        'Cost of goods sold', Icons.inventory_2_rounded, ac.purchaseTint, ac.purchaseFg),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _statCard(context, 'Gross Profit', _fmtLocal(report.grossProfit),
                        'Revenue \u2212 COGS', Icons.account_balance_rounded, ac.profitTint, ac.profitFg),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(context, 'Expenses', _fmtLocal(report.expenses),
                        'Total kharcha', Icons.trending_down_rounded, ac.expenseTint, ac.expenseFg),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _statCard(context, 'Net Profit', _fmtLocal(report.netProfit),
                        'Margin: ${report.revenue > 0 ? ((report.netProfit / report.revenue) * 100).toStringAsFixed(0) : 0}%',
                        Icons.trending_up_rounded, ac.profitTint, ac.profitFg),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(context, 'Avg Sale', _fmtLocal(report.avgSaleValue),
                        '${report.salesCount} sales', Icons.sell_rounded, ac.saleTint, ac.saleFg),
                  ),
                ]),
              ],
            ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9))),
      const SizedBox(height: 1),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
          fontFeatures: [FontFeature('tnum')], color: Colors.white)),
    ]));
  }

  Widget _statCard(BuildContext context, String title, String value, String sub,
      IconData icon, Color tint, Color iconColor) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [BoxShadow(color: cs.shadow, blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -4)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature('tnum')], color: cs.onSurface)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 10, color: ac.inkFaint)),
      ]),
    );
  }
}
