// Receipt model + print layout.
//
// The receipt used to be described twice: once as a Flutter widget tree
// (`_ReceiptPaper` in `billing_screen.dart`) and again as a `pdf` widget tree
// (`generateReceiptPdfBytes` here). Nothing tied them together, so they drifted
// until the customer saw two different documents for the same sale.
//
// This file owns the data and the print layout, and the on-screen preview
// feeds the same [ReceiptData], so the two agree by construction.

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/currency.dart';

/// One line of the itemised table.
class ReceiptLine {
  final String name;
  final String qty;
  final String unitPrice;
  final String total;
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });
}

/// Everything the receipt renders, with no formatting decisions left in it.
///
/// The preview and the PDF both build this first, so they cannot disagree about
/// what a sale contains.
class ReceiptData {
  final String storeName;
  final String date;
  final String receiptNo;
  final String metaLine;
  final String customerName;
  final List<ReceiptLine> items;
  final String total;
  final String paid;
  final bool isDue;
  final String dueValue;
  final String footer;

  const ReceiptData({
    required this.storeName,
    required this.date,
    required this.receiptNo,
    required this.metaLine,
    required this.customerName,
    required this.items,
    required this.total,
    required this.paid,
    required this.isDue,
    required this.dueValue,
    required this.footer,
  });
}

/// 80mm thermal-roll width, the format a real shop printer expects.
const double kReceiptWidthMm = 80.0;

/// Page margin on all four sides.
const double kReceiptMarginMm = 6.0;

/// Longer than this and the receipt stops being a till receipt: it gets a full
/// A4 sheet and paginates, instead of one absurdly long strip of paper.
const double kReceiptTallMm = 297.0;

const _kRegular = 'assets/fonts/Inter-Regular.ttf';
const _kBold = 'assets/fonts/Inter-Bold.ttf';

/// Receipt palette, shared with the on-screen preview and
/// `design/foam-shop-receipt-report-mockup.html`.
class ReceiptPalette {
  final PdfColor tealDark = PdfColor.fromHex('#0B4E49');
  final PdfColor ink = PdfColor.fromHex('#1B1F1E');
  final PdfColor inkSoft = PdfColor.fromHex('#5A5F5E');
  final PdfColor inkFaint = PdfColor.fromHex('#8A8F8E');
  final PdfColor border = PdfColor.fromHex('#E3E1DC');
  final PdfColor tintSalesBg = PdfColor.fromHex('#EAF3F1');
  /// Zebra stripe for the itemised table. Kept as its own hex rather than an
  /// alpha of [tintSalesBg] so the band is predictable on a thermal printer,
  /// where a translucent fill can come out muddy or vanish entirely.
  final PdfColor tintRowBg = PdfColor.fromHex('#F5F8F7');

  final PdfColor tintSalesFg = PdfColor.fromHex('#0F6B64');
  final PdfColor tintProfitBg = PdfColor.fromHex('#EAF3EC');
  final PdfColor tintProfitFg = PdfColor.fromHex('#2E6B4E');
  final PdfColor tintExpenseBg = PdfColor.fromHex('#FBEBE8');
  final PdfColor tintExpenseFg = PdfColor.fromHex('#B54A38');
  final PdfColor white = PdfColors.white;
}

