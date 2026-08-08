import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import 'firebase_providers.dart';

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.productsStream.map((snap) {
    return snap.docs.map((doc) {
      return Product.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  });
});

final lowStockProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(productsStreamProvider);
  return products.when(
    data: (list) => AsyncValue.data(list.where((p) => p.isLowStock).toList()),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
