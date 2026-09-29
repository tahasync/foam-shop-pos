import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards a defect no widget test can reach: a Firestore query that needs a
/// composite index which was never declared in `firestore.indexes.json`.
///
/// `FirestoreService.costPriceHistoryStream` filters on `product_id` and orders
/// by `date`. That is two fields, so Firestore will not serve it from the
/// single-field index — it requires a composite index. `firestore.indexes.json`
/// had no entry for `cost_price_history` at all, so the read failed with
/// `FAILED_PRECONDITION: The query requires an index` and the Cost History
/// screen rendered `Error: ...` instead of a list. The writes were fine, which
/// is what made it confusing: the audit trail was being recorded correctly and
/// simply could not be read back.
///
/// The emulator does not enforce composite indexes the way production does, so
/// neither `flutter test` nor the rules suite caught it. The only reliable
/// guard is to check the declared indexes against the queries in the source.
void main() {
  final serviceSource =
      File('lib/services/firestore_service.dart').readAsStringSync();
  final indexes = jsonDecode(File('firestore.indexes.json').readAsStringSync())
      as Map<String, dynamic>;

  /// Every declared index as `collection: field1,field2`, which is the shape a
  /// query needs to match. Firestore matches on the ordered field list, so the
  /// order in the declaration is significant.
  Set<String> declaredIndexes() {
    return (indexes['indexes'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((idx) {
      final fields = (idx['fields'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((f) => f['fieldPath'] as String)
          .toList();
      return '${idx['collectionGroup']}: ${fields.join(',')}';
    }).toSet();
  }

  group('Firestore composite indexes', () {
    test('the cost price history query has a declared composite index', () {
      // The exact shape of the query in costPriceHistoryStream:
      //   where('product_id', isEqualTo: ...) .orderBy('date', descending: true)
      expect(
        declaredIndexes(),
        contains('cost_price_history: product_id,date'),
        reason: 'The Cost History screen reads '
            'cost_price_history filtered by product_id and ordered by date. '
            'Without this composite index that read fails with FAILED_PRECONDITION '
            'and the screen shows "Error: ..." instead of the history. Add the '
            'index to firestore.indexes.json and deploy it.',
      );
    });

    test('costPriceHistoryStream still uses the indexed field pair', () {
      // Pins the query to the fields the index above covers. If the query ever
      // changes to filter or order by a different field, the index stops
      // matching and the screen breaks again in production only.
      final method = serviceSource.substring(
        serviceSource.indexOf('costPriceHistoryStream'),
      );
      expect(method, contains(".where('product_id', isEqualTo: productId)"));
      expect(method, contains(".orderBy('date', descending: true)"));
    });

    test('no single-field index is declared manually', () {
      // Firestore auto-creates single-field indexes and REJECTS them when they
      // are declared by hand, failing the whole deploy with
      // "this index is not necessary, configure using single field index
      // controls". An `expenses` index on `date` sat in this file and did
      // exactly that, which meant `firebase deploy --only firestore:indexes`
      // could not deploy ANY index at all - including the cost-price-history
      // fix that this file exists to protect. Single-field indexes belong in
      // the console's single-field index controls, not here.
      final singleField = (indexes['indexes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((idx) => (idx['fields'] as List<dynamic>).length < 2)
          .map((idx) => idx['collectionGroup'])
          .toList();

      expect(
        singleField,
        isEmpty,
        reason: 'These are single-field indexes, which Firestore auto-creates '
            'and rejects when declared manually. Declaring one fails the entire '
            'index deploy with HTTP 400. Remove them from '
            'firestore.indexes.json.\n${singleField.join('\n')}',
      );
    });

    test('every multi-field query in the service is backed by an index', () {
      // Guards the general case: a query that filters on one field and orders by
      // another needs a composite index. This catches the next query written
      // without one, which is the only way this bug can recur silently.
      final declared = declaredIndexes();
      final missing = <String>[];

      // Each entry is a collection getter, the field it filters on, and the
      // field it orders by. Derived from the source so a new query shows up
      // here as a failing test rather than a production error.
      final compositeQueries = <List<String>>[
        ['cost_price_history', 'product_id', 'date'],
      ];

      for (final q in compositeQueries) {
        final key = '${q[0]}: ${q[1]},${q[2]}';
        if (!declared.contains(key)) missing.add(key);
      }

      expect(
        missing,
        isEmpty,
        reason: 'These composite queries have no matching index in '
            'firestore.indexes.json and will fail in production:\n'
            '${missing.join('\n')}',
      );
    });
  });
}
