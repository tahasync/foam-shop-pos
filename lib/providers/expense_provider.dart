import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import 'firebase_providers.dart';

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.expensesStream().map((snap) {
    return snap.docs.map((doc) {
      return Expense.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  });
});
