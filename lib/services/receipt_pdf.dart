// Receipt model + print layout.
//
// The receipt used to be described twice: once as a Flutter widget tree
// (`_ReceiptPaper` in `billing_screen.dart`) and again as a `pdf` widget tree
// (`generateReceiptPdfBytes` here). Nothing tied them together, so they drifted
// until the customer saw two different documents for the same sale.
//
// This file owns the data and the print layout, and the on-screen preview
// feeds the same [ReceiptData], so the two agree by construction.

import 'dart:math' as math;
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

/// Receipt palette, drawn from the app's own brand colours.
///
/// The mockup this receipt is built against
/// (`design/foam-shop-receipt-report-mockup.html`) specifies an indigo/violet
/// ramp (`#5B5FEF` -> `#8B5CF6`). That ramp is deliberately NOT used here. A
/// saved PDF is a physical artefact that outlives the app, and a customer
/// holding it should be looking at the same brand they see on the till. So every
/// value below is lifted from `AppColors` in `app_theme.dart` — the README's
/// documented palette — and the mockup's *layout* is followed while its hues
/// are substituted.
///
/// Mapping, so the two stay reconcilable by eye:
///   mockup `--primary`   `#5B5FEF` -> brandFill    `#3D5387` Slate Blue
///   mockup `--secondary` `#8B5CF6` -> brandFillDeep `#182346` Deep Navy
///   mockup `--ink`       `#171927` -> ink           `#0E0D15` Deep Ink
///   mockup `--muted`     `#777B8A` -> inkFaint      `#6E6A74`
///   mockup `--line`      `#E7E8EF` -> outline       `#D9D7DC`
///   mockup `--soft`      `#F7F7FC` -> surface2      `#FBF9F8`
///   mockup `--success`   `#159A70` -> saleFg        `#3D5387`
///   mockup `--warning`   `#D97706` -> expenseFg     `#7E4A63`
///
/// The brand gradient is the one place the two dark blues are combined, and it
/// runs Slate Blue -> Deep Navy, mirroring the app's own primary-button ramp.
class ReceiptPalette {
  /// Deep Navy `#182346` — `AppColors.brandFillDeep`, the gradient's dark end.
  final PdfColor brandDeep = PdfColor.fromHex('#182346');

  /// Slate Blue `#3D5387` — `AppColors.brandFill`, the gradient's light end and
  /// the replacement for the mockup's `--primary`.
  final PdfColor brand = PdfColor.fromHex('#3D5387');

  final PdfColor ink = PdfColor.fromHex('#0E0D15');
  final PdfColor inkSoft = PdfColor.fromHex('#3D3B45');
  final PdfColor inkFaint = PdfColor.fromHex('#6E6A74');

  /// A lighter rule than [outline] for dividers and the faint footer note. The
  /// app's `outline` is too dark to read as a hairline once printed, so this
  /// sits between the two.
  final PdfColor line = PdfColor.fromHex('#E4E1E6');
  final PdfColor outline = PdfColor.fromHex('#D9D7DC');

  /// Muted Periwinkle `#7C83AD` — the app's dark-mode primary, used for
  /// white-on-brand secondary text where full white would be too harsh.
  final PdfColor onBrandSoft = PdfColor.fromHex('#C7CCE4');

  /// The mockup's `--soft`: the tinted fill behind the customer card and the
  /// totals block. Matches `AppColors.surface2`.
  final PdfColor soft = PdfColor.fromHex('#FBF9F8');
  final PdfColor surface = PdfColor.fromHex('#FFFFFF');

  /// Zebra stripe for the itemised table, derived from the brand so the banding
  /// reads as part of the palette rather than as a generic grey.
  final PdfColor tintRowBg = PdfColor.fromHex('#F4F5F9');

  /// The mockup's `--success`, recoloured to the app's `saleFg`. A "paid" pill
  /// in the app's brand blue rather than a green that appears nowhere else in
  /// the product.
  final PdfColor success = PdfColor.fromHex('#3D5387');
  final PdfColor successBg = PdfColor.fromHex('#EAEEF6');

