// Regression tests for overpayment ("change") handling.
//
// The bug: a customer handed over more than the bill — Rs 70,000 for a Rs 69,000
// sale — and the app had no concept of the Rs 1,000 the shop owes back. The
// receipt said "Balance Rs 0 / FULLY PAID", the billing row said "Bal -1,000",
// and Cash in Hand counted the Rs 70,000 as if the till still held it. The
// cashier had to subtract the change by hand in front of the customer.
//
// Each test below names the specific wrong number that used to be produced.
import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/models/opening_balance.dart';
import 'package:foam_shop_register/models/sale.dart';
import 'package:foam_shop_register/screens/sales_entry_screen.dart';
import 'package:foam_shop_register/services/accounting_service.dart';
import 'package:foam_shop_register/services/receipt_pdf.dart';

/// The exact sale from the bug report: 2 x ZZTEST7 @ 34,500 = 69,000, paid 70,000.
Sale _overpaidSale({double paid = 70000}) => Sale(
      id: 'INV-QQHL',
      date: DateTime(2026, 9, 28, 1, 30),
      customerId: 'c1',
      customerName: 'Taha',
      lineItems: [
        SaleLineItem(
            productId: 'p1', name: 'ZZTEST7', qtyOrArea: 2, salePrice: 34500),
      ],
      paid: paid,
    );

