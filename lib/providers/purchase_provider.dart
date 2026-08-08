import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase.dart';
import 'firebase_providers.dart';

final purchasesStreamProvider = StreamProvider<List<Purchase>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.purchasesStream().map((snap) {
    return snap.docs.map((doc) {
      return Purchase.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  });
});
