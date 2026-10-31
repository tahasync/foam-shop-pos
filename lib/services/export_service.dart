import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../utils/currency.dart';
import '../utils/brand.dart';
import 'accounting_service.dart';

class ExportService {
  final _dateFmt = DateFormat('dd-MMM-yyyy');

  /// Timestamp for report filenames, to the second.
  ///
  /// Reports were named to the DAY only, so a second export on the same day
  /// silently overwrote the first. A shopkeeper who exported the morning
  /// figures, emailed them to their accountant, then corrected a sale and
  /// re-exported ended up with a link whose contents no longer matched what
  /// was sent. Including the time makes every export a distinct file.
  final _stampFmtFile = DateFormat('yyyy-MM-dd_HHmmss');

  /// A fresh, collision-free filename stem for one export.
  String _reportStem() =>
      'foam_shop_report_${_stampFmtFile.format(DateTime.now())}';
  final _numberFmt = NumberFormat('#,##0');

  String _fmt(double v, {String currencyCode = 'PKR'}) =>
      '${currencySymbolFromCode(currencyCode)} ${_numberFmt.format(v)}';
  String _fmtCsv(double v) => NumberFormat('#,##0.##').format(v);
  String _marginPct(double revenue, double netProfit) => revenue > 0
      ? '${((netProfit / revenue) * 100).toStringAsFixed(1)}%'
      : '0%';
  String _invoiceId(String id) => id.length >= 8 ? id.substring(0, 8) : id;

  /// A display name for a sale's customer, safe for any ID length.
  ///
  /// This used to be `customerName ?? customerId.substring(0, 6)`, which threw
  /// `RangeError` for any ID shorter than six characters — and a walk-in sale
  /// stores an *empty* `customerId` by design (see the Walk-in button in
  /// `sales_entry_screen.dart`). One walk-in sale in the selected period was
  /// therefore enough to abort CSV, XLSX and PDF generation together, which is
  /// exactly what "export is not working" looked like from the shop's side.
  ///
  /// Falls back to a readable label, and only truncates when there is enough
  /// text to make the abbreviation worth it.
  String _customerLabel(Sale sale) {
    final name = sale.customerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = sale.customerId.trim();
    if (id.isEmpty) return 'Walk-in Customer';
    return id.length >= 6 ? id.substring(0, 6) : id;
  }

  static String _sanitizeCsvCell(String value) {
    if (value.isEmpty) return value;
    final first = value.codeUnitAt(0);
    if (first == 0x3D || first == 0x2B || first == 0x2D || first == 0x40) {
      return '\'$value';
    }
    return value;
  }

  bool _isSingleDay(DateTime start, DateTime end) =>
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;

  String _rangeLabel(DateTime start, DateTime end) {
    if (_isSingleDay(start, end)) return _dateFmt.format(start);
    return '${_dateFmt.format(start)} - ${_dateFmt.format(end)}';
  }