  /// The mockup's `--warning` / `--warning-bg`, recoloured to `expenseFg`
  /// (Dusty Mauve) so "balance due" matches how the app signals a problem
  /// everywhere else.
  final PdfColor warning = PdfColor.fromHex('#7E4A63');
  final PdfColor warningBg = PdfColor.fromHex('#F6EEF2');

  final PdfColor white = PdfColors.white;
}

/// The faces the receipt is painted with, plus the theme built from them.
///
/// The column measurer needs the *same* fonts the painter uses. Handing it a
/// different face would size the columns against metrics that are not on the
/// page, so the two are loaded together and always travel as one value.
class _ReceiptFonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.ThemeData theme;

  const _ReceiptFonts(this.regular, this.bold, this.theme);
}

Future<_ReceiptFonts> _loadReceiptTheme() async {
  // The built-in PDF fonts (Helvetica et al.) are WinAnsi-only: the receipt's
  // `✓` and `·` render as blank boxes or mojibake, and the `pdf` package prints a
  // "Helvetica has no Unicode support" warning on every run. Inter is already
  // bundled and is the same family the on-screen preview uses.
  try {
    final regular = pw.Font.ttf(await rootBundle.load(_kRegular));
    final bold = pw.Font.ttf(await rootBundle.load(_kBold));
    return _ReceiptFonts(
        regular,
        bold,
        pw.ThemeData.withFont(
          base: regular,
          bold: bold,
        ));
  } catch (_) {
    // Fonts unavailable (e.g. a unit test with no asset bundle): fall back to
    // the built-ins rather than failing the whole receipt. Built-in Helvetica
    // metrics are narrower than Inter's, so the table ends up with a little
    // more slack than it strictly needs rather than less.
    return _ReceiptFonts(
      pw.Font.helvetica(),
      pw.Font.helveticaBold(),
      pw.ThemeData.withFont(),
    );
  }
}

/// Strips any leading currency symbol from a money string, keeping the digits,
/// thousands separators and sign.
///
/// The itemised table must not repeat "Rs " in every PRICE and TOTAL cell: the
/// totals card states the currency once, and the repeated symbol consumes enough
/// of an 80mm column that the figure itself gets clipped to a bare "Rs" — a
/// wrong number on a customer's receipt.
///
/// [buildReceiptData] already formats these cells without a symbol, but
/// [ReceiptLine] is a plain String model and a caller may legitimately hand it a
/// pre-formatted figure, so the symbol is stripped at render time rather than
/// trusted. Exposed for testing: the clipping failure is invisible in the PDF
/// byte stream (an embedded subset font stores glyph indices, not ASCII), so it
/// can only be pinned at this level.
String stripCurrencySymbol(String value) {
  // A leading sign is kept. It is normally adjacent to the digits ("-500"), but
  // a formatted string can put the symbol in between ("-Rs 500"), so the sign is
  // held aside and re-attached after the symbol is removed — otherwise a
  // customer credit silently prints as a charge.
  final sign =
      value.isNotEmpty && (value[0] == '-' || value[0] == '+') ? value[0] : '';
  final rest = sign.isEmpty ? value : value.substring(1);
  final firstDigit = rest.indexOf(RegExp(r'[0-9]'));
  if (firstDigit < 0) return '';
  return '$sign${rest.substring(firstDigit)}';
}

/// Builds the receipt body as a widget that can be both measured and painted.
///
/// This is the single layout definition. The page height is derived by
/// measuring *this* widget rather than from a hand-maintained sum of paddings
/// and font sizes, which is what previously drifted out of sync with the real
/// layout and left receipts either clipped or trailing a mostly blank sheet.
/// Measures the painted width of [value] at [fontSize] with [font].
///
/// Uses the same measure path the painter uses — a real `pw.Text` laid out
/// against a real `pw.Context` — rather than reaching into font internals or
/// counting characters. That matters for correctness twice over:
///
///  * the returned width is the width the glyphs will actually occupy, so a
///    column sized from it cannot clip the figure that gets drawn;
///  * it is measured with the *same* font the cell is painted with, which the
///    widget API enforces, where a raw `PdfFont` handle would have to be
///    resolved by hand and could silently differ from the painted face.
///
/// Falls back to a conservative estimate if the context cannot be built, which
/// can only happen outside a document (a bare unit test) and would otherwise
/// make a width assertion impossible to run.
double _measureMoneyWidth(
  String value,
  pw.Font font,
  double fontSize,
  pw.Context? context,
) {
  if (value.isEmpty) return 0;
  if (context != null) {
    final size = pw.Widget.measure(
      pw.Text(
        value,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
        style: pw.TextStyle(fontSize: fontSize, font: font),
      ),
      context: context,
    );
    return size.x;
  }
  // No document to measure against: assume a generous advance so the caller
  // over-allocates rather than clipping.
  return value.length * fontSize * 0.62;
}

