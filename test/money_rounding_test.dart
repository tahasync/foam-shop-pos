import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/models/sale.dart';
import 'package:foam_shop_register/services/accounting_service.dart';
import 'package:foam_shop_register/services/export_service.dart';
import 'package:foam_shop_register/services/receipt_pdf.dart';
import 'package:foam_shop_register/utils/money.dart';

/// Guards the money-rounding fix.
///
/// The defect: every monetary display site called `.toInt()` on a `double`, and
/// `double.toInt()` truncates toward zero rather than rounding. A cart of three
/// lines at Rs 100.50 has a true total of Rs 301.50 and the printed receipt said:
///
/// ```text
///   1 @ 100   100
///   1 @ 100   100
///   1 @ 100   100
///   TOTAL     301
/// ```
///
/// Three printed lines of 100 do not sum to 301. A receipt that does not add up
/// cannot be reconciled by the cashier in front of the customer, and truncation
/// biased every total downwards, so a shop systematically under-reports revenue.
void main() {
  group('roundMoney', () {
    test('rounds to nearest, half away from zero', () {
      expect(roundMoney(100.4), 100);
      expect(roundMoney(100.5), 101);
      expect(roundMoney(2.5), 3);
      expect(roundMoney(3.5), 4);
      expect(roundMoney(1000.6), 1001);
    });

    test('does NOT truncate, which was the original bug', () {
      // The exact values the old `.toInt()` call got wrong.
      expect(roundMoney(100.5), isNot(100));
      expect(roundMoney(59.97), 60);
      expect(roundMoney(1499.99), 1500);
    });

    test('leaves whole amounts untouched', () {
      expect(roundMoney(0), 0);
      expect(roundMoney(450), 450);
      expect(roundMoney(25500), 25500);
      expect(roundMoney(-70000), -70000);
    });

    test('rounds a credit away from zero, not toward it', () {
      // `.toInt()` sent -0.5 to 0, so a refund could vanish from the books.
      expect(roundMoney(-0.5), -1);
      expect(roundMoney(-1499.99), -1500);
    });

    test('corrupt input degrades to zero instead of printing NaN', () {
      expect(roundMoney(null), 0);
      expect(roundMoney(double.nan), 0);
      expect(roundMoney(double.infinity), 0);
      expect(roundMoney(double.negativeInfinity), 0);
    });

    test('never produces negative zero', () {
      // "-0" printed on a receipt reads as a bug to a shopkeeper.
      expect(roundMoney(-0.4).toString(), '0');
      expect(roundMoney(-0.0), 0);
    });

    test('rounding each line can differ from rounding the sum', () {
      // This is the arithmetic that made the old receipt wrong, stated as a
      // fact rather than a bug. 3 x 100.50 is 301.50 -> 302, while each line
      // rounds up to 101 -> 303. The receipt now reports the 1-unit gap instead
      // of printing numbers that contradict each other.
      final line = 1 * 100.50;
      final printed = List.filled(3, roundMoney(line));
      expect(printed.reduce((a, b) => a + b), 303);
      expect(roundMoney(3 * line), 302);
      expect(roundMoney(3 * line) - printed.reduce((a, b) => a + b), -1);
    });
  });

  group('formatMoney', () {
    test('groups thousands and rounds rather than truncates', () {
      expect(formatMoney(25500), '25,500');
      expect(formatMoney(1499.99), '1,500');
      expect(formatMoney(1000.5), '1,001');
    });

    test('places the currency symbol exactly once', () {
      expect(formatMoneyWithSymbol(25500, currencyCode: 'PKR'), 'Rs 25,500');
    });
  });

  group('receipt arithmetic', () {
    ReceiptLine line(String name, double qty, double price) => ReceiptLine(
          name: name,
          qty: qty.toString(),
          unitPrice: formatMoney(price),
          total: formatMoney(qty * price),
          totalValue: qty * price,
        );

    test('a whole-rupee sale reconciles exactly, with no adjustment', () {
      // The overwhelmingly common case must stay perfectly clean: a
      // "rounding adjustment" row must never appear on a normal receipt.
      final data = buildReceiptData(
        storeName: 'Test Foam Shop',
        receiptId: 'INV-1',
        date: '28/9/2026',
        customerName: 'Test Customer',
        items: [line('A', 2, 450), line('B', 3, 120)],
        totalAmount: 1260,
        paidAmount: 1260,
        remainingBalance: 0,
      );
      expect(data.roundingAdjustment, 0);
      expect(data.roundingLabel, isEmpty);
    });

    test('fractional lines surface a visible, signed adjustment', () {
      final data = buildReceiptData(
        storeName: 'Test Foam Shop',
        receiptId: 'INV-2',
        date: '28/9/2026',
        customerName: 'Test Customer',
        items: [
          line('A', 1, 100.50),
          line('B', 1, 100.50),
          line('C', 1, 100.50)
        ],
        totalAmount: 301.50,
        paidAmount: 301.50,
        remainingBalance: 0,
      );
      // Lines print 101 each (303); the total prints 302. The difference is
      // stated on the receipt rather than the receipt silently disagreeing
      // with itself.
      expect(data.roundingAdjustment, -1);
      expect(data.roundingLabel, contains('Rs'));
      expect(data.roundingLabel, startsWith('−'));
    });

    test('a positive adjustment carries a plus sign', () {
      final data = buildReceiptData(
        storeName: 'Shop',
        receiptId: 'INV-3',
        date: '28/9/2026',
        customerName: 'Test',
        items: [line('A', 1, 100.40), line('B', 1, 100.40)],
        totalAmount: 201.20,
        paidAmount: 201.20,
        remainingBalance: 0,
      );
      expect(data.roundingAdjustment, 1);
      expect(data.roundingLabel, startsWith('+'));
    });

    test('a hand-built ReceiptLine without a numeric total still works', () {
      // Fixtures and the document preview omit totalValue. They must not crash
      // and must not invent an adjustment.
      final data = buildReceiptData(
        storeName: 'Shop',
        receiptId: 'INV-4',
        date: '28/9/2026',
        customerName: 'Test',
        items: const [
          ReceiptLine(name: 'A', qty: '1', unitPrice: '100', total: '100'),
        ],
        totalAmount: 100,
        paidAmount: 100,
        remainingBalance: 0,
      );
      expect(data.roundingAdjustment, 0);
      expect(data.roundingLabel, isEmpty);
    });

    test('a discounted total is still formatted and not called a subtotal', () {
      // `d.total` carries the grand total - discount and charges already
      // applied. It used to be printed under the word "Subtotal", which implied
      // the visible items were not the whole bill.
      final data = buildReceiptData(
        storeName: 'Shop',
        receiptId: 'INV-5',
        date: '28/9/2026',
        customerName: 'Test',
        items: [line('A', 1, 1000)],
        totalAmount: 900,
        paidAmount: 900,
        remainingBalance: 0,
      );
      expect(data.total, 'Rs 900');
    });

    test('change is still reported on an overpaid sale', () {
      final data = buildReceiptData(
        storeName: 'Shop',
        receiptId: 'INV-6',
        date: '28/9/2026',
        customerName: 'Test',
        items: [line('A', 1, 69000)],
        totalAmount: 69000,
        paidAmount: 70000,
        remainingBalance: 0,
      );
      expect(data.hasChange, isTrue);
      expect(data.change, 'Rs 1,000');
    });

    test('a balance due is still reported on an underpaid sale', () {
      final data = buildReceiptData(
        storeName: 'Shop',
        receiptId: 'INV-7',
        date: '28/9/2026',
        customerName: 'Test',
        items: [line('A', 1, 1000)],
        totalAmount: 1000,
        paidAmount: 400,
        remainingBalance: 600,
      );
      expect(data.isDue, isTrue);
      expect(data.dueValue, 'Rs 600');
    });
  });
  group('CSV export cannot be used as a formula vector', () {
    /// Excel, LibreOffice and Google Sheets evaluate a cell whose first
    /// character is `=`, `+`, `-` or `@` as a formula. A customer named
    /// `=cmd|'/C calc'!A0` therefore executes when a shopkeeper opens the
    /// exported report - and opening an exported sales report in Excel is
    /// precisely what a shopkeeper does.
    ///
    /// The sanitizer already existed but was applied only to the Items column.
    /// Customer and shop name are equally attacker-influenced and were
    /// reaching the file raw.
    AccountingSummary summary() => AccountingService().compute(
          sales: const [],
          purchases: const [],
          expenses: const [],
          payments: const [],
          supplierPayments: const [],
          products: const [],
          openingBal: null,
        );

    List<Sale> saleFor(String customerName) => [
          Sale(
            id: 'sale0000000001',
            date: DateTime(2026, 9, 28),
            customerId: 'c1',
            customerName: customerName,
            paid: 100,
            lineItems: [
              SaleLineItem(
                productId: 'p1',
                name: 'Test Product',
                qtyOrArea: 1,
                salePrice: 100,
              ),
            ],
          ),
        ];

    String csvFor({required List<Sale> sales, String shopName = 'Test Foam'}) =>
        ExportService().buildCsvReport(
          sales: sales,
          products: const [],
          summary: summary(),
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 30),
          shopName: shopName,
        );

    test('a customer name starting with = is neutralised', () {
      final csv = csvFor(sales: saleFor('=cmd|\'/C calc\'!A0'));
      // The payload must still be visible to the shopkeeper...
      expect(csv, contains('cmd'));
      // ...but never at the start of a cell, which is what makes it a formula.
      expect(csv, isNot(contains(',=cmd')));
      expect(csv, contains("'=cmd"));
    });

    test('a customer name starting with @ is neutralised', () {
      final csv = csvFor(sales: saleFor('@SUM(1:9)'));
      expect(csv, contains("'@SUM"));
    });

    test('a shop name starting with + is neutralised in the header', () {
      final csv = csvFor(sales: const [], shopName: '+HYPERLINK("x")');
      expect(csv.trimLeft(), isNot(startsWith('+')));
      expect(csv, contains("'+HYPERLINK"));
    });

    test('an ordinary customer name is left exactly as typed', () {
      // The sanitizer must not mangle the 99.9% case, or every export would
      // grow a stray apostrophe and reports would look wrong.
      final csv = csvFor(sales: saleFor('Ali Raza'));
      expect(csv, contains('Ali Raza'));
    });
  });
}
