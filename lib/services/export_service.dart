import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../utils/currency.dart';
import 'accounting_service.dart';

class ExportService {
  final _dateFmt = DateFormat('dd-MMM-yyyy');
  final _dateFmtFile = DateFormat('yyyy-MM-dd');
  final _numberFmt = NumberFormat('#,##0');

  String _fmt(double v, {String currencyCode = 'PKR'}) => '${currencySymbolFromCode(currencyCode)} ${_numberFmt.format(v)}';
  String _fmtCsv(double v) => _numberFmt.format(v);
  String _marginPct(double revenue, double netProfit) =>
      revenue > 0 ? '${((netProfit / revenue) * 100).toStringAsFixed(1)}%' : '0%';
  String _invoiceId(String id) => id.length >= 8 ? id.substring(0, 8) : id;

  static String _sanitizeCsvCell(String value) {
    if (value.isEmpty) return value;
    final first = value.codeUnitAt(0);
    if (first == 0x3D || first == 0x2B || first == 0x2D || first == 0x40) {
      return '\'$value';
    }
    return value;
  }

  bool _isSingleDay(DateTime start, DateTime end) =>
      start.year == end.year && start.month == end.month && start.day == end.day;

  String _rangeLabel(DateTime start, DateTime end) {
    if (_isSingleDay(start, end)) return _dateFmt.format(start);
    return '${_dateFmt.format(start)} - ${_dateFmt.format(end)}';
  }