Future<pw.ThemeData> _loadReceiptTheme() async {
  // The built-in PDF fonts (Helvetica et al.) are WinAnsi-only: the receipt's
  // `✓` and `·` render as blank boxes or mojibake, and the `pdf` package prints a
  // "Helvetica has no Unicode support" warning on every run. Inter is already
  // bundled and is the same family the on-screen preview uses.
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

/// Builds the receipt body as a widget that can be both measured and painted.
///
/// This is the single layout definition. The page height is derived by
/// measuring *this* widget rather than from a hand-maintained sum of paddings
/// and font sizes, which is what previously drifted out of sync with the real
/// layout and left receipts either clipped or trailing a mostly blank sheet.
pw.Widget _buildReceipt(ReceiptData d, ReceiptPalette p) {
  // Small-caps labels. `letterSpacing` is what makes an 80mm roll read as a
  // designed document rather than a default print-out: the wide tracking gives
  // the tiny type a label-like texture that survives thermal printing.
  pw.TextStyle labelStyle(PdfColor c) => pw.TextStyle(
        fontSize: 6.2,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.7,
        color: c,
      );

  pw.Widget metaCell(String label, String value, {bool end = false}) =>
      pw.Column(
        crossAxisAlignment:
            end ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: labelStyle(p.inkFaint)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            textAlign: end ? pw.TextAlign.right : pw.TextAlign.left,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: p.ink,
            ),
          ),
        ],
      );

  pw.Widget th(String t, {bool end = false}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Text(
          t,
          textAlign: end ? pw.TextAlign.right : pw.TextAlign.left,
          style: labelStyle(p.inkFaint),
        ),
      );

  // Item names are free text and routinely overflow the 80mm column, which
  // pushed the money columns off the right edge. Eliding with `maxLines: 2`
  // keeps a long name readable over two lines while guaranteeing the table's
  // right-hand column can never be pushed out of the printable area.
  pw.Widget td(String v, {bool end = true, bool bold = false, int maxLines = 1}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4.5),
        child: pw.Text(
          v,
          textAlign: end ? pw.TextAlign.right : pw.TextAlign.left,
          maxLines: maxLines,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            fontSize: 8.5,
            lineSpacing: 1.2,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: p.ink,
          ),
        ),
      );

  // Alternating row tint. On a thermal print this is what actually carries the
  // grouping: a hairline rule disappears at low DPI, a faint band does not.
  pw.TableRow itemRow(ReceiptLine i, int index) => pw.TableRow(
        decoration: index.isOdd
            ? pw.BoxDecoration(color: p.tintRowBg)
            : null,
        children: [
          td(i.name, end: false, bold: true, maxLines: 2),
          td(i.qty),
          td(i.unitPrice),
          td(i.total, bold: true),
        ],
      );

  pw.Widget totalRow(String label, String value, {bool grand = false}) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: grand ? 3 : 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: grand ? 10.5 : 8.5,
                fontWeight: grand ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: grand ? p.tintSalesFg : p.inkSoft,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: grand ? 10.5 : 8.5,
                fontWeight: grand ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: grand ? p.tintSalesFg : p.ink,
              ),
            ),
          ],
        ),
      );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      // Branded header. A solid teal block with the store name reversed out of
      // it is the single strongest signal that this is a real till receipt, and
      // it survives greyscale thermal printing where fine hairlines do not.
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(10, 10, 10, 9),
        decoration: pw.BoxDecoration(
          color: p.tealDark,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              d.storeName,
              textAlign: pw.TextAlign.center,
              maxLines: 2,
              style: pw.TextStyle(
                fontSize: 13.5,
                lineSpacing: 1.15,
                fontWeight: pw.FontWeight.bold,
                color: p.white,
              ),
            ),
            pw.SizedBox(height: 3),
            // A rule under the name, in the light tint, gives the block an
            // internal structure so the two lines do not read as one blob.
            pw.Container(width: 26, height: 0.7, color: p.tintSalesBg),
            pw.SizedBox(height: 3),
            pw.Text(
              'DIGITAL REGISTER',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 6.2,
                letterSpacing: 1.1,
                color: p.tintSalesBg,
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 9),
      // Date / receipt number.
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: metaCell('DATE', d.date)),
          pw.SizedBox(width: 8),
          metaCell('RECEIPT #', d.receiptNo, end: true),
        ],
      ),

      if (d.metaLine.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          d.metaLine,
          style: pw.TextStyle(fontSize: 7, color: p.inkFaint),
        ),
      ],

      pw.SizedBox(height: 9),
      pw.Container(height: 0.6, color: p.border),
      pw.SizedBox(height: 8),

      // Customer. Given the same small-caps label treatment as DATE / RECEIPT
      // so the top of the receipt scans as three labelled facts.
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: pw.BoxDecoration(
          color: p.tintRowBg,
          borderRadius: pw.BorderRadius.circular(5),
          border: pw.Border.all(color: p.border, width: 0.5),
        ),
        child: pw.Row(
          children: [
            pw.Text('CUSTOMER', style: labelStyle(p.inkFaint)),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Text(
                d.customerName,
                textAlign: pw.TextAlign.right,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: p.ink,
                ),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 9),

      // Itemised table. A real column table, not stacked label/value lines, so
      // qty, price and total can be scanned down the columns. The heavy rule
      // under the header row is what separates "what you bought" from the
      // metadata above it.
      pw.Table(
        border: pw.TableBorder.symmetric(
          inside: pw.BorderSide(color: p.border, width: 0.4),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.9),
          1: pw.FlexColumnWidth(1.0),
          2: pw.FlexColumnWidth(1.6),
          3: pw.FlexColumnWidth(1.8),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: p.ink, width: 1),
              ),
            ),
            children: [
              th('ITEM', end: false),
              th('QTY'),
              th('PRICE'),
              th('TOTAL'),
            ],
          ),
          for (final (index, i) in d.items.indexed) itemRow(i, index),
        ],
      ),
      pw.SizedBox(height: 10),
      // Totals card. The currency symbol appears exactly once, here, rather
      // than repeated in every PRICE/TOTAL cell (it used to render as
      // "Rs Rs 25,500" and overflow the narrow columns).
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: pw.BoxDecoration(
          color: p.tintSalesBg,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            totalRow('Amount', d.total),
            totalRow('Paid', d.paid),
            pw.SizedBox(height: 4),
            pw.Container(height: 0.6, color: p.tintSalesFg),
            pw.SizedBox(height: 4),
            totalRow(
              d.isDue ? 'Balance Due' : 'Balance',
              d.dueValue,
              grand: true,
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 8),

      // Status pill. This is the one thing a customer scans for, so it gets a
      // solid filled treatment for "paid" and a tinted one for "due" — the
      // difference has to be legible from arm's length on a scrap of paper.
      pw.Center(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            color: d.isDue ? p.tintExpenseBg : p.tintSalesFg,
            borderRadius: pw.BorderRadius.circular(9),
          ),
          child: pw.Text(
            d.isDue ? 'BALANCE DUE' : 'PAID IN FULL',
            style: pw.TextStyle(
              fontSize: 7,
              letterSpacing: 0.7,
              fontWeight: pw.FontWeight.bold,
              color: d.isDue ? p.tintExpenseFg : p.white,
            ),
          ),
        ),
      ),
      pw.SizedBox(height: 12),

      // A dashed tear line, the way a thermal roll is actually separated. A
      // solid rule here printed as a hard edge across the paper and looked like
      // a mistake; dashes read as "cut here".
      pw.Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            pw.Expanded(
              child: pw.Container(
                height: 0.6,
                decoration: pw.BoxDecoration(
                  color: p.border,
                  borderRadius: pw.BorderRadius.circular(1),
                ),
              ),
            ),
            if (i < 2) pw.SizedBox(width: 4),
          ],
        ],
      ),
      pw.SizedBox(height: 9),

      pw.Center(
        child: pw.Text(
          'Thank you for your business!',
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: p.tintSalesFg,
          ),
        ),
      ),
      if (d.footer.isNotEmpty) ...[
        pw.SizedBox(height: 2.5),
        pw.Center(
          child: pw.Text(
            d.footer,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 7, color: p.inkFaint),
          ),
        ),
      ],
    ],
  );
}

