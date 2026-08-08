import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/opening_balance.dart';
import '../services/accounting_service.dart';
import 'firebase_providers.dart';
import 'product_provider.dart';
import 'sale_provider.dart';
import 'purchase_provider.dart';
import 'expense_provider.dart';
import 'payment_provider.dart';
import 'supplier_payment_provider.dart';

final accountingServiceProvider = Provider<AccountingService>((ref) => AccountingService());

final openingBalanceStreamProvider = StreamProvider<OpeningBalance?>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.openingBalanceStream.map((snap) {
    if (snap.docs.isEmpty) return null;
    return OpeningBalance.fromMap(snap.docs.first.data() as Map<String, dynamic>);
  });
});

final accountingSummaryProvider = Provider<AsyncValue<AccountingSummary>>((ref) {
  final salesAsync = ref.watch(salesStreamProvider);
  final purchasesAsync = ref.watch(purchasesStreamProvider);
  final expensesAsync = ref.watch(expensesStreamProvider);
  final paymentsAsync = ref.watch(paymentsStreamProvider);
  final supplierPaymentsAsync = ref.watch(supplierPaymentsStreamProvider);
  final productsAsync = ref.watch(productsStreamProvider);
  final openingBalAsync = ref.watch(openingBalanceStreamProvider);

  if (salesAsync.isLoading || purchasesAsync.isLoading ||
      expensesAsync.isLoading || paymentsAsync.isLoading ||
      supplierPaymentsAsync.isLoading || productsAsync.isLoading ||
      openingBalAsync.isLoading) {
    return const AsyncValue.loading();
  }

  final sales = salesAsync.asData?.value ?? [];
  final purchases = purchasesAsync.asData?.value ?? [];
  final expenses = expensesAsync.asData?.value ?? [];
  final payments = paymentsAsync.asData?.value ?? [];
  final supplierPayments = supplierPaymentsAsync.asData?.value ?? [];
  final products = productsAsync.asData?.value ?? [];
  final openingBal = openingBalAsync.asData?.value;

  final service = ref.read(accountingServiceProvider);
  final result = service.compute(
    sales: sales,
    purchases: purchases,
    expenses: expenses,
    payments: payments,
    supplierPayments: supplierPayments,
    products: products,
    openingBal: openingBal,
  );

  return AsyncValue.data(result);
});
