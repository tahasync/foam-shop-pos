import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/models/sale.dart';

/// Pins the sale idempotency key.
///
/// The defect: `transaction_uuid` was named and documented as an idempotency
/// key, and the Firestore rules require it to be non-empty, but nothing made it
/// one. `Sale.toMap()` emitted `transactionUuid ?? id`, and the sales screen
/// built every attempt's `Sale` without passing `transactionUuid` — so the field
/// silently fell back to the document id, which was a FRESH `generateId()` on
/// each attempt.
///
/// `saveSaleTransaction` de-duplicates on the document path:
///
/// ```dart
/// final existing = await transaction.get(_sales.doc(sale.id));
/// if (existing.exists) return;
/// ```
///
/// With a fresh id per attempt, `existing.exists` was always false and the
/// guard protected nothing. Scenario: the commit lands on the server but the
/// response is lost on flaky mobile data, the cashier sees "Could not save",
/// taps Save again, and a second full sale is written with a second stock
/// decrement. The customer is billed twice, inventory is gone, and the
/// duplicate cannot be deleted.
///
/// The fix makes the document id BE the idempotency key, minted once per cart
/// and reused on every retry, so a retry reuses the same path and the existing
/// check turns it into a genuine no-op.
void main() {
  group('transaction_uuid is a real idempotency key', () {
    Sale saleWithId(String id, {String? txnUuid}) => Sale(
          id: id,
          date: DateTime(2026, 9, 28),
          customerId: 'c1',
          customerName: 'Test Customer',
          paid: 100,
          transactionUuid: txnUuid,
          lineItems: [
            SaleLineItem(
              productId: 'p1',
              name: 'Test Product',
              qtyOrArea: 1,
              salePrice: 100,
            ),
          ],
        );

    test('it is always present and non-empty, as the rules require', () {
      // firestore.rules rejects a create whose transaction_uuid is empty, so
      // this must never be null or blank on the way out.
      final map = saleWithId('doc-1').toMap();
      final txn = map['transaction_uuid'];
      expect(txn, isNotNull);
      expect(txn, isA<String>());
      expect((txn as String).trim(), isNotEmpty);
    });

    test('it falls back to the document id rather than going null', () {
      // A null here would be rejected by the rules. The fallback is what keeps
      // the write legal even if a caller forgets to pass one.
      expect(saleWithId('doc-1').toMap()['transaction_uuid'], 'doc-1');
    });

    test('an explicit key is preserved verbatim', () {
      expect(
        saleWithId('doc-1', txnUuid: 'key-abc').toMap()['transaction_uuid'],
        'key-abc',
      );
    });

    test('a retry reusing the key targets the same document', () {
      // This is the property the whole fix rests on: two attempts with the same
      // key must produce the same document path, so `existing.exists` matches
      // and the transaction returns without a second write.
      final first = saleWithId('sale-xyz').toMap();
      final retry = saleWithId('sale-xyz').toMap();
      expect(retry['id'], first['id']);
      expect(retry['transaction_uuid'], first['transaction_uuid']);
    });

    test('distinct sales keep distinct keys', () {
      // The converse must also hold, or the fix would collapse two genuinely
      // different sales into one and silently lose the second.
      final a = saleWithId('sale-aaa').toMap();
      final b = saleWithId('sale-bbb').toMap();
      expect(a['transaction_uuid'], isNot(b['transaction_uuid']));
    });
  });

  group('the sales screen actually reuses the key on retry', () {
    // The model-level tests above only pin the contract. This pins the actual
    // fix, which lives in the screen and cannot be exercised without a live
    // Firestore emulator driving the widget. A source assertion is the honest
    // substitute: it fails the moment someone re-introduces a per-attempt id.
    // (Same drift-detection approach launcher_icon_config_test.dart already
    // uses for the launcher artwork.)
    final screen =
        File('lib/screens/sales_entry_screen.dart').readAsStringSync();

    test('the id is minted with ??= so a retry reuses it', () {
      // A plain `final saleId = svc.generateId();` is the exact bug: a new id
      // per attempt, so `existing.exists` never matches and a retry duplicates
      // the sale. `??=` is what makes the key sticky across attempts.
      expect(
        screen
            .contains(RegExp(r'_pendingSaleId\s*\?\?=\s*svc\.generateId\(\)')),
        isTrue,
        reason: 'The sale id must be minted with ??= from _pendingSaleId, so a '
            'retry reuses the same document path and de-duplicates.',
      );
    });

    test('the key is passed onto the Sale as its transactionUuid', () {
      expect(
        screen.contains(RegExp(r'transactionUuid:\s*saleId')),
        isTrue,
        reason: 'The document id must be carried as transactionUuid so the '
            'field can never drift away from the id it de-duplicates on.',
      );
    });

    test('the key is released on success and on clear, but not on failure', () {
      // Success: the next cart must mint a fresh key, or an unrelated sale
      // would collide and be silently swallowed as a duplicate.
      final clearCount =
          RegExp(r'_pendingSaleId\s*=\s*null').allMatches(screen).length;
      expect(
        clearCount,
        greaterThanOrEqualTo(2),
        reason: '_pendingSaleId must be released after a confirmed save and '
            'when the cart is explicitly cleared.',
      );

      // Failure: releasing it in the catch block would undo the entire
      // retry-safety property, which is the whole point of the fix.
      final catchBlock =
          RegExp(r'\}\s*catch\s*\([^)]*\)\s*\{(.*?)\n\s*\}', dotAll: true)
              .allMatches(screen)
              .map((m) => m.group(1) ?? '')
              .join('\n');
      expect(
        catchBlock.contains('_pendingSaleId = null'),
        isFalse,
        reason: 'The idempotency key must NOT be cleared on failure - that is '
            'precisely the case where the next attempt has to reuse it.',
      );
    });

    test('stock deductions accumulate rather than overwrite', () {
      // `deductions[id] = qty` keeps only the last line for a repeated product,
      // which would sell two lines and deduct one. `voidSale` already uses `+=`
      // for the same reason; the two directions must agree.
      expect(
        screen.contains(
            RegExp(r'deductions\[c\.product\.id\]\s*=\s*\n?\s*\(deductions\[')),
        isTrue,
        reason: 'Repeated product lines must accumulate into deductions, not '
            'overwrite each other.',
      );
    });
  });
}
