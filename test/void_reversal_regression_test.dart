// Regression tests for voiding a sale.
//
// The bug: voiding *any* sale failed on-device with the generic "Could not void
// sale" toast, and the stock was never returned. `FirestoreService.voidSale`
// wrote the sale document first and only then read each product document inside
// the restock loop. Firestore requires every read in a transaction to happen
// before the first write, so the whole transaction was rejected with
// FAILED_PRECONDITION and nothing was ever reversed. The failure was invisible
// to `flutter analyze` and to every other test, because it only reproduces
// against a real Firestore backend.
//
// The accounting side is covered here too, because the point of a void is that
// the money leaves the till: a Rs 69,000 sale the customer paid Rs 70,000 for
// must take Rs 69,000 back out of Cash in Hand, not the Rs 70,000 the cashier
// counted in, and not the Rs 1,000 of change that never reached the till at all.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/models/opening_balance.dart';
import 'package:foam_shop_register/models/sale.dart';
import 'package:foam_shop_register/services/accounting_service.dart';

OpeningBalance _noOpening() =>
    OpeningBalance(id: 'ob1', date: DateTime(2026, 9, 1), capitalAmount: 0);

/// The exact sale from the bug report: 2 x ZZTEST7 @ 34,500 = 69,000, paid
/// 70,000, so Rs 1,000 of change left the till with the customer.
Sale _voidCandidate({bool isVoided = false}) => Sale(
      id: 'INV-QQHL',
      date: DateTime(2026, 9, 28, 1, 30),
      customerId: 'c1',
      customerName: 'Taha',
      lineItems: [
        SaleLineItem(
          productId: 'p1',
          name: 'ZZTEST7',
          qtyOrArea: 2,
          salePrice: 34500,
        ),
      ],
      paid: 70000,
      isVoided: isVoided,
      voidReason: isVoided ? 'Customer changed their mind' : null,
    );

/// A second, ordinary sale that must survive the void of the first.
Sale _keeperSale() => Sale(
      id: 'INV-KEEP',
      date: DateTime(2026, 9, 28, 1, 15),
      customerId: 'c2',
      customerName: 'Walk-in',
      lineItems: [
        SaleLineItem(
          productId: 'p2',
          name: 'ZZTEST8',
          qtyOrArea: 1,
          salePrice: 22500,
        ),
      ],
      paid: 26000,
    );

