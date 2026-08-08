import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment.dart';
import 'firebase_providers.dart';

final paymentsStreamProvider = StreamProvider<List<Payment>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.paymentsStream().map((snap) {
    return snap.docs.map((doc) {
      return Payment.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  });
});
