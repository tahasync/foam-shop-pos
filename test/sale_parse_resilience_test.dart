/// Regression test for the one-bad-sale-takes-down-the-whole-shop bug.
///
/// `Sale.fromMap` hard-cast `id`, `date`, `customer_id` and `paid`, and divided
/// `amount / qty_or_area` with no guard. `salesStreamProvider` mapped every
/// document eagerly, so any one of those throws propagated out of the provider.
/// That provider feeds the billing list, the dashboard totals, Reports, CSV
/// export and the Khata ledger, so a single malformed archived sale blanked the
/// shop's entire sales history with no way to tell it from an outage.
///
/// Production has a live legacy flat-schema document with no `line_items`,
/// which is exactly the branch that divides by `qty_or_area`, so this is not
/// hypothetical.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/models/sale.dart';

/// A complete, modern sale as `toMap` writes it. Used as the "other rows" that
/// must survive alongside a broken one.
Map<String, dynamic> _goodSale(String id) => {
      'id': id,
      'date': '2026-09-01T10:00:00.000',
      'customer_id': 'cust-1',
      'customer_name': 'Taha',
      'line_items': [
        {
          'product_id': 'p1',
          'name': 'luxury',
          'qty_or_area': 1.0,
          'sale_price': 1000.0,
          'line_discount_amount': 0.0,
          'cost_price_at_sale': 700.0,
        }
      ],
      'paid': 1000.0,
      'is_voided': false,
      'is_quote': false,
    };

