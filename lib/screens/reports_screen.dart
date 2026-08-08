import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sale.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/payment.dart';
import '../models/supplier_payment.dart';
import '../models/opening_balance.dart';
import '../services/accounting_service.dart';
import '../providers/sale_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/product_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/supplier_payment_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system/design_system.dart';
import 'export_screen.dart';

enum ReportsPeriod { daily, weekly, monthly, yearly }

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

class _RevenueBucket {
  final String label;
  final DateTime start;
  final DateTime end;
  double amount = 0;
  _RevenueBucket({required this.label, required this.start, required this.end});
}

const _shortDays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
const _monthInitials = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

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
    final salesAsync = ref.watch(salesStreamProvider);
    final purchasesAsync = ref.watch(purchasesStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final supplierPaymentsAsync = ref.watch(supplierPaymentsStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final openingBalAsync = ref.watch(openingBalanceStreamProvider);

    final asyncs = <AsyncValue>[
      salesAsync, purchasesAsync, expensesAsync,
      paymentsAsync, supplierPaymentsAsync, productsAsync, openingBalAsync,
    ];
    if (asyncs.any((a) => a.isLoading)) {
      return const FullScreenOverlay(
        title: 'Reports',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final firstError = asyncs.where((a) => a.hasError).firstOrNull;
    if (firstError != null) {
      return FullScreenOverlay(
        title: 'Reports',
        child: Center(child: Text('Error: ${firstError.error}', style: TextStyle(color: cs.onSurface))),
      );
    }

    return _buildBody(
      context,
      sales: salesAsync.asData!.value,
      purchases: purchasesAsync.asData!.value,
      expenses: expensesAsync.asData!.value,
      payments: paymentsAsync.asData!.value,
      supplierPayments: supplierPaymentsAsync.asData!.value,
      products: productsAsync.asData!.value,
      openingBal: openingBalAsync.asData!.value,
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<Sale> sales,
    required List<Purchase> purchases,
    required List<Expense> expenses,
    required List<Payment> payments,
    required List<SupplierPayment> supplierPayments,
    required List<Product> products,
    required OpeningBalance? openingBal,
  }) {
    final ac = AppColors.of(context);
    final csym = ref.watch(currencySymbolProvider);
    final range = _dateRangeFor(_period);

    // Single source of truth: same AccountingService call the Export screen
    // uses, with ALL streams, so Dashboard/Reports/Export never disagree.
    final summary = AccountingService().recomputeForPeriod(
      sales: sales,
      purchases: purchases,
      expenses: expenses,
      payments: payments,
      supplierPayments: supplierPayments,
      products: products,
      openingBal: openingBal,
      startDate: range.start,
      endDate: range.end,
    );

    String _fmt(double v) => '$csym ${NumberFormat('#,##0').format(v.toInt())}';

    return FullScreenOverlay(
      title: 'Reports',
      actions: [
        AppIconButton(
          icon: Icons.ios_share_rounded,
          onTap: () => pushOverlay(context, const ExportScreen()),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedControl(
          options: const ['Daily', 'Weekly', 'Monthly', 'Yearly'],
          selectedIndex: _period.index,
          onChanged: (i) => setState(() => _period = ReportsPeriod.values[i]),
        ),
        HeroCard(
          eyebrow: 'Period summary \u00b7 ${_periodLabel(_period)}',
          amount: _fmt(summary.netProfit),
          pills: [
            HeroPill(label: 'Revenue', value: _fmt(summary.revenue)),
            HeroPill(label: 'Cash in hand', value: _fmt(summary.cashInHand)),
          ],
        ),
        SectionLabel(title: 'Revenue trend'),
        _buildRevenueChart(context, sales, csym),
        SectionLabel(title: 'Expense breakdown'),
        _buildDonut(context, expenses, range, csym),
        SectionLabel(title: 'Full accounting summary'),
        FoamCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            _summaryRow(context, 'Gross profit', _fmt(summary.grossProfit), valueColor: ac.saleFg),
            const Divider(height: 1),
            _summaryRow(context, 'Opening capital', _fmt(summary.openingCapital)),
            const Divider(height: 1),
            _summaryRow(context, 'Cash from recoveries', _fmt(summary.cashFromRecoveries)),
            const Divider(height: 1),
            _summaryRow(context, 'Paid to suppliers', _fmt(summary.cashPaidToSuppliers), valueColor: ac.purchaseFg),
            const Divider(height: 1),
            _summaryRow(context, 'Products / categories', '${summary.totalProducts} / ${summary.categoryCount}'),
          ]),
        ),
      ]),
    );
  }

  List<_RevenueBucket> _revenueBuckets(ReportsPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = <_RevenueBucket>[];

    switch (period) {
      case ReportsPeriod.daily:
      case ReportsPeriod.weekly:
        for (var i = 6; i >= 0; i--) {
          final day = today.subtract(Duration(days: i));
          buckets.add(_RevenueBucket(
            label: _shortDays[day.weekday - 1],
            start: DateTime(day.year, day.month, day.day),
            end: DateTime(day.year, day.month, day.day, 23, 59, 59, 999),
          ));
        }
        break;
      case ReportsPeriod.monthly:
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        for (var d = 1; d <= daysInMonth; d++) {
          buckets.add(_RevenueBucket(
            label: '$d',
            start: DateTime(now.year, now.month, d),
            end: DateTime(now.year, now.month, d, 23, 59, 59, 999),
          ));
        }
        break;
      case ReportsPeriod.yearly:
        for (var m = 1; m <= 12; m++) {
          buckets.add(_RevenueBucket(
            label: _monthInitials[m - 1],
            start: DateTime(now.year, m, 1),
            end: DateTime(now.year, m + 1, 0, 23, 59, 59, 999),
          ));
        }
        break;
    }
    return buckets;
  }

  Widget _buildRevenueChart(BuildContext context, List<Sale> sales, String csym) {
    final ac = AppColors.of(context);
    final buckets = _revenueBuckets(_period);
    for (final s in sales) {
      if (s.isVoided || s.isQuote) continue;
      for (final b in buckets) {
        if (!s.date.isBefore(b.start) && !s.date.isAfter(b.end)) {
          b.amount += s.amount;
          break;
        }
      }
    }

    if (!buckets.any((b) => b.amount > 0)) {
      return FoamCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'No sales in this period',
          subtitle: 'Daily sales revenue will appear here',
        ),
      );
    }

    final maxV = buckets.map((b) => b.amount).reduce((a, b) => a > b ? a : b);
    final maxY = maxV <= 0 ? 100.0 : maxV * 1.25;
    final isDense = buckets.length > 20;

    return FoamCard(
      padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
      child: SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            barGroups: [
              for (var i = 0; i < buckets.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: buckets[i].amount,
                      gradient: LinearGradient(colors: [ac.primary, ac.primaryStrong]),
                      width: isDense ? 8 : 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
            ],
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: isDense ? 2 : 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      child: Text(
                        buckets[i].label,
                        style: TextStyle(
                          fontSize: isDense ? 8 : 9,
                          fontWeight: FontWeight.w700,
                          color: ac.inkFaint,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final i = group.x.toInt();
                  if (i < 0 || i >= buckets.length) return null;
                  return BarTooltipItem(
                    '${buckets[i].label}\n$csym ${NumberFormat('#,##0').format(rod.toY.toInt())}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonut(BuildContext context, List<Expense> expenses, DateTimeRange range, String csym) {
    final ac = AppColors.of(context);
    final endOfDay = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
    final inRange = expenses
        .where((e) => !e.date.isBefore(range.start) && !e.date.isAfter(endOfDay))
        .toList();

    if (inRange.isEmpty) {
      return FoamCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          icon: Icons.pie_chart_outline_rounded,
          title: 'No expenses in this period',
          subtitle: 'Expense breakdown will appear here',
        ),
      );
    }

    final totals = <String, double>{};
    for (final e in inRange) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    final palette = <Color>[
      ac.primary,
      ac.accent,
      ac.expenseFg,
      ac.inventoryFg,
      ac.saleFg,
      ac.purchaseFg,
      ac.khataFg,
    ];

    return FoamCard(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      child: Column(children: [
        SizedBox(
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 46,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value,
                        color: palette[i % palette.length],
                        radius: 30,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$csym ${NumberFormat.compact().format(total)}',
                    style: AppTheme.display(context, size: 17)),
                const SizedBox(height: 1),
                Text('TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ac.inkFaint)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            for (var i = 0; i < entries.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: palette[i % palette.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${entries[i].key} ${_pct(entries[i].value, total)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ac.inkSoft),
                ),
              ]),
          ],
        ),
      ]),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value, {Color? valueColor}) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ac.inkSoft)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? ac.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

String _pct(double v, double total) => total <= 0 ? '0%' : '${((v / total) * 100).round()}%';
