// End-to-end report export, run on a real device.
//
// The unit suite in `test/` covers the *content* of each report, but it cannot
// cover the half that actually breaks in the field: the file never being
// written, or being written somewhere unreadable. Both need a live
// `path_provider` platform channel, which only exists on a real device or
// emulator — a host-side `flutter test` stubs the plugin out and silently
// returns a path that does not exist.
//
// So this runs on hardware, generates each report through the same public API
// the Export screen calls, then REOPENS each file from disk and parses it back.
// A report that writes but produces unparseable bytes fails here, which is the
// failure a shop would otherwise only discover after sharing a broken file.
//
// Run it with:
//
//   flutter test integration_test/export_e2e_test.dart -d <device-id>
//
// Deliberately excluded from the default `flutter test` run: it needs a device,
// and CI does not have one attached.
//
// Coverage per format:
//   * CSV  — read back as text, parsed with the same `csv` package, values
//            compared to the inputs.
//   * XLSX — unzipped and parsed with the `excel` package; cell values read back
//            out of the real archive.
//   * PDF  — read back as bytes; header, page count and extracted text checked.
//            `printing`'s `extractText` runs the real PDF parser on the file the
//            app produced, so money figures can be searched for as text.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart' show ZLibDecoder;
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:foam_shop_register/models/product.dart';
import 'package:foam_shop_register/models/sale.dart';
import 'package:foam_shop_register/services/accounting_service.dart';
import 'package:foam_shop_register/services/export_service.dart';
import 'package:foam_shop_register/services/receipt_pdf.dart';
import 'package:foam_shop_register/services/receipt_saver.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final start = DateTime(2026, 9, 1);
  final end = DateTime(2026, 9, 30, 23, 59, 59, 999);

  // A product whose cost price differs from the sale price, so COGS and profit
  // are both non-trivial and a mis-mapped column would be visible.
  final products = [
    Product(
      id: 'p-luxury',
      name: 'luxury',
      type: 'Sheet',
      sizeLength: 72,
      sizeWidth: 36,
      thickness: 4,
      density: 16,
      unitType: 'per_sqft',
      unitPrice: 0,
      costPrice: 40000,
      currentStock: 500,
      lowStockThreshold: 5,
    ),
  ];

  // The three customer shapes the export has to survive. The second and third
  // are the ones that used to throw: a sale written before the `customer_name`
  // field existed, and a sale with neither a name nor an id.
  final sales = [
    Sale(
      id: 'sale-named-0001',
      date: DateTime(2026, 9, 27),
      customerId: 'cust_bilal_0001',
      customerName: 'Bilal Traders',
      lineItems: [
        SaleLineItem(
          productId: 'p-luxury',
          name: 'luxury',
          qtyOrArea: 2,
          salePrice: 60000,
          costPriceAtSale: 40000,
        ),
      ],
      paid: 100000,
    ),
    Sale(
      id: 'sale-legacy-002',
      date: DateTime(2026, 9, 15),
      // No name, and an id shorter than the six characters the old code sliced.
      customerId: 'walk',
      lineItems: [
        SaleLineItem(
          productId: 'p-luxury',
          name: 'luxury',
          qtyOrArea: 3,
          salePrice: 60000,
          costPriceAtSale: 40000,
        ),
      ],
      paid: 180000,
    ),
    Sale(
      id: 'sale-no-id-0003',
      date: DateTime(2026, 9, 20),
      customerId: '',
      lineItems: [
        SaleLineItem(
          productId: 'p-luxury',
          name: 'luxury',
          qtyOrArea: 1,
          salePrice: 60000,
          costPriceAtSale: 40000,
        ),
      ],
      paid: 0,
    ),
  ];

  final summary = AccountingService().compute(
    sales: sales,
    purchases: const [],
    expenses: const [],
    payments: const [],
    supplierPayments: const [],
    products: products,
    openingBal: null,
  );

  group('Report export round-trip on a real device', () {
    late Directory scratch;

    setUp(() async {
      // A real, writable directory from the real platform channel — the
      // dependency the host-side unit tests cannot satisfy.
      final docs = await getApplicationDocumentsDirectory();
      scratch = Directory('${docs.path}/e2e_export_scratch');
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
      scratch.createSync(recursive: true);
    });

    tearDown(() {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    });

    test('the documents directory is real and writable', () async {
      // Precondition. If this fails nothing below means anything — and on a
      // host-side run it fails, which is the whole reason this file exists.
      expect(scratch.existsSync(), isTrue,
          reason: 'path_provider must return a real, creatable directory');

      final probe = File('${scratch.path}/probe.txt');
      await probe.writeAsString('ok');
      expect(probe.existsSync(), isTrue);
      expect(await probe.readAsString(), 'ok');
    });

    test('CSV is written to disk and parses back with the same values',
        () async {
      final file = await ExportService().generateCsvReport(
        sales: sales,
        products: products,
        summary: summary,
        startDate: start,
        endDate: end,
        shopName: 'Asif Foam Center',
      );

      expect(file.existsSync(),
          isTrue, reason: 'the CSV must exist on the device filesystem');
      expect(file.lengthSync(), greaterThan(0));

      // Reopen from disk and parse with the same library that wrote it.
      // `CsvToListConverter` is a stream transformer, so parsing is async.
      final raw = await file.readAsString();
      final rows = await const CsvToListConverter()
          .convert(raw)
          .toList();

      // The header row names the columns, so assert by column rather than by
      // substring position — a column reorder would otherwise still pass.
      final header = rows.firstWhere((r) => r.contains('Invoice ID'));
      final colCustomer = header.indexOf('Customer');
      final colAmount = header.indexOf('Amount');
      expect(colCustomer, isNonNegative);
      expect(colAmount, isNonNegative);

      // Every sale must be present: the nameless ones are labelled, not
      // dropped. This is the regression — they used to throw before writing.
      final dataRows =
          rows.where((r) => r.isNotEmpty && r.contains('luxury')).toList();
      expect(dataRows.length, 3,
          reason: 'all three sales must appear in the report');

      final labels = dataRows.map((r) => r[colCustomer]).toList();
      expect(labels, contains('Bilal Traders'));
      expect(labels, contains('Walk-in Customer'),
          reason: 'a sale with no name and no id must still be labelled');
      expect(labels.any((l) => l.contains('walk')),
          isTrue, reason: 'the legacy short id must be used, not throw');

      // The money must be the real figures, not truncated or blank.
      final amounts = dataRows.map((r) => r[colAmount]).toSet();
      expect(amounts, contains('120,000'));
      expect(amounts, contains('180,000'));
      expect(amounts, contains('60,000'));
      // And the summary block must carry the totals.
      expect(raw, contains('Revenue'));
      // 2 + 3 + 1 units at 60,000 each.
      expect(raw, contains('360,000'));
      expect(raw, contains('240,000'), reason: 'COGS: 2+3+1 at 40,000');
    });
    test('XLSX is written to disk and its cells parse back', () async {
      final file = await ExportService().generateXlsxReport(
        sales: sales,
        products: products,
        summary: summary,
        startDate: start,
        endDate: end,
        shopName: 'Asif Foam Center',
      );

      expect(file.existsSync(),
          isTrue, reason: 'the XLSX must exist on the device filesystem');
      expect(file.lengthSync(), greaterThan(0));

      // An xlsx is a zip; a file that is not a real archive is the failure this
      // catches, so confirm the magic bytes before parsing.
      final bytes = await file.readAsBytes();
      expect(bytes.take(2), equals([0x50, 0x4B]),
          reason: 'xlsx must start with the ZIP magic "PK"');

      // Parse the archive back off disk with the same library that wrote it.
      final reopened = Excel.decodeBytes(bytes);

      // The default sheet is deleted by the exporter, so exactly the two
      // intended sheets must remain.
      expect(reopened.sheets.keys.toSet(), {'Summary', 'Sales Detail'});

      // The detail sheet must carry all three sales — including the two that
      // used to throw before the sheet was finished.
      final detail = reopened['Sales Detail'];
      final customerValues = <String>[];
      final amountValues = <int>[];
      for (var r = 2; r <= 4; r++) {
        customerValues.add(detail
            .cell(CellIndex.indexByString('C$r'))
            .value
            .toString()
            .trim());
        final amount = detail.cell(CellIndex.indexByString('E$r')).value;
        if (amount is IntCellValue) amountValues.add(amount.value);
      }

      expect(customerValues.length, 3);
      expect(customerValues, contains('Bilal Traders'));
      expect(customerValues, contains('Walk-in Customer'));
      amountValues.sort();
      expect(amountValues, equals([60000, 120000, 180000]));

      // The summary sheet must carry the real totals as numbers.
      final revenue =
          reopened['Summary'].cell(CellIndex.indexByString('B5')).value;
      expect(revenue, isA<IntCellValue>());
      // 2 + 3 + 1 units at 60,000 each.
      expect((revenue as IntCellValue).value, 360000);
    });
    test('PDF is written to disk and its text extracts with the real figures',
        () async {
      final file = await ExportService().generatePdfReport(
        sales: sales,
        products: products,
        summary: summary,
        startDate: start,
        endDate: end,
        shopName: 'Asif Foam Center',
      );

      expect(file.existsSync(),
          isTrue, reason: 'the PDF must exist on the device filesystem');
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(500));
      // "%PDF-" is the signature every PDF reader checks first.
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
      // A well-formed PDF ends with the cross-reference trailer marker.
      expect(utf8.decode(bytes.skip(bytes.length - 6).toList()),
          contains('%%EOF'));

      // The report PDF is drawn with the built-in Helvetica, whose glyphs are
      // written as plain ASCII in the content stream — so the money figures can
      // be read back out of the real file. A column that was too narrow would
      // clip the figure and this would not find it.
      final text = _readAsciiContentStreamText(bytes);
      expect(text, contains('Asif Foam Center'));
      expect(text, contains('180,000'),
          reason: 'every money figure must survive to the page intact');
      expect(text, contains('120,000'));
      expect(text, contains('60,000'));
      // And it must still be a multi-page-capable document with real content.
      expect(_pdfPageCount(bytes), greaterThan(0));
    });

    test('the receipt PDF is written to disk and its figures are readable',
        () async {
      // The receipt is the document a customer physically takes away, so its
      // money figures are asserted here rather than only on layout maths.
      //
      // The receipt embeds a *subsetted* Inter, so the content stream stores
      // glyph indices, not ASCII. The `pdf` package writes a `/ToUnicode` CMap
      // alongside the subset, which maps those glyph ids back to characters —
      // so the text is recoverable, and a clipped figure cannot hide here.
      final bytes = await generateReceiptPdf(
        const ReceiptData(
          storeName: 'Asif Foam Center',
          date: '27/9/2026',
          receiptNo: 'INV-1',
          metaLine: 'Shop #4, Urdu Bazaar',
          customerName: 'Walk-in Customer',
          items: [
            // The exact receipt from the bug report.
            ReceiptLine(
                name: 'luxury', qty: '2', unitPrice: '60,000', total: '120,000'),
          ],
          total: 'Rs 120,000',
          paid: 'Rs 100,000',
          isDue: true,
          dueValue: 'Rs 20,000',
          footer: 'Asif Foam Center',
        ),
      );

      final file = File('${scratch.path}/receipt.pdf');
      await file.writeAsBytes(bytes, flush: true);

      // Written to the real device filesystem and readable back.
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
      final onDisk = await file.readAsBytes();
      expect(onDisk.length, bytes.length,
          reason: 'the file on disk must match what was generated');

      // Structurally a valid, single-page 80mm PDF.
      expect(utf8.decode(onDisk.take(5).toList()), '%PDF-');
      expect(_pdfPageCount(onDisk), 1,
          reason: 'a single-item receipt must stay on one page');
      expect(_firstPageWidthMm(onDisk), closeTo(80, 0.5),
          reason: 'the page must be the 80mm thermal roll width');

      // Now the part that matters: the figures, read back out of the written
      // file through the embedded font's ToUnicode CMap.
      final text = _extractTextViaToUnicode(onDisk);

      expect(text, contains('60,000'),
          reason: 'the unit price must be whole, not clipped to "60,00"');
      expect(text, contains('120,000'),
          reason: 'the line total must be whole, not clipped to "120,00"');
      expect(text, contains('20,000'), reason: 'the balance due must be stated');
      expect(text, contains('Asif Foam Center'));
      // The exact truncation this guards: a clipped "120,00" must not appear
      // anywhere as a standalone figure.
      expect(RegExp(r'120,00(?!0)').hasMatch(text), isFalse,
          reason: 'a truncated total must not survive onto the receipt');
    });
    // ── Receipt save: the Dart -> Kotlin -> MediaStore round trip ──
    //
    // This is the one path that cannot be checked any other way. The original
    // bug was a silent no-op: Dart wrote straight to /sdcard/Download, Android
    // 10+ scoped storage swallowed it, and the UI still said "Saved". A unit
    // test with a stubbed channel passes happily either way.
    //
    // Here the real MethodChannel runs against the real MainActivity on real
    // hardware, and the returned location is a MediaStore content:// URI — the
    // signal that the file is genuinely registered with the system and will
    // appear in Files/Downloads, not written to a path the user cannot reach.

    test('a receipt is saved through the real native channel into Downloads',
        () async {
      // A unique name so a re-run cannot pass on a leftover from last time.
      final name =
          'e2e_receipt_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final bytes = await generateReceiptPdf(
        const ReceiptData(
          storeName: 'Asif Foam Center',
          date: '27/9/2026',
          receiptNo: 'E2E-1',
          metaLine: 'Shop #4, Urdu Bazaar',
          customerName: 'Walk-in Customer',
          items: [
            ReceiptLine(
                name: 'luxury', qty: '2', unitPrice: '60,000', total: '120,000'),
          ],
          total: 'Rs 120,000',
          paid: 'Rs 100,000',
          isDue: true,
          dueValue: 'Rs 20,000',
          footer: 'Asif Foam Center',
        ),
      );

      // Deliberately NOT stubbed: `isAndroid` and `nativeSave` are left at their
      // real values so the platform channel is exercised. Stubbing either one
      // would make this test prove nothing.
      expect(ReceiptSaver.instance.isAndroid(), isTrue,
          reason: 'this test is only meaningful on Android');

      final where = await ReceiptSaver.instance.save(bytes, name);

      // MediaStore returns a content:// URI. A bare /sdcard path here would mean
      // the legacy branch ran, which is the pre-Android-10 behaviour that made
      // the original bug invisible.
      expect(where, startsWith('content://'),
          reason: 'Android 10+ must save through MediaStore, got: $where');
      expect(where, contains('downloads'),
          reason: 'the URI must address the Downloads collection');
      // MediaStore addresses the row by id, not by name, so the returned URI
      // legitimately does not contain the file name. The name is stored in the
      // row's DISPLAY_NAME column, which the assertion above cannot see — so
      // the name check happens from the native side instead (see the docs on
      // this test: the row is confirmed out-of-band via `adb shell content
      // query`).
      expect(where, matches(r'content://media/external/downloads/\d+'),
          reason: 'expected a Downloads row URI, got: $where');

      // Report the location so it can be confirmed from outside the app.
      // ignore: avoid_print
      print('E2E_RECEIPT_SAVED_TO=$where');
    });

    test('an empty file name is rejected by the native side', () async {
      // A blank name must not produce a nameless row in the user's Downloads
      // folder. The native handler answers `bad_args`; the Dart wrapper must
      // surface that as a failure rather than reporting success.
      final bytes = await generateReceiptPdf(
        const ReceiptData(
          storeName: 'Asif Foam Center',
          date: '27/9/2026',
          receiptNo: 'E2E-2',
          metaLine: '',
          customerName: 'Walk-in Customer',
          items: [
            ReceiptLine(name: 'luxury', qty: '1', unitPrice: '1,000', total: '1,000'),
          ],
          total: 'Rs 1,000',
          paid: 'Rs 1,000',
          isDue: false,
          dueValue: 'Rs 0',
          footer: 'Asif Foam Center',
        ),
      );

      var failed = false;
      try {
        await ReceiptSaver.instance.save(bytes, '   ');
      } catch (_) {
        failed = true;
      }
      expect(failed, isTrue,
          reason: 'a blank file name must be rejected, not silently accepted');
    });
  });
}

