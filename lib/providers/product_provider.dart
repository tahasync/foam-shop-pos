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