void main() {
  final service = AccountingService();

  group('Void reversal — Cash in Hand', () {
    test('net received, not the cash handed over, is what leaves the till', () {
      // Sanity-check the two figures the reversal has to choose between.
      final sale = _voidCandidate();
      expect(sale.amount, 69000.0);
      expect(sale.paid, 70000.0);
      expect(sale.changeDue, 1000.0);
      expect(sale.netCashReceived, 69000.0);
    });

    test('voiding takes exactly the net received back out of the till', () {
      final before = service.compute(
        sales: [_voidCandidate(), _keeperSale()],
        purchases: const [],
        expenses: const [],
        payments: const [],
        supplierPayments: const [],
        products: const [],
        openingBal: _noOpening(),
      );
      final after = service.compute(
        sales: [_voidCandidate(isVoided: true), _keeperSale()],
        purchases: const [],
        expenses: const [],
        payments: const [],
        supplierPayments: const [],
        products: const [],
        openingBal: _noOpening(),
      );

      // Before: 69,000 (net) + 22,500 (net) = 91,500. This is the figure that
      // was verified on-device before the fix.
      expect(before.cashInHand, 91500.0);
      expect(before.revenue, 91500.0);

      // After: only the Rs 22,500 sale is still counted.
      expect(after.cashInHand, 22500.0);
      expect(after.revenue, 22500.0);

      // The reversal is the net received — 69,000. Had it subtracted the
      // customer's 70,000 payment the till would read -500; had it clawed back
      // the 1,000 change as well it would read 21,500.
      expect(before.cashInHand - after.cashInHand, 69000.0);
    });

    test('a voided sale contributes nothing at all to the till', () {
      final onlyVoided = service.compute(
        sales: [_voidCandidate(isVoided: true)],
        purchases: const [],
        expenses: const [],
        payments: const [],
        supplierPayments: const [],
        products: const [],
        openingBal: _noOpening(),
      );

      expect(onlyVoided.cashInHand, 0.0);
      expect(onlyVoided.revenue, 0.0);
      expect(onlyVoided.netProfit, 0.0);
    });

    test('a voided sale keeps its reason, so it can be audited', () {
      final sale = _voidCandidate(isVoided: true);
      expect(sale.isVoided, isTrue);
      expect(sale.voidReason, 'Customer changed their mind');
    });
  });

  group('voidSale — Firestore transaction ordering', () {
    // The defect lived entirely inside a closure handed to `runTransaction`, so
    // the only way to guard it without a live Firestore emulator is to assert on
    // the source. This mirrors the approach already used in
    // source_integrity_test.dart, which exists for the same reason.
    late List<String> voidSaleBody;

    setUpAll(() {
      final source =
          File('lib/services/firestore_service.dart').readAsLinesSync();
      final start =
          source.indexWhere((l) => l.contains('Future<void> voidSale('));
      expect(
        start,
        isNot(-1),
        reason: 'voidSale not found in firestore_service.dart',
      );
      final end = source.indexWhere(
          (l) => l.trim() == '}' && l.startsWith('  }'), start + 1);
      voidSaleBody = source.sublist(start, end == -1 ? source.length : end);
    });

    test('every product read is issued before the first write', () {
      // The old body wrote the sale document and *then* read each product
      // inside the restock loop, so Firestore rejected the transaction with
      // FAILED_PRECONDITION and voiding never worked.
      //
      // Every read in the transaction must precede every write. That is the rule
      // Firestore enforces, and breaking it is what made every void fail with
      // FAILED_PRECONDITION.
      //
      // The whole body is analysed, comments excluded. Earlier attempts scoped
      // the window - by cutting at the first `return;`, then by anchoring on
      // `Future.wait` - and both were wrong in the same way: they shrank the
      // region until the offending ordering fell outside it, so the test passed
      // on exactly the code it exists to reject. The `Future.wait` anchor is
      // particularly treacherous because the read sits on a *continuation* line,
      // so starting there also drops every write above it.
      //
      // The isQuote guard that was added later is legal precisely because it
      // writes and returns without reading afterwards. Rather than special-case
      // it by scanning for `return;` - which is how the previous version went
      // wrong - the ordering rule is checked on the region AFTER that guard,
      // found by its own distinctive text.
      final guardAt =
          voidSaleBody.indexWhere((l) => l.contains('if (sale.isQuote)'));

      final analysedFrom = guardAt == -1
          ? 0
          : voidSaleBody.indexWhere(
              (l) =>
                  l.contains('restockByProduct') &&
                  !l.trimLeft().startsWith('//'),
              guardAt,
            );

      expect(
        analysedFrom,
        isNot(-1),
        reason: 'voidSale must aggregate the restock quantities after the '
            'isQuote guard; that aggregation starts the path under test.',
      );

      final restockPath = voidSaleBody
          .sublist(analysedFrom)
          .where((l) => !l.trimLeft().startsWith('//'))
          .toList();

      final firstWrite = restockPath.indexWhere((l) =>
          l.contains('transaction.update') || l.contains('transaction.set'));
      final lastRead =
          restockPath.lastIndexWhere((l) => l.contains('transaction.get'));

      expect(firstWrite, isNot(-1), reason: 'no write found in voidSale');
      expect(lastRead, isNot(-1), reason: 'no read found in voidSale');
      expect(
        lastRead,
        lessThan(firstWrite),
        reason: 'voidSale reads after it writes; Firestore requires all reads '
            'to precede all writes inside a transaction, which is why voiding '
            'failed with "Could not void sale"',
      );
    });

    test('product documents are read in one batch, not one at a time', () {
      // A per-line read is what made the ordering bug possible in the first
      // place; batching the reads up front is what fixes it.
      final reads =
          voidSaleBody.where((l) => l.contains('transaction.get')).length;
      expect(
        reads,
        lessThanOrEqualTo(2),
        reason: 'product restock reads should be hoisted into a single '
            'Future.wait, not issued one line item at a time',
      );
    });
  });
}
