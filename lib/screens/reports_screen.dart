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
import '../utils/money.dart';

enum ReportsPeriod { daily, weekly, monthly, yearly }

DateTimeRange _dateRangeFor(ReportsPeriod period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final eod = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  switch (period) {
    case ReportsPeriod.daily:
      return DateTimeRange(start: today, end: eod);
    case ReportsPeriod.weekly:
      return DateTimeRange(
          start: today.subtract(const Duration(days: 6)), end: eod);
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
    case ReportsPeriod.daily:
      return 'Today';
    case ReportsPeriod.weekly:
      return 'This Week';
    case ReportsPeriod.monthly:
      return 'This Month';
    case ReportsPeriod.yearly:
      return 'This Year';
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
const _monthInitials = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

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
      salesAsync,
      purchasesAsync,
      expensesAsync,
      paymentsAsync,
      supplierPaymentsAsync,
      productsAsync,
      openingBalAsync,
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
        child: Center(
            child: Text('Error: ${firstError.error}',
                style: TextStyle(color: cs.onSurface))),
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

    String _fmt(double v) =>
        '$csym ${NumberFormat('#,##0').format(roundMoney(v))}';

    return FullScreenOverlay(
      title: 'Reports',
      actions: [
        AppIconButton(
          icon: Icons.ios_share_rounded,
          semanticLabel: 'Export report',
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
            _summaryRow(context, 'Gross profit', _fmt(summary.grossProfit),
                valueColor: ac.saleFg),
            const Divider(height: 1),
            _summaryRow(
                context, 'Opening capital', _fmt(summary.openingCapital)),
            const Divider(height: 1),
            _summaryRow(context, 'Cash from recoveries',
                _fmt(summary.cashFromRecoveries)),
            const Divider(height: 1),
            _summaryRow(
                context, 'Paid to suppliers', _fmt(summary.cashPaidToSuppliers),
                valueColor: ac.purchaseFg),
            const Divider(height: 1),
            _summaryRow(context, 'Products / categories',
                '${summary.totalProducts} / ${summary.categoryCount}'),
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

  Widget _buildRevenueChart(
      BuildContext context, List<Sale> sales, String csym) {
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
          compact: true,
          icon: Icons.bar_chart_rounded,
          title: 'No sales in this period',
          subtitle: 'Daily sales revenue will appear here',
        ),
      );
    }

    return _RevenueBarChart(buckets: buckets, csym: csym);
  }

  Widget _buildDonut(BuildContext context, List<Expense> expenses,
      DateTimeRange range, String csym) {
    final ac = AppColors.of(context);
    final endOfDay = DateTime(
        range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
    final inRange = expenses
        .where(
            (e) => !e.date.isBefore(range.start) && !e.date.isAfter(endOfDay))
        .toList();

    if (inRange.isEmpty) {
      return FoamCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          compact: true,
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
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
                Text('TOTAL',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: ac.inkFaint)),
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
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ac.inkSoft),
                ),
              ]),
          ],
        ),
      ]),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value,
      {Color? valueColor}) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ac.inkSoft)),
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

String _pct(double v, double total) =>
    total <= 0 ? '0%' : '${((v / total) * 100).round()}%';

/// The revenue trend bar chart.
///
/// The previous implementation rendered bare bars on a blank field: no grid,
/// no value axis, and a fixed 150px box that left a lot of dead space above the
/// data. This version adds the things a chart actually needs to be readable:
///
///  * horizontal gridlines plus a compact left-hand value axis, so a bar's
///    height can be estimated without tapping,
///  * a headroom-aware max so the tallest bar never touches the ceiling,
///  * rounded bars with a subtle top highlight and a muted zero-bar state
///    (an empty period is visibly "no data", not "a broken chart"),
///  * a peak callout naming the best bucket, so the takeaway is available
///    without interaction, and
///  * a summary for screen readers, because a canvas chart is otherwise silent.
class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({required this.buckets, required this.csym});

  final List<_RevenueBucket> buckets;
  final String csym;

  /// Compact money formatting for the axis, e.g. 120K / 1.4M.
  static String _axisLabel(double v) {
    if (v >= 1000000) {
      final m = v / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (v >= 1000) {
      final k = v / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final fmt = NumberFormat('#,##0');

    final values = buckets.map((b) => b.amount).toList();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    // 18% headroom keeps the tallest bar off the ceiling so it reads as data
    // rather than as a clipped edge.
    final maxY = maxV <= 0 ? 100.0 : maxV * 1.18;
    final gridInterval = maxY <= 0 ? 25.0 : maxY / 4;

    final isDense = buckets.length > 20;
    final peakIndex = values.indexOf(maxV);

    return FoamCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Peak callout - the takeaway is readable without any interaction.
          Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  size: AppIconSize.sm, color: ac.saleFg),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Peak ${buckets[peakIndex].label} \u00b7 $csym ${fmt.format(roundMoney(maxV))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ac.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 168,
            child: Semantics(
              label:
                  'Revenue trend chart. ${buckets.length} periods. Highest is ${buckets[peakIndex].label} at $csym ${fmt.format(roundMoney(maxV))}.',
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: buckets[i].amount,
                            width: isDense ? 7 : 14,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadii.xs),
                            ),
                            // A zero bar is drawn as a faint stub so an empty
                            // period reads as "no sales" rather than a gap.
                            color: buckets[i].amount > 0
                                ? ac.saleFg
                                : ac.glassNested,
                            gradient: buckets[i].amount > 0
                                ? LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      ac.saleFg,
                                      ac.saleFg.withValues(alpha: 0.55),
                                    ],
                                  )
                                : null,
                          ),
                        ],
                      ),
                  ],
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: gridInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: ac.glassHairline,
                      strokeWidth: 1,
                      // Dashed grid so it never competes with the bars.
                      dashArray: const [4, 6],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: gridInterval,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            space: 6,
                            child: Text(
                              _axisLabel(value),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: ac.inkFaint,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: isDense ? 2 : 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= buckets.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(
                              buckets[i].label,
                              style: TextStyle(
                                fontSize: isDense ? 8.5 : 9.5,
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
                    // Only respond to a deliberate tap or drag, never to a
                    // stray brush during a scroll.
                    handleBuiltInTouches: true,
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => ac.brandFillDeep,
                      tooltipBorderRadius: BorderRadius.circular(AppRadii.sm),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final i = group.x.toInt();
                        if (i < 0 || i >= buckets.length) return null;
                        return BarTooltipItem(
                          '${buckets[i].label}\n$csym ${fmt.format(roundMoney(rod.toY))}',
                          TextStyle(
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
          ),
        ],
      ),
    );
  }
}
