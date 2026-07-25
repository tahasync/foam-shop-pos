import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/expense.dart';
import '../models/product.dart';
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
import '../utils/currency.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';

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
    final ac = AppColors.of(context);

    final salesAsync = ref.watch(salesStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Export Reports')),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.onSurface))),
        data: (sales) => productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.onSurface))),
          data: (products) => expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.onSurface))),
            data: (expenses) => _buildBody(context, cs, ac, sales, products, expenses),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme cs, AppColors ac,
      List<Sale> sales, List<Product> products, List<Expense> expenses) {
    final range = _range;
    final profile = ref.read(shopProfileProvider).asData?.value;
    final csym = profile != null ? currencySymbolFromCode(profile.currency) : 'Rs';
    String _fmtLocal(double v) => _fmt(v, csym: csym);
    final summary = AccountingService().recomputeForPeriod(
      sales: sales,
      purchases: [],
      expenses: expenses,
      payments: [],
      supplierPayments: [],
      products: products,
      openingBal: null,
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ExportPeriod>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ExportPeriod.daily, label: Text('Daily', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis)),
                    ButtonSegment(value: ExportPeriod.weekly, label: Text('Weekly', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis)),
                    ButtonSegment(value: ExportPeriod.monthly, label: Text('Monthly', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis)),
                    ButtonSegment(value: ExportPeriod.custom, label: Text('Custom', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis)),
                  ],
                  selected: {_period},
                  onSelectionChanged: (v) {
                    setState(() {
                      _period = v.first;
                      if (_period != ExportPeriod.custom) {
                        _customStart = null;
                        _customEnd = null;
                      }
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              if (_period == ExportPeriod.custom) ...[
                InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                      color: cs.surfaceContainerLowest,
                    ),
                    child: Row(children: [
                      Icon(Icons.date_range_rounded, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _customStart != null && _customEnd != null
                              ? '${DateFormat('dd-MMM-yy').format(_customStart!)} — ${DateFormat('dd-MMM-yy').format(_customEnd!)}'
                              : 'Tap to select date range',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: ac.inkFaint),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Summary preview card
              Container(
                padding: const EdgeInsets.all(16),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_periodLabel(_period), style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.06,
                        color: Colors.white.withValues(alpha: 0.85),
                      )),
                      Text(
                        salesCount > 0
                            ? '$salesCount sales'
                            : 'No sales',
                        style: TextStyle(
                          fontSize: 10.5, color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    _statItem('Revenue', _fmtLocal(summary.revenue)),
                    const SizedBox(width: 16),
                    _statItem('Net Profit', _fmtLocal(summary.netProfit)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    _statItem('COGS', _fmtLocal(summary.cogs)),
                    const SizedBox(width: 16),
                    _statItem('Margin', '$marginPct%'),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _error = null),
                      child: Icon(Icons.close_rounded, size: 16, color: cs.onErrorContainer),
                    ),
                  ]),
                ),

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
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.insert_chart_outlined_rounded, size: 48,
                          color: ac.inkFaint.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('No sales data for this period',
                          style: TextStyle(color: ac.inkFaint)),
                    ]),
                  ),
                ),
            ],
          ),
        ),

        // Bottom action buttons
        if (!_loading)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: _exportButton(
                      label: 'CSV',
                      icon: Icons.table_chart_outlined,
                      color: cs.primary,
                      onTap: () => _export('csv'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _exportButton(
                      label: 'Excel',
                      icon: Icons.grid_on_rounded,
                      color: AppTheme.sage,
                      onTap: () => _export('xlsx'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _exportButton(
                      label: 'PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      color: AppTheme.terracotta,
                      onTap: () => _export('pdf'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
      ],
    );
  }

  Widget _exportButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _statItem(String label, String value) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9))),
      const SizedBox(height: 1),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
          fontFeatures: [FontFeature('tnum')], color: Colors.white)),
    ]));
  }
}