void main() {
  group('the real legacy document loads', () {
    // Verbatim production shape: no line_items, no is_voided, no is_quote,
    // no customer_name, no transaction_uuid, a bare `amount` and `qty_or_area`.
    final legacy = {
      'id': 'wmejhdrF7cP21GLT9IRB',
      'date': '2026-07-20T02:53:46.213228',
      'customer_id': '3yH6FvKtqBBAopNuaZDe',
      'amount': 50000.0,
      'qty_or_area': 2.0,
      'paid': 50000.0,
      'balance': 0.0,
      'product_id': '5ClFeDnPDJLBrWM3CLzf',
      'custom_length': null,
      'custom_width': null,
    };

    test('a legacy flat sale recovers its price from the bill', () {
      final sale = Sale.fromMap(legacy);
      expect(sale.amount, 50000.0,
          reason: 'The bill must come out of the legacy amount, not be lost.');
      expect(sale.paid, 50000.0);
      expect(sale.balance, 0.0);
      expect(sale.changeDue, 0.0);
      expect(sale.lineItems.single.productId, '5ClFeDnPDJLBrWM3CLzf');
      expect(sale.lineItems.single.salePrice, 25000.0,
          reason: 'Rs 50,000 over 2 units is Rs 25,000 a unit.');
    });

    test('missing optional flags default to a live, non-quote sale', () {
      final sale = Sale.fromMap(legacy);
      expect(sale.isVoided, isFalse);
      expect(sale.isQuote, isFalse);
      expect(sale.customerName, isNull);
    });
  });

  group('a malformed row costs only itself', () {
    // Each of these threw before the fix. Every one is a document that could
    // exist in a shop's archive, and every one used to empty the whole screen.
    final broken = <String, Map<String, dynamic>>{
      'no id': {
        'date': '2026-09-01T10:00:00.000',
        'customer_id': 'c1',
        'line_items': [
          {'product_id': 'p1', 'qty_or_area': 1.0, 'sale_price': 10.0}
        ],
        'paid': 10.0,
      },
      'blank id': {
        'id': '   ',
        'date': '2026-09-01T10:00:00.000',
        'customer_id': 'c1',
        'line_items': [
          {'product_id': 'p1', 'qty_or_area': 1.0, 'sale_price': 10.0}
        ],
        'paid': 10.0,
      },
      'unparseable date': {
        'id': 's1',
        'date': 'not-a-date',
        'customer_id': 'c1',
        'line_items': [
          {'product_id': 'p1', 'qty_or_area': 1.0, 'sale_price': 10.0}
        ],
        'paid': 10.0,
      },
      'missing date': {
        'id': 's1',
        'customer_id': 'c1',
        'line_items': [
          {'product_id': 'p1', 'qty_or_area': 1.0, 'sale_price': 10.0}
        ],
        'paid': 10.0,
      },
      'no customer': {
        'id': 's1',
        'date': '2026-09-01T10:00:00.000',
        'line_items': [
          {'product_id': 'p1', 'qty_or_area': 1.0, 'sale_price': 10.0}
        ],
        'paid': 10.0,
      },
      'no paid': {
        'id': 's1',
        'date': '2026-09-01T10:00:00.000',
        'customer_id': 'c1',
        'line_items': [
          {'product_id': 'p1', 'qty_or_area': 1.0, 'sale_price': 750.0}
        ],
      },
      'legacy with zero quantity': {
        'id': 's1',
        'date': '2026-09-01T10:00:00.000',
        'customer_id': 'c1',
        'product_id': 'p1',
        'amount': 4000.0,
        'qty_or_area': 0.0,
        'paid': 4000.0,
      },
      'legacy with no amount': {
        'id': 's1',
        'date': '2026-09-01T10:00:00.000',
        'customer_id': 'c1',
        'product_id': 'p1',
        'qty_or_area': 2.0,
        'paid': 4000.0,
      },
      'legacy with no product id': {
        'id': 's1',
        'date': '2026-09-01T10:00:00.000',
        'customer_id': 'c1',
        'amount': 4000.0,
        'qty_or_area': 2.0,
        'paid': 4000.0,
      },
    };

    broken.forEach((name, doc) {
      test('a sale with $name still parses', () {
        // The assertion is that this does not throw. Before the fix each of
        // these propagated out of the provider and took the screen with it.
        expect(() => Sale.fromMap(doc), returnsNormally,
            reason: 'A single malformed row must not empty the sales list.');
      });
    });

    test('a missing paid falls back to the bill, not to zero', () {
      final sale = Sale.fromMap(broken['no paid']!);
      expect(sale.paid, 750.0,
          reason: 'Defaulting to 0 would invent a Rs 750 unpaid balance and '
              'understate cash. The line total is what the record was worth.');
    });

    test('a legacy zero quantity keeps its bill instead of dividing by zero',
        () {
      final sale = Sale.fromMap(broken['legacy with zero quantity']!);
      expect(sale.amount, 4000.0,
          reason:
              'qty 0 must not produce Infinity/NaN or trip the qty>0 assert.');
      expect(sale.amount.isFinite, isTrue);
    });
  });

  group('valid sales are unaffected', () {
    test('a round trip through toMap is lossless', () {
      final original = Sale(
        id: 's1',
        date: DateTime.parse('2026-09-01T10:00:00.000'),
        customerId: 'c1',
        customerName: 'Taha',
        lineItems: [
          SaleLineItem(
              productId: 'p1',
              qtyOrArea: 2,
              salePrice: 19500,
              costPriceAtSale: 13000)
        ],
        paid: 40000,
      );
      final reloaded = Sale.fromMap(original.toMap());
      expect(reloaded.amount, original.amount);
      expect(reloaded.paid, original.paid);
      expect(reloaded.changeDue, original.changeDue);
      expect(reloaded.balance, original.balance);
      expect(reloaded.id, original.id);
      expect(reloaded.customerId, original.customerId);
    });

    test('an overpaid sale still reports its change', () {
      // The overpayment case from the changelog: 39,000 bill, 40,000 paid.
      final over = Sale.fromMap({
        ..._goodSale('s2'),
        'line_items': [
          {
            'product_id': 'p1',
            'qty_or_area': 2.0,
            'sale_price': 19500.0,
            'line_discount_amount': 0.0,
            'cost_price_at_sale': 13000.0,
          }
        ],
        'paid': 40000.0,
      });
      expect(over.amount, 39000.0);
      expect(over.changeDue, 1000.0);
      expect(over.balance, 0.0);
      expect(over.netCashReceived, 39000.0,
          reason: 'Change is the customer\'s money leaving the till.');
    });

    test('a walk-in sale with no customer is valid, not malformed', () {
      final sale = Sale.fromMap({
        ..._goodSale('s3'),
        'customer_id': '',
        'customer_name': null,
      });
      expect(sale.customerId, '');
      expect(sale.customerName, isNull);
    });
  });

  group('the provider skips a bad row instead of failing', () {
    // Source-level, because `salesStreamProvider` needs a live Firestore
    // instance and cannot be constructed in a unit test.
    final providerSource =
        File('lib/providers/sale_provider.dart').readAsStringSync();

    test('documents are parsed inside a try/catch', () {
      expect(providerSource, contains('try {'),
          reason: 'One unreadable document must not propagate out of the '
              'provider and blank the billing list, dashboard, reports, export '
              'and khata.');
      expect(providerSource, contains('catch (e)'),
          reason: 'The unparseable row is skipped, not thrown.');
    });

    test('a skipped row is logged with its id', () {
      expect(providerSource, contains('Skipped unreadable sale'),
          reason: 'Silently dropping data is its own bug. The id is needed to '
              'find and repair the document.');
      expect(providerSource, contains(r'${doc.id}'),
          reason: 'The log must identify which document was skipped.');
    });

    test('the eager map is gone', () {
      // Strip comments first: the rationale for this fix legitimately *names*
      // `snap.docs.map(...)`, so a raw substring search would match the
      // explanation and pass/fail for the wrong reason.
      final code = providerSource
          .split('\n')
          .where((l) =>
              !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
          .join('\n');
      expect(code, isNot(contains('snap.docs.map')),
          reason: 'The eager map is what let a single throw take the whole '
              'stream. The loop must catch per document.');
      expect(code, contains('for (final doc in snap.docs)'),
          reason: 'Each document is parsed individually so one failure is '
              'isolated to that row.');
    });
  });
}
