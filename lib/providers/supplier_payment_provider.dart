import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier_payment.dart';
import 'firebase_providers.dart';

final supplierPaymentsStreamProvider = StreamProvider<List<SupplierPayment>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.supplierPaymentsStream().map((snap) {
    return snap.docs.map((doc) {
      return SupplierPayment.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  });
});