  Future<File> generateCsvReport({
    required List<Sale> sales,
    required List<Product> products,
    required AccountingSummary summary,
    required DateTime startDate,
    required DateTime endDate,
    String shopName = 'Digital Register',
  }) async {
    final productMap = {for (final p in products) p.id: p};
    final rows = <List<String>>[
      ['$shopName - Digital Register'],
      ['Sales Report: ${_rangeLabel(startDate, endDate)}'],
      ['Generated: ${_dateFmt.format(DateTime.now())}'],
      [],
      ['Summary'],
      ['Revenue', _fmtCsv(summary.revenue)],
      ['COGS', _fmtCsv(summary.cogs)],
      ['Gross Profit', _fmtCsv(summary.grossProfit)],
      ['Expenses', _fmtCsv(summary.totalExpenses)],
      ['Net Profit', _fmtCsv(summary.netProfit)],
      ['Margin %', _marginPct(summary.revenue, summary.netProfit)],
      [],
      ['Invoice ID', 'Date', 'Customer', 'Items', 'Amount', 'COGS', 'Profit'],
    ];

    for (final sale in sales) {
      if (sale.isVoided || sale.isQuote) continue;
      final items = sale.lineItems.map((li) {
        final prod = productMap[li.productId];
        return prod?.name ?? li.productId;
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
        _invoiceId(sale.id),
        _dateFmt.format(sale.date),
        sale.customerName ?? sale.customerId.substring(0, 6),
        _sanitizeCsvCell(items),
        _fmtCsv(sale.amount),
        _fmtCsv(cogs),
        _fmtCsv(sale.amount - cogs),
      ]);
    }

    rows.add([]);
    rows.add(['TOTAL', '', '', '', _fmtCsv(summary.revenue), _fmtCsv(summary.cogs), _fmtCsv(summary.netProfit)]);

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'foam_shop_report_${_dateFmtFile.format(DateTime.now())}.csv';
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
    final productMap = {for (final p in products) p.id: p};
    final doc = pw.Document();
    final tealColor = PdfColor.fromInt(0xFF0F6B64);
    final tealDark = PdfColor.fromInt(0xFF0B4E49);
    const subStyle = pw.TextStyle(fontSize: 10, color: PdfColors.grey600);
    final thStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    const tdStyle = pw.TextStyle(fontSize: 9);
    final totalStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

    int pageNum = 0;
    final dataRows = sales.where((s) => !s.isVoided && !s.isQuote).toList();
    final chunkSize = 25;
    final totalChunks = dataRows.isEmpty ? 1 : (dataRows.length / chunkSize).ceil();

    for (var chunkIdx = 0; chunkIdx < totalChunks; chunkIdx++) {
      final chunk = dataRows.isEmpty ? [] : dataRows.skip(chunkIdx * chunkSize).take(chunkSize).toList();
      pageNum++;

      doc.addPage(pw.MultiPage(
        margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 56),
        header: (ctx) => pw.Column(children: [
          if (chunkIdx == 0) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: pw.BoxDecoration(color: tealColor),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(shopName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text('${_rangeLabel(startDate, endDate)}', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xD9FFFFFF))),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Generated', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                  pw.Text('${_dateFmt.format(DateTime.now())}', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xD9FFFFFF))),
                ]),
              ]),
            ),
            pw.SizedBox(height: 14),
            pw.Text('Report period: ${_rangeLabel(startDate, endDate)}', style: subStyle),
            pw.SizedBox(height: 12),
            pw.Row(children: [
              pw.Expanded(child: _summaryCard('Revenue', _fmt(summary.revenue, currencyCode: currencyCode), PdfColor.fromInt(0xFFEAF3F1), PdfColor.fromInt(0xFF0F6B64))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _summaryCard('COGS', _fmt(summary.cogs, currencyCode: currencyCode), PdfColor.fromInt(0xFFFDF1E4), PdfColor.fromInt(0xFFB4712A))),
            ]),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              pw.Expanded(child: _summaryCard('Gross Profit', _fmt(summary.grossProfit, currencyCode: currencyCode), PdfColor.fromInt(0xFFE9F3EC), PdfColor.fromInt(0xFF2E6B4E))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _summaryCard('Expenses', _fmt(summary.totalExpenses, currencyCode: currencyCode), PdfColor.fromInt(0xFFFBEBE8), PdfColor.fromInt(0xFFB54A38))),
            ]),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              pw.Expanded(child: _summaryCard('Net Profit', _fmt(summary.netProfit, currencyCode: currencyCode), PdfColor.fromInt(0xFFEAF3EC), PdfColor.fromInt(0xFF2E6B4E))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _summaryCard('Margin', _marginPct(summary.revenue, summary.netProfit), PdfColor.fromInt(0xFFEAF3EC), PdfColor.fromInt(0xFF2E6B4E))),
            ]),
            pw.SizedBox(height: 14),
            pw.Text('Sales Detail', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
          ],
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            pw.Text('Page ${chunkIdx + 1} of $totalChunks', style: subStyle),
          ]),
        ]),
        footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('$shopName - Digital Register', style: subStyle),
          pw.Text('Page $pageNum', style: subStyle),
        ]),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headerStyle: thStyle,
            headerDecoration: pw.BoxDecoration(color: tealDark),
            cellStyle: tdStyle,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
            headers: ['Invoice ID', 'Date', 'Customer', 'Items', 'Amount', 'COGS', 'Profit'],
            data: chunk.map((s) {
              final items = s.lineItems.map((li) {
                final prod = productMap[li.productId];
                return prod?.name ?? li.productId;
              }).join(', ');
              double cogs = 0;
              for (final li in s.lineItems) {
                double unitCost = li.costPriceAtSale;
                if (unitCost <= 0) {
                  final prod = productMap[li.productId];
                  unitCost = prod?.costPrice ?? 0;
                }
                // fallback removed — Buy Price is required at product creation
                cogs += li.qtyOrArea * unitCost;
              }
              return [
                _invoiceId(s.id),
                _dateFmt.format(s.date),
                s.customerName ?? s.customerId.substring(0, 6),
                items.length > 25 ? '${items.substring(0, 25)}...' : items,
                _fmt(s.amount, currencyCode: currencyCode),
                _fmt(cogs, currencyCode: currencyCode),
                _fmt(s.amount - cogs, currencyCode: currencyCode),
              ];
            }).toList(),
          ),
          if (chunkIdx == totalChunks - 1 && dataRows.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFEAF3F1)),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                pw.Text('TOTAL', style: totalStyle),
                pw.SizedBox(width: 60),
                pw.Text(_fmt(summary.revenue, currencyCode: currencyCode), style: totalStyle),
                pw.Text(_fmt(summary.cogs, currencyCode: currencyCode), style: totalStyle),
                pw.Text(_fmt(summary.netProfit, currencyCode: currencyCode), style: totalStyle),
              ]),
            ),
          ],
        ],
      ));
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'foam_shop_report_${_dateFmtFile.format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  pw.Widget _summaryCard(String label, String value, PdfColor bg, PdfColor fg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: bg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xCC2E6B4E))),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: fg)),
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
    final xl = Excel.createExcel();
    final numStyle = CellStyle(numberFormat: NumFormat.standard_3);

    final summarySheet = xl['Summary'];
    summarySheet.setColumnWidth(0, 16);
    summarySheet.setColumnWidth(1, 20);
    summarySheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('$shopName - Business Report');
    summarySheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(bold: true, fontSize: 14);
    summarySheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Period: ${_rangeLabel(startDate, endDate)}');
    summarySheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Generated: ${_dateFmt.format(DateTime.now())}');

    final metricDefs = [
      ('Revenue', summary.revenue, 'FFE9F2F1'),
      ('COGS', summary.cogs, 'FFFBF0E1'),
      ('Gross Profit', summary.grossProfit, 'FFE9F3EC'),
      ('Expenses', summary.totalExpenses, 'FFFAEAE7'),
      ('Net Profit', summary.netProfit, 'FFE9F3EC'),
    ];
    for (var i = 0; i < metricDefs.length; i++) {
      final row = i + 5;
      final m = metricDefs[i];
      summarySheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(m.$1);
      summarySheet.cell(CellIndex.indexByString('A$row')).cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString(m.$3),
      );
      summarySheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(m.$2.toInt());
      summarySheet.cell(CellIndex.indexByString('B$row')).cellStyle = CellStyle(
        numberFormat: NumFormat.standard_3,
        backgroundColorHex: ExcelColor.fromHexString(m.$3),
      );
    }

    final marginRow = 5 + metricDefs.length;
    summarySheet.cell(CellIndex.indexByString('A$marginRow')).value = TextCellValue('Margin %');
    summarySheet.cell(CellIndex.indexByString('A$marginRow')).cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FFE9F3EC'),
    );
    summarySheet.cell(CellIndex.indexByString('B$marginRow')).value = TextCellValue(_marginPct(summary.revenue, summary.netProfit));
    summarySheet.cell(CellIndex.indexByString('B$marginRow')).cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('FFE9F3EC'),
    );

    final detailSheet = xl['Sales Detail'];
    detailSheet.setColumnWidth(0, 12);
    detailSheet.setColumnWidth(1, 14);
    detailSheet.setColumnWidth(2, 18);
    detailSheet.setColumnWidth(3, 28);
    detailSheet.setColumnWidth(4, 14);
    detailSheet.setColumnWidth(5, 14);
    detailSheet.setColumnWidth(6, 14);
    final headers = ['Invoice ID', 'Date', 'Customer', 'Items', 'Amount', 'COGS', 'Profit'];
    for (var c = 0; c < headers.length; c++) {
      final col = String.fromCharCode(65 + c);
      detailSheet.cell(CellIndex.indexByString('$col${1}')).value = TextCellValue(headers[c]);
      detailSheet.cell(CellIndex.indexByString('$col${1}')).cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('FF0F6B64'),
      );
    }

    final productMap = {for (final p in products) p.id: p};
    int row = 2;
    double totalAmount = 0, totalCogs = 0, totalProfit = 0;
    for (final s in sales) {
      if (s.isVoided || s.isQuote) continue;
      final items = s.lineItems.map((li) {
        final prod = productMap[li.productId];
        return prod?.name ?? li.productId;
      }).join(', ');
      double cogs = 0;
      for (final li in s.lineItems) {
        double unitCost = li.costPriceAtSale;
        if (unitCost <= 0) {
          final prod = productMap[li.productId];
          unitCost = prod?.costPrice ?? 0;
        }
        // fallback removed — Buy Price is required at product creation
        cogs += li.qtyOrArea * unitCost;
      }
      totalAmount += s.amount;
      totalCogs += cogs;
      totalProfit += s.amount - cogs;
      detailSheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(_invoiceId(s.id));
      detailSheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(_dateFmt.format(s.date));
      detailSheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(s.customerName ?? s.customerId.substring(0, 6));
      detailSheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(items.length > 25 ? '${items.substring(0, 25)}...' : items);
      detailSheet.cell(CellIndex.indexByString('E$row')).value = IntCellValue(s.amount.toInt());
      detailSheet.cell(CellIndex.indexByString('E$row')).cellStyle = numStyle;
      detailSheet.cell(CellIndex.indexByString('F$row')).value = IntCellValue(cogs.toInt());
      detailSheet.cell(CellIndex.indexByString('F$row')).cellStyle = numStyle;
      detailSheet.cell(CellIndex.indexByString('G$row')).value = IntCellValue((s.amount - cogs).toInt());
      detailSheet.cell(CellIndex.indexByString('G$row')).cellStyle = numStyle;
      row++;
    }

    final totalRow = row;
    detailSheet.cell(CellIndex.indexByString('A$totalRow')).value = TextCellValue('TOTAL');
    detailSheet.cell(CellIndex.indexByString('A$totalRow')).cellStyle = CellStyle(bold: true);
    detailSheet.cell(CellIndex.indexByString('E$totalRow')).value = IntCellValue(totalAmount.toInt());
    detailSheet.cell(CellIndex.indexByString('E$totalRow')).cellStyle = CellStyle(bold: true, numberFormat: NumFormat.standard_3);
    detailSheet.cell(CellIndex.indexByString('F$totalRow')).value = IntCellValue(totalCogs.toInt());
    detailSheet.cell(CellIndex.indexByString('F$totalRow')).cellStyle = CellStyle(bold: true, numberFormat: NumFormat.standard_3);
    detailSheet.cell(CellIndex.indexByString('G$totalRow')).value = IntCellValue(totalProfit.toInt());
    detailSheet.cell(CellIndex.indexByString('G$totalRow')).cellStyle = CellStyle(bold: true, numberFormat: NumFormat.standard_3);

    xl.delete('Sheet1');

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'foam_shop_report_${_dateFmtFile.format(DateTime.now())}.xlsx';
    final fileBytes = xl.encode();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(fileBytes!);
    return file;
  }
}
