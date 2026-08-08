import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier.dart';
import 'firebase_providers.dart';

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.suppliersStream.map((snap) {
    return snap.docs.map((doc) {
      return Supplier.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  });
});