  /// Builds the report as CSV text, without touching the filesystem.
  ///
  /// Split out from [generateCsvReport] so the content can be asserted in tests
  /// without a plugin-provided documents directory, and so a formatting bug
  /// cannot hide behind a file-system error.
  String buildCsvReport({
    required List<Sale> sales,
    required List<Product> products,
    required AccountingSummary summary,
    required DateTime startDate,
    required DateTime endDate,
    String shopName = 'Digital Register',
    String currencyCode = 'PKR',
  }) {
    final productMap = {for (final p in products) p.id: p};
    final rows = <List<String>>[
      [_sanitizeCsvCell('${AppBrand.name} - ${AppBrand.descriptor}')],
      [_sanitizeCsvCell(shopName)],
      ['Business report', _rangeLabel(startDate, endDate)],
      ['Generated', _dateFmt.format(DateTime.now())],
      [],
      ['SUMMARY', 'VALUE', 'CURRENCY'],
      ['Revenue', _fmtCsv(summary.revenue), currencyCode],
      ['COGS', _fmtCsv(summary.cogs), currencyCode],
      ['Gross profit', _fmtCsv(summary.grossProfit), currencyCode],
      ['Expenses', _fmtCsv(summary.totalExpenses), currencyCode],
      ['Net profit', _fmtCsv(summary.netProfit), currencyCode],
      ['Margin', _marginPct(summary.revenue, summary.netProfit), ''],
      ['Cash in hand', _fmtCsv(summary.cashInHand), currencyCode],
      ['Customer balance', _fmtCsv(summary.totalCustomerBaqaya), currencyCode],
      ['Supplier balance', _fmtCsv(summary.totalSupplierBaqaya), currencyCode],
      ['Inventory value', _fmtCsv(summary.inventoryValue), currencyCode],
      [],
      ['SALES DETAIL'],
      ['Invoice ID', 'Date', 'Customer', 'Items', 'Amount', 'COGS', 'Profit'],
    ];

    for (final sale in sales) {
      if (sale.isVoided || sale.isQuote) continue;
      final items = sale.lineItems.map((li) {
        final prod = productMap[li.productId];
        return prod?.name ?? li.name ?? li.productId;
      }).join(', ');
      double cogs = 0;
      for (final li in sale.lineItems) {
        double unitCost = li.costPriceAtSale;
        if (unitCost <= 0) {
          final prod = productMap[li.productId];
          unitCost = prod?.costPrice ?? 0;
        }
        cogs += li.qtyOrArea * unitCost;
      }
      rows.add([
        _sanitizeCsvCell(_invoiceId(sale.id)),
        _dateFmt.format(sale.date),
        _sanitizeCsvCell(_customerLabel(sale)),
        _sanitizeCsvCell(items),
        _fmtCsv(sale.amount),
        _fmtCsv(cogs),
        _fmtCsv(sale.amount - cogs),
      ]);
    }

    rows.add([]);
    rows.add([
      'TOTAL',
      '',
      '',
      '',
      _fmtCsv(summary.revenue),
      _fmtCsv(summary.cogs),
      _fmtCsv(summary.netProfit)
    ]);

    // UTF-8 BOM makes the Unicode Foam Shop title open correctly in desktop
    // spreadsheet apps. CSV has no styling, so its clear section rows and
    // stable numeric columns carry the same report hierarchy as PDF/XLSX.
    return '\uFEFF${const ListToCsvConverter().convert(rows)}';
  }