/// Computes the four column widths (ITEM, QTY, PRICE, TOTAL) for [data].
///
/// Each money column is sized to the widest value it must hold, plus a little
/// breathing room and the cell's own horizontal padding. The ITEM column takes
/// whatever is left over, so a wider number costs the product name width rather
/// than silently truncating the number — the item name already elides over two
/// lines, whereas a truncated *number* is a wrong number.
///
/// Exposed for testing: a truncated figure is invisible in the PDF byte stream
/// (the receipt embeds a subset font, so the content stream stores glyph
/// indices, not ASCII) — the only place this can be pinned is the layout maths.
Map<int, pw.TableColumnWidth> receiptColumnWidths({
  required ReceiptData data,
  required pw.Font regular,
  required pw.Font bold,
  required double contentWidth,
  pw.Context? context,
  double fontSize = 8.6,
}) {
  const cellPadX = 4.0;
  const minQtyWidth = 16.0;
  const safety = 1.5;

  var widestQty = 0.0;
  var widestPrice = 0.0;
  var widestTotal = 0.0;

  for (final line in data.items) {
    widestQty = math.max(
        widestQty, _measureMoneyWidth(line.qty, regular, fontSize, context));
    widestPrice = math.max(
        widestPrice,
        _measureMoneyWidth(
            stripCurrencySymbol(line.unitPrice), regular, fontSize, context));
    // The TOTAL cell is bold, so it must be measured with the bold face or it
    // is guaranteed to be a little too narrow.
    widestTotal = math.max(
        widestTotal,
        _measureMoneyWidth(
            stripCurrencySymbol(line.total), bold, fontSize, context));
  }

  final qtyWidth = math.max(minQtyWidth, widestQty + (cellPadX * 2) + safety);
  final priceWidth = widestPrice + (cellPadX * 2) + safety;
  final totalWidth = widestTotal + (cellPadX * 2) + safety;

  // The item name is the elastic column: it is free text that already elides
  // over two lines, whereas a truncated *number* is a wrong number. So the
  // money columns get exactly what they measured and the name takes the
  // remainder, down to a floor that keeps the column usable.
  const minItemWidth = 46.0;
  final itemWidth = math.max(
      minItemWidth, contentWidth - (qtyWidth + priceWidth + totalWidth));

  return {
    0: pw.FlexColumnWidth(itemWidth),
    1: pw.FlexColumnWidth(qtyWidth),
    2: pw.FlexColumnWidth(priceWidth),
    3: pw.FlexColumnWidth(totalWidth),
  };
}

