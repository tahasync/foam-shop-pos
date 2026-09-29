import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/models/sale.dart';
import 'package:foam_shop_register/services/accounting_service.dart';

/// Regression test for the quote-void stock inflation bug.
///
/// A quote is written by a bare `.set()` (`FirestoreService.addSale`), which is
/// the only sale path that does NOT decrement `current_stock`. But `voidSale`
/// restocked unconditionally. So voiding a quote returned material the shop
/// never gave out: quote 500 sq ft against 1,000 in stock, void the quote, and
/// the ledger claims 1,500 sq ft of foam that does not exist. The phantom stock
/// is sellable, the owner over-buys against it, and because a sale can never be
/// deleted to undo the error, it is permanent.
///
/// `flutter analyze` cannot see this - the guard is a runtime branch - and no
/// other test exercised void-on-quote, because the existing void tests all use
/// `isQuote: false`. The service cannot be unit-tested directly either: it
/// holds a live `FirebaseFirestore.instance`, so the check is necessarily
/// source-level, like `test/source_integrity_test.dart`.
void main() {
  final serviceSource =
      File('lib/services/firestore_service.dart').readAsStringSync();
  final billingSource =
      File('lib/screens/billing_screen.dart').readAsStringSync();

  group('voiding a quote must not restock', () {
    test('voidSale returns before the restock loop when the sale is a quote',
        () {
      final start = serviceSource.indexOf('Future<void> voidSale');
      expect(start, greaterThan(-1),
          reason: 'voidSale must still exist - the test is stale.');
      final body = serviceSource.substring(start);

      // The guard has to come BEFORE the restock writes, or it protects nothing.
      final guardAt = body.indexOf('if (sale.isQuote)');
      final restockAt = body.indexOf("'current_stock': currentStock +");
      expect(guardAt, greaterThan(-1),
          reason: 'voidSale must short-circuit for a quote. Without this, '
              'voiding a quote invents stock that was never deducted.');
      expect(restockAt, greaterThan(-1),
          reason: 'The real-sale restock path should still be present.');
      expect(guardAt, lessThan(restockAt),
          reason: 'The isQuote guard must run BEFORE the restock writes. '
              'Placed after them, a quote is still restocked before the guard '
              'can return.');
    });

    test('the quote guard still marks the sale voided', () {
      final start = serviceSource.indexOf('Future<void> voidSale');
      final body = serviceSource.substring(start);
      final guardStart = body.indexOf('if (sale.isQuote)');
      expect(guardStart, greaterThan(-1));

      // A void that neither restocks nor flags the document would leave a live
      // estimate counted as a real order forever.
      final guardBlock = body.substring(guardStart, guardStart + 320);
      expect(guardBlock, contains("'is_voided': true"),
          reason: 'Voiding a quote must still retire it.');
    });

    test('the void action is not offered on a quote', () {
      expect(
        billingSource,
        contains('if (!sale.isVoided && !sale.isQuote)'),
        reason: 'The receipt action sheet must not offer "Void sale" on a '
            'quote. AccountingService.canCancelSale() encodes the same rule; '
            'this pins the UI half of it.',
      );
    });

    test('canCancelSale still refuses a quote (the rule has one source)', () {
      final quote = Sale(
        id: 'q1',
        date: DateTime(2026, 9, 28),
        customerId: '',
        customerName: '',
        lineItems: [
          SaleLineItem(
            productId: 'p1',
            name: 'Foam',
            qtyOrArea: 500,
            salePrice: 450,
          ),
        ],
        paid: 0,
        isQuote: true,
      );
      // An instance method on AccountingService, not a static helper.
      final service = AccountingService();
      expect(service.canCancelSale(quote), isFalse,
          reason:
              'A quote moved no stock, so it is not cancellable as a sale.');
    });
  });
}
