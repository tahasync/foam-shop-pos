// Renders sample receipts to PDF so the layout can be eyeballed as an image.
//
// This is a visual aid, not an assertion: it writes `build/sample_paid.pdf` and
// `build/sample_due.pdf` and always passes. Run it with:
//
//   flutter test test/sample_receipt_test.dart
//   pdftoppm -png -r 150 build/sample_paid.pdf build/sample_paid
//
// The assertions about content and page geometry live in the real test suites;
// duplicating them here would only give a second place to update them.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:foam_shop_register/services/receipt_pdf.dart';

ReceiptData _sample({required bool isDue, required int itemCount}) {
  const longName = 'High-Density Gold Reflex Foam 10mm Sheet';
  return ReceiptData(
    storeName: 'Asif Foam & Furniture',
    date: '27 Sep 2026, 04:38 PM',
    receiptNo: 'INV-2026-00417',
    metaLine: 'Shop #4, Urdu Bazaar \u00b7 0300-1234567',
    customerName: isDue ? 'Walk-in Customer' : 'Bilal Traders',
    items: [
      for (var i = 0; i < itemCount; i++)
        ReceiptLine(
          // Include an over-long name: that is the case that used to shove the
          // money columns off the right edge of the 80mm roll.
          name: i == 0 ? longName : 'Foam Sheet ${i + 1}',
          qty: '${i + 2} pc',
          unitPrice: 'Rs ${1200 * (i + 1)}',
          total: 'Rs ${1200 * (i + 1) * (i + 2)}',
        ),
    ],
    total: 'Rs 20,500',
    paid: isDue ? 'Rs 12,000' : 'Rs 20,500',
    isDue: isDue,
    dueValue: isDue ? 'Rs 8,500' : 'Rs 0',
    footer: 'Asif Foam & Furniture \u00b7 Shop #4, Urdu Bazaar',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders sample receipts for visual inspection', () async {
    for (final entry in [
      (name: 'sample_paid', due: false, items: 3),
      (name: 'sample_due', due: true, items: 8),
    ]) {
      final bytes = await generateReceiptPdf(
        _sample(isDue: entry.due, itemCount: entry.items),
      );
      File('build/${entry.name}.pdf').writeAsBytesSync(bytes);
    }
  });
}