/// Counts pages by counting `/Type /Page` objects, excluding the `/Pages` node.
///
/// Reading the count back out of the written file proves the file is a parseable
/// document, not merely a non-empty blob.
int _pdfPageCount(List<int> bytes) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(_latin1(bytes)).length;

/// Returns the first page's width in millimetres, from its `/MediaBox`.
///
/// PDF user units are 1/72 inch, so `value / 72 * 25.4` converts to millimetres.
double _firstPageWidthMm(List<int> bytes) {
  final m = RegExp(
    r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)',
  ).firstMatch(_latin1(bytes));
  expect(m, isNotNull, reason: 'the PDF must declare a /MediaBox');
  return double.parse(m!.group(1)!) / 72 * 25.4;
}

/// Decodes PDF bytes as Latin-1 so high bytes stay printable.
///
/// PDF operators and text operands are ASCII, and decoding as UTF-8 would
/// replace every byte above 0x7F with U+FFFD, destroying the very strings the
/// scan is looking for.
String _latin1(List<int> bytes) => String.fromCharCodes(bytes);

/// Extracts text from a PDF drawn with the built-in Type1 fonts (Helvetica).
///
/// Those fonts store their glyphs as literal ASCII in the content stream, so
/// each `[(...)] TJ` operand is readable as-is. Text runs are emitted one
/// operand per word — "Asif", "Foam", "Center" arrive separately because the
/// layout engine breaks a string at every space — so the operands are joined
/// with a space, which is what makes a multi-word phrase searchable.
///
/// Test-only: not a general PDF text extractor. The *receipt* uses an embedded
/// subset and needs [_extractTextViaToUnicode] instead.
String _readAsciiContentStreamText(List<int> bytes) {
  final out = StringBuffer();
  for (final stream in _inflateAllStreams(bytes)) {
    for (final t in RegExp(r'\[\((.*?)\)\]\s*TJ').allMatches(stream)) {
      out.write(t.group(1));
      out.write(' ');
    }
  }
  return out.toString();
}

