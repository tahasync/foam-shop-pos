import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import 'firebase_providers.dart';

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.customersStream.map((snap) {
    return snap.docs.map((doc) {
      return Customer.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  });
});

final customersWithBaqayaProvider = Provider<AsyncValue<List<Customer>>>((ref) {
  final customersAsync = ref.watch(customersStreamProvider);
  return customersAsync.when(
    data: (list) => AsyncValue.data(list.where((c) => c.baqaya > 0).toList()),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