  Future<File> generateCsvReport({
    required List<Sale> sales,
    required List<Product> products,
    required AccountingSummary summary,
    required DateTime startDate,
    required DateTime endDate,
    String shopName = 'Digital Register',
    String currencyCode = 'PKR',
  }) async {
    final csv = buildCsvReport(
      sales: sales,
      products: products,
      summary: summary,
      startDate: startDate,
      endDate: endDate,
      shopName: shopName,
      currencyCode: currencyCode,
    );
    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${_reportStem()}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);
    return file;
  }

  Future<File> generatePdfReport({
    required List<Sale> sales,
    required List<Product> products,
    required AccountingSummary summary,
    required DateTime startDate,
    required DateTime endDate,
    required String shopName,
    String currencyCode = 'PKR',
  }) async {
    final bytes = await buildPdfReportBytes(
      sales: sales,
      products: products,
      summary: summary,
      startDate: startDate,
      endDate: endDate,
      shopName: shopName,
      currencyCode: currencyCode,
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${_reportStem()}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Builds the report PDF in memory for preview and layout verification.
  Future<Uint8List> buildPdfReportBytes({
    required List<Sale> sales,
    required List<Product> products,
    required AccountingSummary summary,
    required DateTime startDate,
    required DateTime endDate,
    required String shopName,
    String currencyCode = 'PKR',
  }) async {
    final productMap = {for (final p in products) p.id: p};
    final regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final doc = pw.Document(theme: theme);
    final navy = PdfColor.fromInt(BrandPalette.deepNavy);
    final slate = PdfColor.fromInt(BrandPalette.slateBlue);
    final ink = PdfColor.fromInt(BrandPalette.deepInk);
    final foam = PdfColor.fromInt(BrandPalette.foamWhite);
    final muted = PdfColor.fromHex('#6E6A74');
    final rule = PdfColor.fromHex('#D9D7DC');
    final cardTints = [
      PdfColor.fromInt(BrandPalette.paidTint),
      foam,
      PdfColor.fromInt(BrandPalette.paidTint),
      PdfColor.fromInt(BrandPalette.dueTint),
      PdfColor.fromInt(BrandPalette.paidTint),
      foam,
    ];
    final subStyle = pw.TextStyle(fontSize: 8.5, color: muted);
    final headerStyle = pw.TextStyle(
      fontSize: 7.2,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 0.45,
      color: PdfColors.white,
    );
    final cellStyle = pw.TextStyle(fontSize: 8, color: ink);
    final totalStyle = pw.TextStyle(
      fontSize: 8.5,
      fontWeight: pw.FontWeight.bold,
      color: navy,
    );

    final dataRows = sales.where((s) => !s.isVoided && !s.isQuote).toList();
    final rows = dataRows.map((sale) {
      final items = sale.lineItems.map((line) {
        final product = productMap[line.productId];
        return product?.name ?? line.name ?? line.productId;
      }).join(', ');
      final cogs = sale.lineItems.fold<double>(0, (sum, line) {
        final savedCost = line.costPriceAtSale;
        final fallbackCost = productMap[line.productId]?.costPrice ?? 0;
        return sum +
            line.qtyOrArea * (savedCost > 0 ? savedCost : fallbackCost);
      });
      return [
        _invoiceId(sale.id),
        _dateFmt.format(sale.date),
        _customerLabel(sale),
        items,
        _fmt(sale.amount, currencyCode: currencyCode),
        _fmt(cogs, currencyCode: currencyCode),
        _fmt(sale.amount - cogs, currencyCode: currencyCode),
      ];
    }).toList();

    final cards = [
      ('Revenue', _fmt(summary.revenue, currencyCode: currencyCode)),
      ('COGS', _fmt(summary.cogs, currencyCode: currencyCode)),
      ('Gross profit', _fmt(summary.grossProfit, currencyCode: currencyCode)),
      ('Expenses', _fmt(summary.totalExpenses, currencyCode: currencyCode)),
      ('Net profit', _fmt(summary.netProfit, currencyCode: currencyCode)),
      ('Margin', _marginPct(summary.revenue, summary.netProfit)),
    ];

    doc.addPage(pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(38, 36, 38, 42),
      header: (ctx) {
        if (ctx.pageNumber == 1) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: pw.BoxDecoration(
                  color: navy,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(shopName,
                              maxLines: 1,
                              style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white)),
                          pw.SizedBox(height: 3),
                          pw.Text('${AppBrand.name}  ·  ${AppBrand.descriptor}',
                              style: pw.TextStyle(fontSize: 8.5, color: foam)),
                          pw.SizedBox(height: 4),
                          pw.Text('BUSINESS REPORT',
                              style: pw.TextStyle(
                                  fontSize: 7,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: PdfColor.fromInt(
                                      BrandPalette.periwinkle))),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('REPORT PERIOD', style: headerStyle),
                        pw.SizedBox(height: 3),
                        pw.Text(_rangeLabel(startDate, endDate),
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white)),
                        pw.SizedBox(height: 5),
                        pw.Text('Generated ${_dateFmt.format(DateTime.now())}',
                            style: pw.TextStyle(fontSize: 7.5, color: foam)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) pw.SizedBox(width: 7),
                    pw.Expanded(
                      child: _summaryCard(
                          cards[i].$1, cards[i].$2, cardTints[i], navy),
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 7),
              pw.Row(
                children: [
                  for (var i = 3; i < 6; i++) ...[
                    if (i > 3) pw.SizedBox(width: 7),
                    pw.Expanded(
                      child: _summaryCard(
                          cards[i].$1, cards[i].$2, cardTints[i], navy),
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 13),
              pw.Text('SALES DETAIL',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                      color: ink)),
              pw.SizedBox(height: 6),
            ],
          );
        }

        return pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: rule))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(shopName,
                  style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: navy)),
              pw.Text('BUSINESS REPORT  ·  ${_rangeLabel(startDate, endDate)}',
                  style: subStyle),
            ],
          ),
        );
      },
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 7),
        decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: rule))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${AppBrand.name}  ·  ${AppBrand.descriptor}',
                style: subStyle),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: subStyle),
          ],
        ),
      ),
      build: (ctx) => [
        if (dataRows.isEmpty)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
                color: foam,
                border: pw.Border.all(color: rule),
                borderRadius: pw.BorderRadius.circular(7)),
            child: pw.Text('No sales were recorded during this report period.',
                style: pw.TextStyle(fontSize: 9, color: ink)),
          )
        else
          pw.TableHelper.fromTextArray(
            headerStyle: headerStyle,
            headerPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            headerDecoration: pw.BoxDecoration(color: slate),
            cellStyle: cellStyle,
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(0.85),
              1: const pw.FlexColumnWidth(1.0),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.75),
              4: const pw.FlexColumnWidth(1.05),
              5: const pw.FlexColumnWidth(1.05),
              6: const pw.FlexColumnWidth(1.05),
            },
            oddRowDecoration: pw.BoxDecoration(color: foam),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: rule, width: 0.45),
              bottom: pw.BorderSide(color: rule, width: 0.7),
            ),
            headers: const [
              'INVOICE',
              'DATE',
              'CUSTOMER',
              'ITEMS',
              'AMOUNT',
              'COGS',
              'PROFIT'
            ],
            data: rows,
          ),
        if (dataRows.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(BrandPalette.paidTint),
                borderRadius: pw.BorderRadius.circular(5)),
            child: pw.Row(
              children: [
                pw.Expanded(
                    flex: 4, child: pw.Text('TOTALS', style: totalStyle)),
                pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                        _fmt(summary.revenue, currencyCode: currencyCode),
                        textAlign: pw.TextAlign.right,
                        style: totalStyle)),
                pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                        _fmt(summary.cogs, currencyCode: currencyCode),
                        textAlign: pw.TextAlign.right,
                        style: totalStyle)),
                pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                        _fmt(summary.netProfit, currencyCode: currencyCode),
                        textAlign: pw.TextAlign.right,
                        style: totalStyle)),
              ],
            ),
          ),
        ],
      ],
    ));

    return Uint8List.fromList(await doc.save());
  }

  pw.Widget _summaryCard(String label, String value, PdfColor bg, PdfColor fg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(BrandPalette.deepInk))),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: fg)),
      ]),
    );
  }

  Future<File> generateXlsxReport({
    required List<Sale> sales,
    required List<Product> products,
    required AccountingSummary summary,
    required DateTime startDate,
    required DateTime endDate,
    String shopName = 'Digital Register',
    String currencyCode = 'PKR',
  }) async {
    final fileBytes = buildXlsxReportBytes(
      sales: sales,
      products: products,
      summary: summary,
      startDate: startDate,
      endDate: endDate,
      shopName: shopName,
      currencyCode: currencyCode,
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${_reportStem()}.xlsx');
    await file.writeAsBytes(fileBytes);
    return file;
  }

  /// Builds a styled workbook without touching the file system.
  ///
  /// Kept separate so numeric precision, hierarchy and palette can be checked
  /// in unit tests without relying on a platform documents directory.
  Uint8List buildXlsxReportBytes({
    required List<Sale> sales,
    required List<Product> products,
    required AccountingSummary summary,
    required DateTime startDate,
    required DateTime endDate,
    String shopName = 'Digital Register',
    String currencyCode = 'PKR',
  }) {
    String excelHex(int color) =>
        color.toRadixString(16).padLeft(8, '0').toUpperCase();
    final navyHex = excelHex(BrandPalette.deepNavy);
    final slateHex = excelHex(BrandPalette.slateBlue);
    final inkHex = excelHex(BrandPalette.deepInk);
    final foamHex = excelHex(BrandPalette.foamWhite);
    final paidTintHex = excelHex(BrandPalette.paidTint);
    final dueTintHex = excelHex(BrandPalette.dueTint);
    final amountFormat =
        NumFormat.custom(formatCode: '#,##0.##;[Red](#,##0.##)');

    final xl = Excel.createExcel();
    final summarySheet = xl['Summary'];
    summarySheet.setColumnWidth(0, 26);
    summarySheet.setColumnWidth(1, 22);
    summarySheet.setColumnWidth(2, 13);
    summarySheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('C1'),
    );
    summarySheet.merge(
      CellIndex.indexByString('A2'),
      CellIndex.indexByString('C2'),
    );
    summarySheet.merge(
      CellIndex.indexByString('A3'),
      CellIndex.indexByString('C3'),
    );
    summarySheet.setRowHeight(0, 34);
    summarySheet.setRowHeight(1, 24);

    summarySheet.cell(CellIndex.indexByString('A1')).value =
        TextCellValue('${AppBrand.name}  ·  ${AppBrand.descriptor}');
    summarySheet.cell(CellIndex.indexByString('A2')).value =
        TextCellValue('$shopName  |  Business Report');
    summarySheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'Period: ${_rangeLabel(startDate, endDate)}  |  Generated: ${_dateFmt.format(DateTime.now())}');
    summarySheet.setMergedCellStyle(
        CellIndex.indexByString('A1'),
        CellStyle(
          bold: true,
          fontSize: 16,
          fontFamily: 'Inter',
          fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
          backgroundColorHex: ExcelColor.fromHexString(navyHex),
          verticalAlign: VerticalAlign.Center,
        ));
    summarySheet.setMergedCellStyle(
        CellIndex.indexByString('A2'),
        CellStyle(
          bold: true,
          fontSize: 12,
          fontFamily: 'Inter',
          fontColorHex: ExcelColor.fromHexString(navyHex),
          backgroundColorHex: ExcelColor.fromHexString(foamHex),
          verticalAlign: VerticalAlign.Center,
        ));
    summarySheet.setMergedCellStyle(
        CellIndex.indexByString('A3'),
        CellStyle(
          fontSize: 10,
          fontFamily: 'Inter',
          fontColorHex: ExcelColor.fromHexString(inkHex),
          backgroundColorHex: ExcelColor.fromHexString(foamHex),
          verticalAlign: VerticalAlign.Center,
        ));

    for (final (col, value) in [
      (0, 'METRIC'),
      (1, 'VALUE'),
      (2, 'CURRENCY'),
    ]) {
      final cell = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 4));
      cell.value = TextCellValue(value);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontFamily: 'Inter',
        fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString(slateHex),
        verticalAlign: VerticalAlign.Center,
      );
    }
    summarySheet.setRowHeight(4, 24);

    final metrics = [
      ('Revenue', summary.revenue, paidTintHex),
      ('Cost of goods sold', summary.cogs, foamHex),
      ('Gross profit', summary.grossProfit, paidTintHex),
      ('Expenses', summary.totalExpenses, dueTintHex),
      ('Net profit', summary.netProfit, paidTintHex),
      (
        'Profit margin',
        summary.revenue > 0 ? summary.netProfit / summary.revenue : 0.0,
        foamHex
      ),
      ('Cash in hand', summary.cashInHand, foamHex),
      ('Customer balance', summary.totalCustomerBaqaya, dueTintHex),
      ('Supplier balance', summary.totalSupplierBaqaya, dueTintHex),
      ('Inventory value', summary.inventoryValue, foamHex),
    ];
    for (var i = 0; i < metrics.length; i++) {
      final row = i + 5;
      final metric = metrics[i];
      final label = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      final value = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      final currency = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      label.value = TextCellValue(metric.$1);
      value.value = DoubleCellValue(metric.$2);
      currency.value =
          TextCellValue(metric.$1 == 'Profit margin' ? '%' : currencyCode);
      final fill = ExcelColor.fromHexString(metric.$3);
      label.cellStyle = CellStyle(
        bold: metric.$1 == 'Revenue' || metric.$1 == 'Net profit',
        fontFamily: 'Inter',
        fontColorHex: ExcelColor.fromHexString(inkHex),
        backgroundColorHex: fill,
        verticalAlign: VerticalAlign.Center,
      );
      value.cellStyle = CellStyle(
        bold: true,
        fontFamily: 'Inter',
        fontColorHex: ExcelColor.fromHexString(navyHex),
        backgroundColorHex: fill,
        numberFormat:
            metric.$1 == 'Profit margin' ? NumFormat.standard_10 : amountFormat,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      );
      currency.cellStyle = CellStyle(
        fontSize: 9,
        fontFamily: 'Inter',
        fontColorHex: ExcelColor.fromHexString(inkHex),
        backgroundColorHex: fill,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      summarySheet.setRowHeight(row, 22);
    }

    final detailSheet = xl['Sales Detail'];
    const headers = [
      'Invoice ID',
      'Date',
      'Customer',
      'Items',
      'Amount',
      'COGS',
      'Profit',
    ];
    const widths = [14.0, 16.0, 26.0, 44.0, 18.0, 18.0, 18.0];
    for (var i = 0; i < widths.length; i++) {
      detailSheet.setColumnWidth(i, widths[i]);
    }
    for (final row in [0, 1, 2]) {
      detailSheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
      );
    }
    detailSheet.setRowHeight(0, 32);
    detailSheet.setRowHeight(1, 24);
    detailSheet.cell(CellIndex.indexByString('A1')).value =
        TextCellValue('${AppBrand.name}  ·  SALES DETAIL');
    detailSheet.cell(CellIndex.indexByString('A2')).value =
        TextCellValue('$shopName  |  ${_rangeLabel(startDate, endDate)}');
    detailSheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'Currency: $currencyCode  |  Amounts stay numeric for sorting and formulas');
    detailSheet.setMergedCellStyle(
        CellIndex.indexByString('A1'),
        CellStyle(
          bold: true,
          fontSize: 15,
          fontFamily: 'Inter',
          fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
          backgroundColorHex: ExcelColor.fromHexString(navyHex),
          verticalAlign: VerticalAlign.Center,
        ));
    detailSheet.setMergedCellStyle(
        CellIndex.indexByString('A2'),
        CellStyle(
          bold: true,
          fontSize: 11,
          fontFamily: 'Inter',
          fontColorHex: ExcelColor.fromHexString(navyHex),
          backgroundColorHex: ExcelColor.fromHexString(foamHex),
          verticalAlign: VerticalAlign.Center,
        ));
    detailSheet.setMergedCellStyle(
        CellIndex.indexByString('A3'),
        CellStyle(
          fontSize: 9,
          fontFamily: 'Inter',
          fontColorHex: ExcelColor.fromHexString(inkHex),
          backgroundColorHex: ExcelColor.fromHexString(foamHex),
          verticalAlign: VerticalAlign.Center,
        ));

    for (var col = 0; col < headers.length; col++) {
      final cell = detailSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 4));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontFamily: 'Inter',
        fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString(slateHex),
        horizontalAlign:
            col >= 4 ? HorizontalAlign.Right : HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );
    }
    detailSheet.setRowHeight(4, 25);

    final productMap = {for (final p in products) p.id: p};
    var row = 5;
    var totalAmount = 0.0;
    var totalCogs = 0.0;
    var totalProfit = 0.0;
    for (final sale in sales) {
      if (sale.isVoided || sale.isQuote) continue;
      final items = sale.lineItems.map((line) {
        final product = productMap[line.productId];
        return product?.name ?? line.name ?? line.productId;
      }).join(', ');
      final cogs = sale.lineItems.fold<double>(0, (sum, line) {
        final savedCost = line.costPriceAtSale;
        final fallbackCost = productMap[line.productId]?.costPrice ?? 0;
        return sum +
            line.qtyOrArea * (savedCost > 0 ? savedCost : fallbackCost);
      });
      totalAmount += sale.amount;
      totalCogs += cogs;
      totalProfit += sale.amount - cogs;

      final values = [
        TextCellValue(_invoiceId(sale.id)),
        TextCellValue(_dateFmt.format(sale.date)),
        TextCellValue(_customerLabel(sale)),
        TextCellValue(items),
        DoubleCellValue(sale.amount),
        DoubleCellValue(cogs),
        DoubleCellValue(sale.amount - cogs),
      ];
      final fillHex = row.isOdd ? foamHex : 'FFFFFFFF';
      for (var col = 0; col < values.length; col++) {
        final cell = detailSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = values[col];
        cell.cellStyle = CellStyle(
          fontSize: 10,
          fontFamily: 'Inter',
          fontColorHex: ExcelColor.fromHexString(inkHex),
          backgroundColorHex: ExcelColor.fromHexString(fillHex),
          numberFormat: amountFormat,
          horizontalAlign:
              col >= 4 ? HorizontalAlign.Right : HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center,
          textWrapping:
              col == 2 || col == 3 ? TextWrapping.WrapText : TextWrapping.Clip,
        );
      }
      detailSheet.setRowHeight(row, 25);
      row++;
    }

    final totalRow = row;
    for (var col = 0; col < headers.length; col++) {
      final cell = detailSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: totalRow));
      cell.value = TextCellValue(col == 0 ? 'TOTAL' : '');
      cell.cellStyle = CellStyle(
        bold: true,
        fontFamily: 'Inter',
        fontColorHex: ExcelColor.fromHexString(navyHex),
        backgroundColorHex: ExcelColor.fromHexString(paidTintHex),
        horizontalAlign:
            col >= 4 ? HorizontalAlign.Right : HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );
    }
    for (final (col, value) in [
      (4, totalAmount),
      (5, totalCogs),
      (6, totalProfit)
    ]) {
      final cell = detailSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: totalRow));
      cell.value = DoubleCellValue(value);
      cell.cellStyle = CellStyle(
        bold: true,
        fontFamily: 'Inter',
        fontColorHex: ExcelColor.fromHexString(navyHex),
        backgroundColorHex: ExcelColor.fromHexString(paidTintHex),
        numberFormat: amountFormat,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      );
    }
    detailSheet.setRowHeight(totalRow, 25);

    xl.delete('Sheet1');
    final bytes = xl.encode();
    if (bytes == null)
      throw StateError('Could not encode the report workbook.');
    return Uint8List.fromList(bytes);
  }
}
