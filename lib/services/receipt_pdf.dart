import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/currency.dart';

Future<Uint8List> generateReceiptPdfBytes({
  required String storeName,
  required String receiptId,
  required String date,
  required String customerName,
  required List<Map<String, dynamic>> items,
  required double totalAmount,
  required double paidAmount,
  required double remainingBalance,
  String location = '',
  String currencyCode = 'PKR',
}) async {
  final pdf = pw.Document();
  final fmt = NumberFormat('#,##0');
  final csym = currencySymbolFromCode(currencyCode);

  final tealDark = PdfColor.fromHex('#0B4E49');
  final tintSalesBg = PdfColor.fromHex('#EAF3F1');
  final tintSalesFg = PdfColor.fromHex('#0F6B64');
  final tintProfitBg = PdfColor.fromHex('#EAF3EC');
  final tintProfitFg = PdfColor.fromHex('#2E6B4E');
  final tintExpenseBg = PdfColor.fromHex('#FBEBE8');
  final tintExpenseFg = PdfColor.fromHex('#B54A38');

  String _fmt(double v) => '$csym ${fmt.format(v.toInt())}';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: tealDark,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(children: [
                pw.Text(storeName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 2),
                pw.Text('Digital Register', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
              ]),
            ),
            pw.SizedBox(height: 16),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Receipt #: $receiptId', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 4),
            pw.Text('Customer: $customerName', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Item', 'Qty', 'Price', 'Total'],
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: tealDark),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellStyle: const pw.TextStyle(fontSize: 10),
              data: items.map((i) => [
                i['name'].toString(),
                '${i['qty']}',
                _fmt((i['price'] as num).toDouble()),
                _fmt((i['total'] as num).toDouble()),
              ]).toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: tintSalesBg, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(children: [
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(_fmt(totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]),
                pw.SizedBox(height: 4),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Paid'),
                  pw.Text(_fmt(paidAmount)),
                ]),
                pw.Divider(color: tintSalesFg, thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text(paidAmount >= totalAmount ? 'Change' : 'Balance Due',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                          color: paidAmount >= totalAmount ? tintProfitFg : tintExpenseFg)),
                  pw.Text(_fmt((paidAmount - totalAmount).abs()),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                          color: paidAmount >= totalAmount ? tintProfitFg : tintExpenseFg)),
                ]),
              ]),
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: remainingBalance <= 0 ? tintProfitBg : tintExpenseBg,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  remainingBalance <= 0 ? 'FULLY PAID' : 'BALANCE DUE',
                  style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold,
                    color: remainingBalance <= 0 ? tintProfitFg : tintExpenseFg,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Center(child: pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: tintSalesFg))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('$storeName${location.isNotEmpty ? ' \u00b7 $location' : ''}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
          ],
        );
      },
    ),
  );

  return await pdf.save();
}
