import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/currency.dart';

/// The built-in PDF fonts (Helvetica et al.) are WinAnsi-only: the receipt's
/// `✓` and `·` render as blank boxes or mojibake, and the `pdf` package prints a
/// "Helvetica has no Unicode support" warning on every run.
///
/// Inter is already bundled in `assets/fonts/` and is the same family the
/// on-screen preview uses, so loading it here also removes the font mismatch
/// between what the customer sees and what comes out of the printer.
const _kRegular = 'assets/fonts/Inter-Regular.ttf';
const _kBold = 'assets/fonts/Inter-Bold.ttf';

Future<pw.ThemeData> _loadReceiptTheme() async {
  pw.ThemeData make(pw.Font base, pw.Font bold) => pw.ThemeData.withFont(
        base: base,
        bold: bold,
      );
  try {
    return make(
      pw.Font.ttf(await rootBundle.load(_kRegular)),
      pw.Font.ttf(await rootBundle.load(_kBold)),
    );
  } catch (_) {
    // Fonts unavailable (e.g. a unit test with no asset bundle): fall back to
    // the built-ins rather than failing the whole receipt.
    return pw.ThemeData.withFont();
  }
}

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
  String phone = '',
  String currencyCode = 'PKR',
}) async {
  final pdf = pw.Document(theme: await _loadReceiptTheme());
  final fmt = NumberFormat('#,##0');
  final csym = currencySymbolFromCode(currencyCode);

  // Palette shared with `design/foam-shop-receipt-report-mockup.html`.
  final tealDark = PdfColor.fromHex('#0B4E49');
  final ink = PdfColor.fromHex('#1B1F1E');
  final inkSoft = PdfColor.fromHex('#5A5F5E');
  final inkFaint = PdfColor.fromHex('#8A8F8E');
  final border = PdfColor.fromHex('#E3E1DC');
  final tintSalesBg = PdfColor.fromHex('#EAF3F1');
  final tintSalesFg = PdfColor.fromHex('#0F6B64');
  final tintProfitBg = PdfColor.fromHex('#EAF3EC');
  final tintProfitFg = PdfColor.fromHex('#2E6B4E');
  final tintExpenseBg = PdfColor.fromHex('#FBEBE8');
  final tintExpenseFg = PdfColor.fromHex('#B54A38');
  final white = PdfColors.white;

  // The currency symbol is printed ONCE, in the totals card, exactly like the
  // on-screen preview. It used to be repeated in every PRICE and TOTAL cell,
  // which rendered as "Rs Rs 25,500" and overflowed the 80mm columns into a
  // second line.
  String _num(double v) => fmt.format(v.toInt());
  String _fmt(double v) => '$csym ${fmt.format(v.toInt())}';

  // 80mm thermal-roll width, the format a real shop printer expects. The old
  // A4 page produced a full sheet that was mostly whitespace for a 3-line
  // receipt.
  const pageWidthMm = 80.0;
  final settled = paidAmount >= totalAmount;
  final badgeBg = remainingBalance <= 0 ? tintProfitBg : tintExpenseBg;
  final badgeFg = remainingBalance <= 0 ? tintProfitFg : tintExpenseFg;
  pw.Widget th(String label, {bool left = false}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          label,
          textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
          style: pw.TextStyle(
              fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: inkFaint),
        ),
      );

  pw.Widget td(String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: ink),
        ),
      );

  pw.Widget totalRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: inkSoft)),
            pw.Text(value, style: pw.TextStyle(fontSize: 9, color: ink)),
          ],
        ),
      );

  pdf.addPage(
    // `MultiPage`, NOT `Page`.
    //
    // With a plain `pw.Page` the whole receipt was one `pw.Column` on a
    // fixed-height sheet. Anything past the bottom was silently *dropped*: a
    // 25-item sale produced a 4.0 KB PDF, smaller than a 1-item one (5.0 KB),
    // because the item table simply stopped rendering. Long foam orders — the
    // normal case for this shop — printed an incomplete receipt.
    //
    // `MultiPage` lays the children out into as many pages as they need, so
    // every line item is always printed.
    pw.MultiPage(
      pageFormat: PdfPageFormat(
        pageWidthMm * PdfPageFormat.mm,
        297 * PdfPageFormat.mm,
        marginAll: 6 * PdfPageFormat.mm,
      ),
      // Keep the full-width bands (header, totals, badge) edge to edge exactly
      // as the single `Column` did.
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      build: (_) {
        return [
          // Branded header block (`.r-header`): a teal gradient banner so the
          // receipt is identifiable at a glance in a pile of paper.
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(12, 14, 12, 14),
            decoration: pw.BoxDecoration(
              color: tealDark,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  storeName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: white,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Digital Register',
                  style: pw.TextStyle(fontSize: 8.5, color: white),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Date / receipt # (`.r-meta`)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DATE',
                      style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: inkFaint)),
                  pw.SizedBox(height: 1),
                  pw.Text(date, style: pw.TextStyle(fontSize: 9, color: ink)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('RECEIPT #',
                      style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: inkFaint)),
                  pw.SizedBox(height: 1),
                  pw.Text(receiptId,
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: ink)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: border, thickness: 0.7, height: 0.7),
          pw.SizedBox(height: 8),

          // Contact line (`.r-meta-line`): the preview shows location/phone
          // here, but the printed receipt dropped them, so the two documents
          // disagreed for the same sale.
          if (location.isNotEmpty || phone.isNotEmpty) ...[
            pw.Text(
              [if (location.isNotEmpty) location, if (phone.isNotEmpty) phone]
                  .join(' \u00b7 '),
              style: pw.TextStyle(fontSize: 8.5, color: inkFaint),
            ),
            pw.SizedBox(height: 6),
          ],

          // Customer (`.r-cust`)
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                    text: 'Customer: ',
                    style: pw.TextStyle(fontSize: 9, color: inkSoft)),
                pw.TextSpan(
                    text: customerName,
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: ink)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          // Itemised table (`.r-items`): a real column table, not stacked
          // label/value lines, so qty/price/total can be scanned vertically.
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: pw.BorderSide(color: border, width: 0.5),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(3.2),
              1: pw.FlexColumnWidth(1.0),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.7),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: ink, width: 1.2),
                  ),
                ),
                children: [
                  th('ITEM', left: true),
                  th('QTY'),
                  th('PRICE'),
                  th('TOTAL'),
                ],
              ),
              for (final i in items)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5),
                      child: pw.Text(
                        i['name'].toString(),
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: ink),
                      ),
                    ),
                    td(i['qty'].toString()),
                    td(_num((i['price'] as num).toDouble())),
                    td(_num((i['total'] as num).toDouble()), bold: true),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),
          // Totals card (`.r-totals`)
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: pw.BoxDecoration(
              color: tintSalesBg,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(children: [
              totalRow('Amount', _fmt(totalAmount)),
              totalRow('Paid', _fmt(paidAmount)),
              pw.SizedBox(height: 5),
              pw.Container(height: 0.7, color: tintSalesFg),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    settled ? 'Balance' : 'Balance Due',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: tintSalesFg,
                    ),
                  ),
                  pw.Text(
                    settled ? _fmt(0) : _fmt((totalAmount - paidAmount).abs()),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: tintSalesFg,
                    ),
                  ),
                ],
              ),
            ]),
          ),
          pw.SizedBox(height: 10),

          // Status badge (`.r-balance`): a colour-coded pill rather than a
          // bare red line, so "Fully Paid" reads instantly at the counter.
          pw.Center(
            child: pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: badgeBg,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Text(
                remainingBalance <= 0 ? '\u2713 FULLY PAID' : 'BALANCE DUE',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: badgeFg,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 14),

          // Footer (`.r-footer`)
          pw.Divider(color: border, thickness: 0.7, height: 0.7),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'Thank you for your business!',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: tintSalesFg,
              ),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              location.isNotEmpty ? '$storeName \u00b7 $location' : storeName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 7.5, color: inkFaint),
            ),
          ),
        ];
      },
    ),
  );

  return await pdf.save();
}