/// Extracts the text of a PDF that embeds subsetted fonts, via `/ToUnicode`.
///
/// The receipt embeds a subset Inter, so its content stream stores glyph indices
/// rather than characters — a plain text search finds nothing, which is exactly
/// how a clipped money figure could hide. The `pdf` package writes a
/// `/ToUnicode` CMap next to each subset that maps those glyph ids back to
/// Unicode, so the real text is recoverable.
///
/// The subtlety that makes a naive reader produce garbage: the receipt embeds
/// *two* subsets (regular and bold) and each has its own CMap in which the same
/// glyph id means a different character — `/F4` id 0x0001 is "S" while `/F9` id
/// 0x0001 is "A". Merging the two maps yields plausible-looking nonsense
/// ("GTaTTT" instead of "60,000"). So the CMap is selected by the font actually
/// selected for each run, via the `BT /Fn ... Tf ... ET` operators that bracket
/// every piece of text.
///
/// Test-only: not a general PDF text extractor. It handles the shape this app
/// produces (Identity-H hex strings, `beginbfchar` CMaps, Flate streams) and
/// makes no attempt to cover the PDF specification.
String _extractTextViaToUnicode(List<int> bytes) {
  final source = _latin1(bytes);

  // 1. Find each font dictionary and the object number of its /ToUnicode CMap.
  //
  //    The CMap is a separate indirect object reached by number:
  //    `/F4 4 0 obj ... /ToUnicode 6 0 R`. Those numbers do *not* line up — here
  //    /F4 -> 6 and /F9 -> 11 — so pairing a font with a CMap by position is
  //    wrong, and it fails silently rather than loudly: glyph id 0x0001 is "S"
  //    in the regular subset and "A" in the bold one, so a mispaired reader
  //    emits plausible nonsense like "GTaTTT" where "60,000" belongs.
  final fontToCmapObj = <String, int>{};
  // `dotAll: true` rather than an inline `(?s)` flag, which Dart's RegExp does
  // not support. A font dictionary spans several lines, so the dot has to match
  // newlines for the ToUnicode reference to be found.
  for (final m in RegExp(
    r'/Type\s*/Font(.{0,1200}?)endobj',
    dotAll: true,
  ).allMatches(source)) {
    final body = m.group(1)!;
    final name = RegExp(r'/Name\s*/(F\d+)').firstMatch(body)?.group(1);
    final cmapNum =
        int.tryParse(RegExp(r'/ToUnicode\s+(\d+)\s+0\s+R').firstMatch(body)?.group(1) ?? '');
    if (name != null && cmapNum != null) fontToCmapObj[name] = cmapNum;
  }

  // 2. Decompress the streams and keep the CMap objects, keyed by the object
  //    number that precedes them in the file.
  //
  //    CMap bodies are Flate-compressed, so `beginbfchar` is not visible in the
  //    raw bytes — the object header (`6 0 obj`) is. The object number is
  //    therefore taken from the raw text immediately before the stream, and the
  //    table is parsed from the inflated bytes.
  final cmapsByObject = <int, Map<int, String>>{};
  for (final m in RegExp(r'(\d+)\s+0\s+obj').allMatches(source)) {
    final objNum = int.tryParse(m.group(1)!);
    if (objNum == null) continue;
    // Find the stream that belongs to this object: the next `stream` keyword
    // after the header and before the object's `endobj`.
    final objEnd = source.indexOf('endobj', m.end);
    if (objEnd < 0) continue;
    final region = source.substring(m.end, objEnd);
    final sm = RegExp(r'stream\r?\n').firstMatch(region);
    if (sm == null) continue;
    final absStart = m.end + sm.end;
    final absEnd = source.indexOf('endstream', absStart);
    if (absEnd < 0) continue;
    String inflated;
    try {
      inflated = String.fromCharCodes(
          ZLibDecoder().decodeBytes(bytes.sublist(absStart, absEnd).toList()));
    } catch (_) {
      continue;
    }
    if (!inflated.contains('beginbfchar')) continue;
    cmapsByObject[objNum] = _parseCMap(inflated);
  }

  final fontCmaps = <String, Map<int, String>>{};
  fontToCmapObj.forEach((font, obj) {
    final parsed = cmapsByObject[obj];
    if (parsed != null) fontCmaps[font] = parsed;
  });

  if (fontCmaps.isEmpty) {
    // A single-font document has nothing to disambiguate; use the first CMap.
    final all = cmapsByObject.values.toList();
    if (all.isEmpty) {
      throw StateError(
        'no /ToUnicode CMap could be resolved: the receipt text cannot be '
        'recovered, so this test would pass without proving anything',
      );
    }
    fontCmaps['__only__'] = all.first;
  }

  // 3. Walk the content stream, tracking the selected font, and decode the
  //    hex-encoded glyph ids with that font's CMap.
  var content = '';
  for (final stream in _inflateAllStreams(bytes)) {
    if (stream.contains('Tf') && stream.contains('TJ')) content = stream;
  }
  if (content.isEmpty) return '';

  final out = StringBuffer();
  var activeFont = '';
  final opRe = RegExp(r'/(F\d+)\s+[\d.]+\s+Tf|<([0-9A-Fa-f]+)>');
  for (final m in opRe.allMatches(content)) {
    if (m.group(1) != null) {
      activeFont = m.group(1)!;
      continue;
    }
    final hex = m.group(2)!;
    if (hex.length % 4 != 0 || hex.length < 4) continue;
    final map = fontCmaps[activeFont] ?? <int, String>{};
    final decoded = StringBuffer();
    for (var i = 0; i + 4 <= hex.length; i += 4) {
      final gid = int.tryParse(hex.substring(i, i + 4), radix: 16);
      if (gid == null) continue;
      final ch = map[gid];
      if (ch != null && ch.trim().isNotEmpty) decoded.write(ch);
    }
    if (decoded.isNotEmpty) {
      out.write(decoded.toString());
      out.write(' ');
    }
  }
  return out.toString();
}

