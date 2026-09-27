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
