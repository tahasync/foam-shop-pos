import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import 'firebase_providers.dart';

final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.salesStream().map((snap) {
    return snap.docs.map((doc) {
      return Sale.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  });
});
