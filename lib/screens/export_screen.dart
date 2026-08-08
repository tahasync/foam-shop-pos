import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
import '../providers/export_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/shop_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../widgets/design_system/design_system.dart';

enum ExportPeriod { daily, weekly, monthly, custom }

DateTimeRange _dateRange(ExportPeriod p, {DateTime? customStart, DateTime? customEnd}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  switch (p) {
    case ExportPeriod.daily:
      return DateTimeRange(start: today, end: endOfDay);
    case ExportPeriod.weekly:
      return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: endOfDay);
    case ExportPeriod.monthly:
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
      );
    case ExportPeriod.custom:
      final cs = customStart ?? today;
      final ce = customEnd ?? today;
      return DateTimeRange(
        start: cs,
        end: DateTime(ce.year, ce.month, ce.day, 23, 59, 59, 999),
      );
  }
}

String _periodLabel(ExportPeriod p) {
  switch (p) {
    case ExportPeriod.daily: return 'Today';
    case ExportPeriod.weekly: return 'This Week';
    case ExportPeriod.monthly: return 'This Month';
    case ExportPeriod.custom: return 'Custom Range';
  }
}

String _fmt(double v, {String csym = 'Rs'}) => '$csym ${NumberFormat('#,##0').format(v)}';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});
  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportPeriod _period = ExportPeriod.daily;
  String _selectedFormat = 'pdf';
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _loading = false;
  String? _error;

  DateTimeRange get _range => _dateRange(_period,
      customStart: _customStart, customEnd: _customEnd);

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  Future<void> _export(String type) async {
    setState(() { _loading = true; _error = null; });

    try {
      final allSales = ref.read(salesStreamProvider).asData?.value ?? [];
      final products = ref.read(productsStreamProvider).asData?.value ?? [];
      final expenses = ref.read(expensesStreamProvider).asData?.value ?? [];
      final range = _range;
      final sales = allSales.where((s) =>
          !s.isVoided && !s.isQuote &&
          !s.date.isBefore(range.start) && !s.date.isAfter(range.end)).toList();

      final purchases = ref.read(purchasesStreamProvider).asData?.value ?? [];
      final payments = ref.read(paymentsStreamProvider).asData?.value ?? [];
      final supplierPayments = ref.read(supplierPaymentsStreamProvider).asData?.value ?? [];
      final openingBal = ref.read(openingBalanceStreamProvider).asData?.value;
      final profile = ref.read(shopProfileProvider).asData?.value;
      final shopName = profile?.shopName ?? 'Digital Register';
      final currencyCode = profile?.currency ?? 'PKR';

      final service = ref.read(exportServiceProvider);
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

      if (type == 'xlsx') {
        final xlsxFile = await service.generateXlsxReport(
          sales: sales,
          products: products,
          summary: summary,
          startDate: range.start,
          endDate: range.end,
          shopName: shopName,
          currencyCode: currencyCode,
        );
        if (!mounted) return;
        setState(() => _loading = false);
        await SharePlus.instance.share(ShareParams(files: [XFile(xlsxFile.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')], text: 'Sales Report - $shopName'));
      } else if (type == 'pdf') {
        final pdfFile = await service.generatePdfReport(
          sales: sales,
          products: products,
          summary: summary,
          startDate: range.start,
          endDate: range.end,
          shopName: shopName,
          currencyCode: currencyCode,
        );
        if (!mounted) return;
        setState(() => _loading = false);
        await SharePlus.instance.share(ShareParams(files: [XFile(pdfFile.path, mimeType: 'application/pdf')], text: 'Sales Report - $shopName'));
      } else {
        final csvFile = await service.generateCsvReport(
          sales: sales,
          products: products,
          summary: summary,
          startDate: range.start,
          endDate: range.end,
          shopName: shopName,
        );
        if (!mounted) return;
        setState(() => _loading = false);
        await SharePlus.instance.share(ShareParams(files: [XFile(csvFile.path, mimeType: 'application/octet-stream')], text: 'Sales Report - $shopName'));
      }
    } catch (e, st) {
      if (!mounted) return;
      print('[Export Error] $e\n$st');
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final salesAsync = ref.watch(salesStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final purchasesAsync = ref.watch(purchasesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final supplierPaymentsAsync = ref.watch(supplierPaymentsStreamProvider);
    final openingBalAsync = ref.watch(openingBalanceStreamProvider);

    final asyncs = <AsyncValue>[
      salesAsync, productsAsync, expensesAsync,
      purchasesAsync, paymentsAsync, supplierPaymentsAsync, openingBalAsync,
    ];
    if (asyncs.any((a) => a.isLoading)) {
      return const FullScreenOverlay(
        title: 'Export Reports',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final firstError = asyncs.where((a) => a.hasError).firstOrNull;
    if (firstError != null) {
      return FullScreenOverlay(
        title: 'Export Reports',
        child: Center(child: Text('Error: ${firstError.error}', style: TextStyle(color: cs.onSurface))),
      );
    }

    return _buildBody(
      context,
      sales: salesAsync.asData!.value,
      products: productsAsync.asData!.value,
      expenses: expensesAsync.asData!.value,
      purchases: purchasesAsync.asData!.value,
      payments: paymentsAsync.asData!.value,
      supplierPayments: supplierPaymentsAsync.asData!.value,
      openingBal: openingBalAsync.asData!.value,
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<Sale> sales,
    required List<Product> products,
    required List<Expense> expenses,
    required List<Purchase> purchases,
    required List<Payment> payments,
    required List<SupplierPayment> supplierPayments,
    required OpeningBalance? openingBal,
  }) {
    final ac = AppColors.of(context);
    final range = _range;
    final csym = ref.watch(currencySymbolProvider);
    String _fmtLocal(double v) => _fmt(v, csym: csym);
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

    final filteredSales = sales.where((s) =>
        !s.isVoided && !s.isQuote &&
        !s.date.isBefore(range.start) && !s.date.isAfter(range.end)).toList();
    final salesCount = filteredSales.length;
    final marginPct = summary.revenue > 0
        ? ((summary.netProfit / summary.revenue) * 100).toStringAsFixed(1)
        : '0.0';

    return FullScreenOverlay(
      title: 'Export Reports',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedControl(
          options: const ['Daily', 'Weekly', 'Monthly', 'Custom'],
          selectedIndex: _period.index,
          onChanged: (i) {
            setState(() {
              _period = ExportPeriod.values[i];
              if (_period != ExportPeriod.custom) {
                _customStart = null;
                _customEnd = null;
              }
            });
          },
        ),
        if (_period == ExportPeriod.custom) ...[
          const SizedBox(height: 10),
          FoamCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: _pickDateRange,
            child: Row(children: [
              Icon(Icons.calendar_month_rounded, size: 17, color: ac.inkSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _customStart != null && _customEnd != null
                      ? '${DateFormat('dd-MMM-yy').format(_customStart!)} \u2014 ${DateFormat('dd-MMM-yy').format(_customEnd!)}'
                      : 'Tap to select date range',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _customStart != null ? ac.ink : ac.inkFaint,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: ac.inkFaint),
            ]),
          ),
        ],
        const SizedBox(height: 14),

        FoamCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_periodLabel(_period).toUpperCase(),
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.06, color: ac.inkFaint)),
            const SizedBox(height: 10),
            MiniRow(label: 'Revenue', value: _fmtLocal(summary.revenue)),
            MiniRow(label: 'Net profit', value: _fmtLocal(summary.netProfit),
                valueColor: summary.netProfit >= 0 ? ac.saleFg : ac.expenseFg),
            const Divider(height: 14),
            MiniRow(label: 'COGS', value: _fmtLocal(summary.cogs)),
            MiniRow(label: 'Margin', value: '$marginPct%'),
          ]),
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ac.expenseTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ac.expenseFg.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, size: 18, color: ac.expenseFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!,
                    style: TextStyle(color: ac.expenseFg, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: () => setState(() => _error = null),
                child: Icon(Icons.close_rounded, size: 16, color: ac.expenseFg),
              ),
            ]),
          ),
        ],

        if (_loading) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          Center(
            child: Text('Generating report…',
                style: TextStyle(color: ac.inkFaint, fontSize: 12)),
          ),
        ],

        if (salesCount == 0 && !_loading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: EmptyState(
              icon: Icons.insert_chart_outlined_rounded,
              title: 'No sales data for this period',
              subtitle: 'The exported report will be empty',
            ),
          ),

        SectionLabel(title: 'Format'),
        Row(children: [
          _formatCard(
            label: 'PDF',
            icon: Icons.picture_as_pdf_outlined,
            selected: _selectedFormat == 'pdf',
            onTap: () => setState(() => _selectedFormat = 'pdf'),
          ),
          const SizedBox(width: 10),
          _formatCard(
            label: 'Excel',
            icon: Icons.grid_on_rounded,
            selected: _selectedFormat == 'xlsx',
            onTap: () => setState(() => _selectedFormat = 'xlsx'),
          ),
          const SizedBox(width: 10),
          _formatCard(
            label: 'CSV',
            icon: Icons.table_chart_outlined,
            selected: _selectedFormat == 'csv',
            onTap: () => setState(() => _selectedFormat = 'csv'),
          ),
        ]),
        const SizedBox(height: 14),
        if (!_loading)
          AppButton(
            label: 'Generate Export',
            icon: Icons.download_rounded,
            onTap: () => _export(_selectedFormat),
          ),
      ]),
    );
  }

  Widget _formatCard({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ac = AppColors.of(context);
    return Expanded(
      child: TapScale(
        onTap: onTap,
        scale: 0.96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 76,
          decoration: BoxDecoration(
            color: selected ? ac.primary.withValues(alpha: 0.12) : ac.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? ac.primary : ac.outlineStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: selected ? ac.primary : ac.inkSoft),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? ac.primary : ac.inkSoft,
                )),
          ]),
        ),
      ),
    );
  }
}