void main() {
  group('Sale — overpayment is change, not a negative balance', () {
    test('the exact reported sale amounts to 69,000', () {
      expect(_overpaidSale().amount, 69000.0);
    });

    test('change is the 1,000 the customer is owed back', () {
      // The core of the bug report: Rs 70,000 paid - Rs 69,000 bill.
      expect(_overpaidSale().changeDue, 1000.0);
      expect(_overpaidSale().hasChange, isTrue);
    });

    test('balance is never negative on an overpaid sale', () {
      // It used to be -1,000, which the billing list printed verbatim as
      // "Bal -1,000" — a figure that reads as a debt, not as change.
      expect(_overpaidSale().balance, 0.0);
      expect(_overpaidSale().balance, greaterThanOrEqualTo(0));
    });

    test('an exact payment has neither change nor balance', () {
      final sale = _overpaidSale(paid: 69000);
      expect(sale.changeDue, 0.0);
      expect(sale.hasChange, isFalse);
      expect(sale.balance, 0.0);
    });

    test('an underpaid sale still reports the outstanding balance', () {
      // The change fix must not swallow a genuine debt.
      final sale = _overpaidSale(paid: 50000);
      expect(sale.changeDue, 0.0);
      expect(sale.hasChange, isFalse);
      expect(sale.balance, 19000.0);
    });

    test('net cash is what the till keeps, not what was handed over', () {
      expect(_overpaidSale().netCashReceived, 69000.0);
    });

    test('change survives a Firestore round trip', () {
      // `paid` is persisted, so the figure must be re-derivable after a reload
      // rather than depending on some in-memory state.
      final reloaded = Sale.fromMap(_overpaidSale().toMap());
      expect(reloaded.changeDue, 1000.0);
      expect(reloaded.balance, 0.0);
      expect(reloaded.netCashReceived, 69000.0);
    });
  });
  group('Receipt states the change to give back', () {
    ReceiptData receiptFor({required double paid, required double balance}) =>
        buildReceiptData(
          storeName: 'Asif Foam Center',
          receiptId: 'INV-QQHL',
          date: '28/9/2026',
          customerName: 'Taha',
          items: const [
            ReceiptLine(
                name: 'ZZTEST7',
                qty: '2',
                unitPrice: '34,500',
                total: '69,000'),
          ],
          totalAmount: 69000,
          paidAmount: paid,
          remainingBalance: balance,
        );

    test('an overpaid receipt prints the 1,000 of change', () {
      final data = receiptFor(paid: 70000, balance: 0);
      expect(data.hasChange, isTrue);
      expect(data.change, contains('1,000'));
    });

    test('the change never carries a negative sign', () {
      // Overpayment is money going out, so a minus would be doubly wrong.
      expect(receiptFor(paid: 70000, balance: 0).change, isNot(contains('-')));
    });

    test('an exact payment shows no change row at all', () {
      // "Change Rs 0" would read as though something is still owed.
      final data = receiptFor(paid: 69000, balance: 0);
      expect(data.hasChange, isFalse);
      expect(data.change, isEmpty);
    });

    test('an underpaid receipt reports the balance and no change', () {
      final data = receiptFor(paid: 50000, balance: 19000);
      expect(data.hasChange, isFalse);
      expect(data.isDue, isTrue);
    });

    test('an overpaid receipt is not also flagged as due', () {
      final data = receiptFor(paid: 70000, balance: 0);
      expect(data.isDue, isFalse);
    });
  });

  group('Cash in Hand does not count change the shop gave back', () {
    final service = AccountingService();

    AccountingSummary summaryFor(Sale sale) => service.compute(
          sales: [sale],
          purchases: const [],
          expenses: const [],
          payments: const [],
          supplierPayments: const [],
          products: const [],
          openingBal: OpeningBalance(
              id: 'ob1', date: DateTime(2026, 1, 1), capitalAmount: 0),
        );

    test('an overpaid sale banks 69,000, not the 70,000 received', () {
      // The till physically holds 69,000: the other 1,000 went straight back
      // out as change. Counting `paid` reported Rs 1,000 of money that was
      // never in the drawer.
      final result = summaryFor(_overpaidSale());
      expect(result.cashFromSales, 69000.0);
      expect(result.cashInHand, 69000.0);
    });

    test('an exact payment is unaffected', () {
      expect(summaryFor(_overpaidSale(paid: 69000)).cashInHand, 69000.0);
    });

    test('a part payment banks only what was actually collected', () {
      expect(summaryFor(_overpaidSale(paid: 50000)).cashInHand, 50000.0);
    });

    test('voiding an overpaid sale reverses the same net amount', () {
      // The void path and `compute` must agree, or a void leaves phantom cash.
      final sale = _overpaidSale();
      final before = summaryFor(sale);
      final after = service.computeVoidAdjustment(
        sale: sale,
        summary: before,
        products: const [],
      );
      expect(after.cashInHand, 0.0);
      expect(after.cashFromSales, 0.0);
    });
  });

  group('Quick-fill offers the note the customer actually hands over', () {
    test('the reported 69,000 bill offers 70,000 as a one-tap option', () {
      // The whole feature: the cashier taps "70,000" instead of typing five
      // digits, and the Change box then reads Rs 1,000.
      final options = quickPaidOptions(69000);
      expect(options, contains(70000.0));
    });

    test('the exact total is always offered, so paid-in-full is one tap', () {
      for (final bill in [900.0, 12500.0, 69000.0, 118500.0]) {
        expect(quickPaidOptions(bill).first, bill,
            reason: 'a bill of $bill must lead with its own exact total');
      }
    });

    test('options come back ascending', () {
      final options = quickPaidOptions(69000);
      final sorted = [...options]..sort();
      expect(options, sorted);
    });

    test('no option is ever offered below the bill', () {
      // Offering less than the total would be a part payment masquerading as
      // "the customer handed me this".
      for (final bill in [1.0, 250.0, 999.0, 12345.0, 69000.0, 250000.0]) {
        for (final option in quickPaidOptions(bill)) {
          expect(option, greaterThanOrEqualTo(bill),
              reason: '$option was offered for a bill of $bill');
        }
      }
    });

    test('change is always less than half the bill', () {
      // A Rs 900 bill rounded to Rs 5,000 is not "Rs 4,100 change", it is a
      // different transaction. Such a chip must not be offered.
      for (final bill in [1.0, 37.0, 900.0, 4500.0, 69000.0]) {
        for (final option in quickPaidOptions(bill)) {
          final change = option - bill;
          expect(change, lessThanOrEqualTo(bill / 2),
              reason:
                  'a change of $change on a bill of $bill is not plausible');
        }
      }
    });

    test('a bill that is already round offers no pointless round-up', () {
      // Every step lands back on 69,000, so there is nothing to give back and
      // the row should be just the one option.
      expect(quickPaidOptions(50000), [50000.0]);
    });

    test('steps reaching the same figure are offered only once', () {
      // 69,000 rounds up to 70,000 via both the 1,000 and 5,000 steps.
      final options = quickPaidOptions(69000);
      expect(options.where((o) => o == 70000.0).length, 1);
      expect(options.toSet().length, options.length,
          reason: 'the option list must not contain duplicates');
    });

    test('an empty cart offers nothing to pay', () {
      expect(quickPaidOptions(0), isEmpty);
      expect(quickPaidOptions(-5), isEmpty);
    });

    test('a fractional cut-to-order bill still rounds up cleanly', () {
      // Foam is sold by area, so the total is rarely a whole rupee.
      final options = quickPaidOptions(12345.5);
      expect(options.first, 12345.5);
      expect(options, contains(12500.0));
    });
  });
}