/// Renders [data] to PDF bytes.
///
/// The page is exactly as tall as the receipt needs: the body is measured with
/// `pw.Widget.measure` at the real content width, and the page height is that
/// measurement plus the margins.
///
/// Measuring is the whole point. The previous implementation carried a
/// hand-maintained sum of every padding and font size that silently drifted
/// from the actual layout — it under-shot, so `MultiPage` pushed the totals and
/// footer onto a second sheet, and before that a hardcoded 297mm left short
/// receipts trailing a mostly blank page.
///
/// A receipt taller than [kReceiptTallMm] is a bulk order rather than a till
/// receipt, so it is given a full A4 sheet and paginates normally.
Future<Uint8List> generateReceiptPdf(ReceiptData data) async {
  // Load the theme once. The measuring pass and the painting pass must agree on
  // it — see the comment on [measureContext] below.
  final theme = await _loadReceiptTheme();
  final pdf = pw.Document(
    title: 'Receipt ${data.receiptNo}',
    author: data.storeName,
    theme: theme,
  );
  final palette = ReceiptPalette();

  final margin = kReceiptMarginMm * PdfPageFormat.mm;
  final contentWidth = kReceiptWidthMm * PdfPageFormat.mm - (margin * 2);

  // Measure the body against a tall throwaway page, then size the real page to
  // the result. This is what removes the hand-maintained height arithmetic that
  // used to drift out of sync with the real layout.
  //
  // `Widget.measure` needs a page *and* a graphics canvas, so the probe page is
  // really added to a throwaway document; only its size is read.
  final probeDoc = pw.Document(theme: theme);
  probeDoc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        kReceiptWidthMm * PdfPageFormat.mm,
        4000 * PdfPageFormat.mm,
        marginAll: margin,
      ),
      build: (_) => _buildReceipt(data, palette),
    ),
  );
  final probePage = probeDoc.document.page(0)!;

  // `Widget.measure` builds its own `Context` that inherits `ThemeData.base()`
  // — the WinAnsi Helvetica defaults — unless a context is supplied. Left to
  // its own devices it therefore measured every string with Helvetica metrics
  // while the page was actually painted in Inter, and Inter's wider letterforms
  // and larger line height meant the real body was TALLER than the measurement.
  // The page was sized to the short number, so the overflow fell off the bottom
  // and the footer and tear line silently vanished from the saved file.
  //
  // Handing it a context that inherits the real theme makes the measurement and
  // the paint use identical font metrics, so the height is the true height.
  final measureContext = pw.Context(
    document: pdf.document,
    page: probePage,
    canvas: probePage.getGraphics(),
  ).inheritFromAll([theme]);

  final measured = pw.Widget.measure(
    _buildReceipt(data, palette),
    context: measureContext,
    constraints: pw.BoxConstraints(maxWidth: contentWidth),
  ).y;

  // A couple of points of headroom absorbs sub-point rounding in the
  // measurement so the last line can never kiss the page edge.
  final heightMm = ((measured + (margin * 2) + 4) / PdfPageFormat.mm)
      .clamp(40.0, 2000.0);

  if (heightMm <= kReceiptTallMm) {
    // Fits a normal roll: one page, sized to the content.
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          kReceiptWidthMm * PdfPageFormat.mm,
          heightMm * PdfPageFormat.mm,
          marginAll: margin,
        ),
        build: (_) => _buildReceipt(data, palette),
      ),
    );
  } else {
    // Bulk order: A4, paginated, so nothing is ever dropped.
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [_buildReceipt(data, palette)],
      ),
    );
  }

  return pdf.save();
}

/// Formats a sale into the shared [ReceiptData] that the preview and the PDF
/// both render, so the two can never disagree about the same sale.
ReceiptData buildReceiptData({
  required String storeName,
  required String receiptId,
  required String date,
  required String customerName,
  required List<ReceiptLine> items,
  required double totalAmount,
  required double paidAmount,
  required double remainingBalance,
  String location = '',
  String phone = '',
  String currencyCode = 'PKR',
}) {
  final fmt = NumberFormat('#,##0');
  final csym = currencySymbolFromCode(currencyCode);
  String money(double v) => '$csym ${fmt.format(v.toInt())}';

  final isDue = remainingBalance > 0;
  return ReceiptData(
    storeName: storeName,
    date: date,
    receiptNo: receiptId,
    metaLine: [
      if (location.isNotEmpty) location,
      if (phone.isNotEmpty) phone,
    ].join(' \u00b7 '),
    customerName: customerName,
    items: items,
    total: money(totalAmount),
    paid: money(paidAmount),
    isDue: isDue,
    // Overpayment is change, not a negative balance, so never print a minus.
    dueValue: isDue ? money(remainingBalance) : money(0),
    footer: location.isNotEmpty ? '$storeName \u00b7 $location' : storeName,
  );
}