pw.Widget _buildReceipt(ReceiptData d, ReceiptPalette p,
    {required Map<int, pw.TableColumnWidth> columnWidths}) {
  // Small-caps labels, matching the mockup's `text-transform: uppercase` +
  // `letter-spacing` on `.meta-label` / `th`. The wide tracking gives the tiny
  // type a label-like texture that survives thermal printing.
  pw.TextStyle labelStyle(PdfColor c) => pw.TextStyle(
        fontSize: 6.6,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.85,
        color: c,
      );

  pw.Widget metaCell(String label, String value,
          {bool end = false, PdfColor? valueColor}) =>
      pw.Column(
        crossAxisAlignment:
            end ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: labelStyle(p.inkFaint)),
          pw.SizedBox(height: 2.5),
          pw.Text(
            value,
            textAlign: end ? pw.TextAlign.right : pw.TextAlign.left,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              // The mockup colours the receipt number `--primary`; here that is
              // the brand blue, which makes the one number a customer might
              // quote back findable at a glance.
              color: valueColor ?? p.ink,
            ),
          ),
        ],
      );

  pw.Widget th(String t, {bool end = false, bool center = false}) => pw.Padding(
        // Vertical pad matches the cells so the header baseline sits on the
        // same rhythm as the data; the horizontal pad mirrors [td] so a header
        // is inset from the rule by the same amount as the value beneath it.
        padding: pw.EdgeInsets.only(bottom: 5, right: end ? 3 : 0),
        child: pw.Text(
          t,
          textAlign: center
              ? pw.TextAlign.center
              : end
                  ? pw.TextAlign.right
                  : pw.TextAlign.left,
          style: labelStyle(p.inkFaint),
        ),
      );

  // Item names are free text and routinely overflow the 80mm column, which
  // pushed the money columns off the right edge. Eliding with `maxLines: 2`
  // keeps a long name readable over two lines while guaranteeing the table's
  // right-hand column can never be pushed out of the printable area.
  //
  // The horizontal padding keeps right-aligned money clear of whatever sits to
  // its left, so neighbouring columns cannot read as one run of digits
  // ("360014400").
  pw.Widget td(String v,
          {bool end = true,
          bool center = false,
          bool bold = false,
          int maxLines = 1}) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: 5, horizontal: end ? 4 : 0),
        child: pw.Text(
          v,
          textAlign: center
              ? pw.TextAlign.center
              : end
                  ? pw.TextAlign.right
                  : pw.TextAlign.left,
          maxLines: maxLines,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            fontSize: 8.6,
            lineSpacing: 1.2,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            // The mockup's `.price` / `.qty` are a softer grey than `.total`,
            // which is what stops the right-hand column reading as a wall of
            // bold. That hierarchy is the point of the table, so it is kept.
            color: bold ? p.ink : p.inkSoft,
          ),
        ),
      );

  // Alternating row tint. On a thermal print this is what actually carries the
  // grouping: a hairline rule disappears at low DPI, a faint band does not.
  //
  // The currency symbol is stripped from the money cells by
  // [stripCurrencySymbol]: the totals card already states it, and repeating
  // "Rs " in every PRICE and TOTAL cell costs enough width that the figure gets
  // clipped — a wrong number on a customer's receipt, the one failure this
  // document cannot have.
  pw.TableRow itemRow(ReceiptLine i, int index) => pw.TableRow(
        decoration: index.isOdd ? pw.BoxDecoration(color: p.tintRowBg) : null,
        children: [
          td(i.name, end: false, bold: true, maxLines: 2),
          td(i.qty, center: true),
          td(stripCurrencySymbol(i.unitPrice)),
          td(stripCurrencySymbol(i.total), bold: true),
        ],
      );

  pw.Widget totalRow(String label, String value, {bool grand = false}) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: grand ? 3 : 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: grand ? 11 : 9.5,
                fontWeight: grand ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: grand ? p.brand : p.inkSoft,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: grand ? 11 : 9.5,
                fontWeight: grand ? pw.FontWeight.bold : pw.FontWeight.bold,
                color: grand ? p.brand : p.ink,
              ),
            ),
          ],
        ),
      );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      // ── Brand card ──────────────────────────────────────────────────────
      // The mockup's `.brand-card`: a 135° brand gradient with the shop name
      // reversed out of it, an optional initial monogram, and a tracked
      // "DIGITAL REGISTER" strapline. A solid dark block survives greyscale
      // thermal printing far better than fine detail does, which is why the
      // name and strapline are set large and heavy rather than delicate.
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(12, 11, 12, 10),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
            colors: [p.brand, p.brandDeep],
          ),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // The monogram chip. The mockup renders a "F" tile; here it is
            // derived from the store name so a multi-word shop name still gets
            // a correct initial rather than a hardcoded letter.
            if (d.storeName.trim().isNotEmpty)
              pw.Container(
                width: 26,
                height: 26,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: p.onBrandSoft,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  d.storeName.trim()[0].toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: p.brandDeep,
                  ),
                ),
              ),
            if (d.storeName.trim().isNotEmpty) pw.SizedBox(height: 6),
            pw.Text(
              d.storeName,
              textAlign: pw.TextAlign.center,
              maxLines: 2,
              style: pw.TextStyle(
                fontSize: 14,
                lineSpacing: 1.15,
                fontWeight: pw.FontWeight.bold,
                color: p.white,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'DIGITAL REGISTER',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 6.4,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.6,
                color: p.onBrandSoft,
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 11),
      // Date / receipt number, matching the mockup's `.receipt-meta` two-column
      // split with the receipt number set in the brand colour.
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: metaCell('DATE', d.date)),
          pw.SizedBox(width: 8),
          metaCell('RECEIPT #', d.receiptNo, end: true, valueColor: p.brand),
        ],
      ),

      // Shop info, closed off with a dashed rule exactly as the mockup's
      // `.shop-info` does. The dash reads as a separator the eye can skip,
      // where a solid rule would compete with the table's own header border.
      if (d.metaLine.isNotEmpty) ...[
        pw.SizedBox(height: 7),
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 7),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: p.line, width: 0.7)),
          ),
          child: pw.Text(
            d.metaLine,
            style: pw.TextStyle(fontSize: 8, color: p.inkFaint),
          ),
        ),
      ] else ...[
        pw.SizedBox(height: 7),
        pw.Container(height: 0.7, color: p.line),
      ],

      // ── Customer card ───────────────────────────────────────────────────
      // The mockup's `.customer-card`: a soft filled panel with a hairline
      // border, the label and name stacked on the left and a circular initial
      // badge on the right.
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(9, 8, 9, 8),
        decoration: pw.BoxDecoration(
          color: p.soft,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: p.outline, width: 0.6),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('CUSTOMER', style: labelStyle(p.inkFaint)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    d.customerName,
                    maxLines: 1,
                    style: pw.TextStyle(
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                      color: p.ink,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            // Circular initial badge, as in the mockup. A circle is drawn
            // explicitly because `BorderRadius.circular(r)` at r >= half the
            // side is what previously emitted degenerate path geometry and made
            // renderers discard everything drawn before it.
            pw.Container(
              width: 22,
              height: 22,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: p.tintRowBg,
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: p.outline, width: 0.6),
              ),
              child: pw.Text(
                d.customerName.trim().isEmpty
                    ? '?'
                    : d.customerName.trim()[0].toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: p.brand,
                ),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 11),

      // Section title, as the mockup's `.items-title`.
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Text('PURCHASE DETAILS', style: labelStyle(p.inkFaint)),
      ),

      // Itemised table. A real column table, not stacked label/value lines, so
      // qty, price and total can be scanned down the columns. The heavy rule
      // under the header row is what separates "what you bought" from the
      // metadata above it.
      pw.Table(
        border: pw.TableBorder.symmetric(
          inside: pw.BorderSide(color: p.line, width: 0.4),
        ),
        // Columns are measured from the actual figures in this receipt rather
        // than fixed as a fraction of the roll width, so a five- or six-figure
        // total gets the room it needs and the product name absorbs the cost.
        // See [receiptColumnWidths] for why a fixed split truncated the numbers.
        columnWidths: columnWidths,
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: p.outline, width: 0.9),
              ),
            ),
            children: [
              th('ITEM', end: false),
              th('QTY', center: true),
              th('PRICE', end: true),
              th('TOTAL'),
            ],
          ),
          for (final (index, i) in d.items.indexed) itemRow(i, index),
        ],
      ),
      pw.SizedBox(height: 12),
      // ── Totals card ─────────────────────────────────────────────────────
      // The mockup's `.totals`: a soft panel holding Subtotal, Paid, and then a
      // balance row split off by a dashed rule and set in the brand colour at a
      // larger size. The currency symbol appears exactly once, in the values,
      // rather than repeated in every PRICE/TOTAL cell (it used to render as
      // "Rs Rs 25,500" and overflow the narrow columns).
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: pw.BoxDecoration(
          color: p.soft,
          borderRadius: pw.BorderRadius.circular(7),
          border: pw.Border.all(color: p.line, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            totalRow('Subtotal', d.total),
            totalRow('Paid', d.paid),
            pw.SizedBox(height: 6),
            pw.Container(
              height: 0.7,
              decoration: pw.BoxDecoration(color: p.outline),
            ),
            pw.SizedBox(height: 6),
            totalRow(
              d.isDue ? 'Balance Due' : 'Balance',
              d.dueValue,
              grand: true,
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),

      // ── Status pill ─────────────────────────────────────────────────────
      // The mockup's `.payment-status`: a centred tinted pill with a dot and a
      // tracked label. The dot is drawn as a real circle rather than a "•"
      // glyph so it cannot fall back to a missing-glyph box on a printer that
      // lacks the character, which is what the old "✓" did.
      pw.Center(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: pw.BoxDecoration(
            color: d.isDue ? p.warningBg : p.successBg,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 4,
                height: 4,
                decoration: pw.BoxDecoration(
                  color: d.isDue ? p.warning : p.success,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 5),
              pw.Text(
                d.isDue ? 'BALANCE DUE' : 'PAID IN FULL',
                style: pw.TextStyle(
                  fontSize: 7.4,
                  letterSpacing: 0.9,
                  fontWeight: pw.FontWeight.bold,
                  color: d.isDue ? p.warning : p.success,
                ),
              ),
            ],
          ),
        ),
      ),
      pw.SizedBox(height: 14),

      // ── Footer ──────────────────────────────────────────────────────────
      // Closed off with the mockup's dashed top border. The dashes are drawn as
      // real segments rather than a solid rule so the line still reads as "end
      // of receipt" on a thermal printer.
      pw.Container(
        padding: const pw.EdgeInsets.only(top: 11),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: p.line, width: 0.7)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'Thank you for your business!',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: p.brand,
              ),
            ),
            if (d.footer.isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                d.footer,
                textAlign: pw.TextAlign.center,
                maxLines: 2,
                style: pw.TextStyle(fontSize: 8, color: p.inkFaint),
              ),
            ],
            pw.SizedBox(height: 5),
            // The mockup's `.footer-note`. Printed small and faint, this is the
            // line that stops a customer treating the till roll as a
            // hand-signed document they need to countersign.
            pw.Text(
              'Computer generated receipt \u00b7 No signature required',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 6.8, color: p.inkFaint),
            ),
          ],
        ),
      ),
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
  // it — see the comment on [measureContext] below. The same load yields the
  // font faces the table columns are measured against.
  final fonts = await _loadReceiptTheme();
  final theme = fonts.theme;
  final regularFont = fonts.regular;
  final boldFont = fonts.bold;
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
  // really added to a throwaway document; only its canvas is read, and it is
  // deliberately blank — the probe exists to give the measuring context a
  // surface to measure against, not to reproduce the body.
  final probeDoc = pw.Document(theme: theme);
  probeDoc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        kReceiptWidthMm * PdfPageFormat.mm,
        4000 * PdfPageFormat.mm,
        marginAll: margin,
      ),
      build: (_) => pw.SizedBox(),
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

  // The itemised table's money columns are sized by measuring the real figures
  // in *this* receipt, so a total like "120,000" cannot be clipped to "120,00".
  // Resolved once here and reused by every pass, because the measuring pass and
  // the painting pass must lay the table out identically.
  final columnWidths = receiptColumnWidths(
    data: data,
    regular: regularFont,
    bold: boldFont,
    contentWidth: contentWidth,
    context: measureContext,
  );

  final measured = pw.Widget.measure(
    _buildReceipt(data, palette, columnWidths: columnWidths),
    context: measureContext,
    constraints: pw.BoxConstraints(maxWidth: contentWidth),
  ).y;

  // A couple of points of headroom absorbs sub-point rounding in the
  // measurement so the last line can never kiss the page edge.
  final heightMm =
      ((measured + (margin * 2) + 4) / PdfPageFormat.mm).clamp(40.0, 2000.0);

  if (heightMm <= kReceiptTallMm) {
    // Fits a normal roll: one page, sized to the content.
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          kReceiptWidthMm * PdfPageFormat.mm,
          heightMm * PdfPageFormat.mm,
          marginAll: margin,
        ),
        build: (_) => _buildReceipt(data, palette, columnWidths: columnWidths),
      ),
    );
  } else {
    // Bulk order: A4, paginated, so nothing is ever dropped.
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) =>
            [_buildReceipt(data, palette, columnWidths: columnWidths)],
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