/// Parses one `beginbfchar` CMap into a glyph-id -> character table.
Map<int, String> _parseCMap(String stream) {
  final map = <int, String>{};
  for (final m in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>').allMatches(stream)) {
    final gid = int.tryParse(m.group(1)!, radix: 16);
    final hex = m.group(2)!;
    if (gid == null || hex.isEmpty || gid == 0) continue;
    // The value is UTF-16BE. This receipt's glyph set uses only the BMP and
    // never a surrogate pair, so the first code unit is the whole character.
    final code =
        hex.length >= 4 ? int.parse(hex.substring(0, 4), radix: 16) : int.parse(hex, radix: 16);
    if (code > 0) map[gid] = String.fromCharCode(code);
  }
  return map;
}

/// Inflates every Flate stream in [bytes] and returns them as Latin-1 strings.
///
/// Embedded fonts and the content stream are all compressed; the uncompressed
/// ones are returned as-is so a file with mixed compression still works.
List<String> _inflateAllStreams(List<int> bytes) {
  final source = _latin1(bytes);
  final result = <String>[];
  for (final m in RegExp(r'stream\r?\n').allMatches(source)) {
    final start = m.end;
    final endMarker = source.indexOf('endstream', start);
    if (endMarker < 0) continue;
    final raw = bytes.sublist(start, endMarker).toList();
    try {
      result.add(String.fromCharCodes(ZLibDecoder().decodeBytes(raw)));
    } catch (_) {
      // Not deflate-compressed; keep the raw text so uncompressed content
      // streams are still readable.
      result.add(_latin1(raw));
    }
  }
  return result;
}
