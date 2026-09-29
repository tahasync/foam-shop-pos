import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import 'firebase_providers.dart';

/// Parses a sales snapshot, dropping any single document that cannot be read.
///
/// This is the difference between one bad archived sale costing that one sale
/// and costing the shop its entire sales list. `salesStreamProvider` feeds the
/// billing list, the dashboard totals, Reports, export and the Khata ledger, and
/// every one of them consumes this stream. A `fromMap` that throws anywhere
/// inside the eager `snap.docs.map(...)` propagates straight out of the
/// provider, so the whole screen falls back to its error state: no sales, no
/// revenue, no COGS - and the shopkeeper has no way to tell a corrupt row from
/// an outage.
///
/// `Sale.fromMap` is already defensive about the fields it reads, so this is the
/// backstop for anything it still cannot handle. The dropped document is logged
/// with its id so it can be found and repaired; the rest of the snapshot loads
/// normally.
final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.salesStream().map((snap) {
    final sales = <Sale>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data is! Map) continue;
      try {
        sales.add(Sale.fromMap(Map<String, dynamic>.from(data)));
      } catch (e) {
        developer.log(
          'Skipped unreadable sale ${doc.id}: $e',
          name: 'sales',
        );
      }
    }
    return sales;
  });
});
