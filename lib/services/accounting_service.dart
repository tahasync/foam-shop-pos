import 'dart:developer' as developer;
import '../models/product.dart';
import '../models/sale.dart';
import '../models/purchase.dart';
import '../models/expense.dart';
import '../models/payment.dart';
import '../models/supplier_payment.dart';
import '../models/opening_balance.dart';

class AccountingSummary {
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;
  final double cashInHand;
  final double openingCapital;
  final double cashFromSales;
  final double cashFromRecoveries;
  final double cashPaidForPurchases;
  final double cashPaidToSuppliers;
  final double totalCustomerBaqaya;
  final double totalSupplierBaqaya;
  final double inventoryValue;
  final int lowStockCount;
  final int totalProducts;
  final int categoryCount;
  final List<String> negativeStockProducts;

  AccountingSummary({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.cashInHand,
    required this.openingCapital,
    required this.cashFromSales,
    required this.cashFromRecoveries,
    required this.cashPaidForPurchases,
    required this.cashPaidToSuppliers,
    required this.totalCustomerBaqaya,
    required this.totalSupplierBaqaya,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.totalProducts,
    required this.categoryCount,
    this.negativeStockProducts = const [],
  });
}

class AccountingService {
  static double sanitize(num? value) {
    final v = (value ?? 0).toDouble();
    return (v.isNaN || v.isInfinite) ? 0.0 : v;
  }

  static double sanitizeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) {
      if (value.isNaN || value.isInfinite) return 0.0;
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0.0;
  }

  AccountingSummary compute({
    required List<Sale> sales,
    required List<Purchase> purchases,
    required List<Expense> expenses,
    required List<Payment> payments,
    required List<SupplierPayment> supplierPayments,
    required List<Product> products,
    required OpeningBalance? openingBal,
  }) {
    final productMap = {for (final p in products) p.id: p};

    double revenue = 0;
    double cogs = 0;

    for (final sale in sales) {
      if (sale.isVoided || sale.isQuote) continue;
      revenue += sanitize(sale.amount);
      for (final li in sale.lineItems) {
        double unitCost = li.costPriceAtSale;
        if (unitCost <= 0) {
          final product = productMap[li.productId];
          unitCost = product?.costPrice ?? 0;
        }
        if (unitCost <= 0) {
          developer.log('[COGS] Missing cost for sale ${sale.id}, line ${li.productId} — costPrice=0',
              name: 'accounting');
        }
        final lineCogs = sanitize(li.qtyOrArea) * sanitize(unitCost);
        final lineRevenue = sanitize(li.qtyOrArea) * sanitize(li.salePrice);
        if (lineCogs >= lineRevenue && lineRevenue > 0) {
          developer.log('[COGS] Sale ${sale.id}: line ${li.productId} '
              'qty=${li.qtyOrArea} salePrice=${li.salePrice} '
              'costPriceAtSale=${li.costPriceAtSale} '
              'productCostPrice=${productMap[li.productId]?.costPrice} '
              'unitCost=$unitCost lineRevenue=$lineRevenue lineCOGS=$lineCogs',
              name: 'accounting');
        }
        cogs += lineCogs;
      }
    }

    final grossProfit = sanitize(revenue) - sanitize(cogs);
    final totalExpenses = expenses.fold(0.0, (s, e) => s + sanitize(e.amount));
    final netProfit = sanitize(grossProfit) - sanitize(totalExpenses);

    final openingCapital = sanitize(openingBal?.capitalAmount);
    final cashFromSales = sales
        .where((s) => !s.isVoided && !s.isQuote)
        .fold(0.0, (s, x) => s + sanitize(x.paid));
    final cashFromRecoveries =
        payments.fold(0.0, (s, p) => s + sanitize(p.amountCollected));
    final cashPaidForPurchases =
        purchases.fold(0.0, (s, p) => s + sanitize(p.paid));
    final cashPaidToSuppliers =
        supplierPayments.fold(0.0, (s, sp) => s + sanitize(sp.amountPaid));

    final cashInHand = sanitize(openingCapital) +
        sanitize(cashFromSales) +
        sanitize(cashFromRecoveries) -
        sanitize(cashPaidForPurchases) -
        sanitize(totalExpenses) -
        sanitize(cashPaidToSuppliers);

    double totalCustomerBaqaya = 0;
    {
      final customerIds = <String>{};
      for (final s in sales) {
        if (!s.isVoided && !s.isQuote && s.customerId.isNotEmpty) {
          customerIds.add(s.customerId);
        }
      }
      for (final p in payments) {
        if (p.customerId.isNotEmpty) customerIds.add(p.customerId);
      }
      for (final cid in customerIds) {
        final cSales = sales.where(
            (s) => s.customerId == cid && !s.isVoided && !s.isQuote);
        final cPayments = payments.where((p) => p.customerId == cid);
        final total =
            cSales.fold(0.0, (s, x) => s + sanitize(x.amount));
        final paid =
            cSales.fold(0.0, (s, x) => s + sanitize(x.paid));
        final recv =
            cPayments.fold(0.0, (s, x) => s + sanitize(x.amountCollected));
        final bal = sanitize(total) - sanitize(paid) - sanitize(recv);
        if (bal > 0) totalCustomerBaqaya += bal;
      }
    }

    double totalSupplierBaqaya = 0;
    {
      final supplierIds = <String>{};
      for (final p in purchases) {
        if (p.supplierId.isNotEmpty) supplierIds.add(p.supplierId);
      }
      for (final sp in supplierPayments) {
        if (sp.supplierId.isNotEmpty) supplierIds.add(sp.supplierId);
      }
      for (final sid in supplierIds) {
        final sPurchases = purchases.where((p) => p.supplierId == sid);
        final sPayments =
            supplierPayments.where((sp) => sp.supplierId == sid);
        final total =
            sPurchases.fold(0.0, (s, p) => s + sanitize(p.costAmount));
        final paidAtPurchase =
            sPurchases.fold(0.0, (s, p) => s + sanitize(p.paid));
        final paidToSupplier =
            sPayments.fold(0.0, (s, sp) => s + sanitize(sp.amountPaid));
        final bal = sanitize(total) - sanitize(paidAtPurchase) - sanitize(paidToSupplier);
        if (bal > 0) totalSupplierBaqaya += bal;
      }
    }

    double inventoryValue = 0;
    for (final p in products) {
      final unitCost = sanitize(p.costPrice);
      if (unitCost <= 0) {
        developer.log('[COGS] Missing cost for product ${p.id} — costPrice=0, inventory value=0',
            name: 'accounting');
      }
      inventoryValue += sanitize(p.currentStock) * unitCost;
    }

    final lowStockCount = products.where((p) => p.isLowStock).length;
    final totalProducts = products.length;
    final categoryCount = products.map((p) => p.type).toSet().length;

    final negativeStockProducts = products
        .where((p) => p.currentStock < 0)
        .map((p) => p.name)
        .toList();

    return AccountingSummary(
      revenue: revenue,
      cogs: cogs,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      cashInHand: cashInHand,
      openingCapital: openingCapital,
      cashFromSales: cashFromSales,
      cashFromRecoveries: cashFromRecoveries,
      cashPaidForPurchases: cashPaidForPurchases,
      cashPaidToSuppliers: cashPaidToSuppliers,
      totalCustomerBaqaya: totalCustomerBaqaya,
      totalSupplierBaqaya: totalSupplierBaqaya,
      inventoryValue: inventoryValue,
      lowStockCount: lowStockCount,
      totalProducts: totalProducts,
      categoryCount: categoryCount,
      negativeStockProducts: negativeStockProducts,
    );
  }

  AccountingSummary computeVoidAdjustment({
    required Sale sale,
    required AccountingSummary summary,
    required List<Product> products,
  }) {
    final productMap = {for (final p in products) p.id: p};
    double cogsAdjustment = 0;
    for (final li in sale.lineItems) {
      final product = productMap[li.productId];
      if (product != null) {
        cogsAdjustment += sanitize(li.qtyOrArea) * sanitize(product.costPrice);
      }
    }

    final newRevenue = sanitize(summary.revenue) - sanitize(sale.amount);
    final newCogs = sanitize(summary.cogs) - sanitize(cogsAdjustment);
    final newGrossProfit = sanitize(newRevenue) - sanitize(newCogs);
    final newNetProfit = sanitize(newGrossProfit) - sanitize(summary.totalExpenses);
    final newCashFromSales = sanitize(summary.cashFromSales) - sanitize(sale.paid);
    final newCashInHand = sanitize(summary.cashInHand) - sanitize(sale.paid);

    return AccountingSummary(
      revenue: newRevenue,
      cogs: newCogs,
      grossProfit: newGrossProfit,
      totalExpenses: summary.totalExpenses,
      netProfit: newNetProfit,
      cashInHand: newCashInHand,
      openingCapital: summary.openingCapital,
      cashFromSales: newCashFromSales,
      cashFromRecoveries: summary.cashFromRecoveries,
      cashPaidForPurchases: summary.cashPaidForPurchases,
      cashPaidToSuppliers: summary.cashPaidToSuppliers,
      totalCustomerBaqaya: summary.totalCustomerBaqaya,
      totalSupplierBaqaya: summary.totalSupplierBaqaya,
      inventoryValue: summary.inventoryValue,
      lowStockCount: summary.lowStockCount,
      totalProducts: summary.totalProducts,
      categoryCount: summary.categoryCount,
      negativeStockProducts: summary.negativeStockProducts,
    );
  }

  bool canFulfillSale(Sale sale, List<Product> products) {
    final productMap = {for (final p in products) p.id: p};
    for (final li in sale.lineItems) {
      final product = productMap[li.productId];
      if (product == null) return false;
      if (product.currentStock < li.qtyOrArea) return false;
    }
    return true;
  }

  String? validateSale(Sale sale, List<Product> products) {
    if (sale.lineItems.isEmpty) return 'Add at least one product';
    if (sale.customerId.isEmpty) return 'Select a customer';
    if (sale.amount <= 0) return 'Sale amount must be positive';
    if (sale.paid < 0) return 'Paid amount cannot be negative';
    if (!canFulfillSale(sale, products)) return 'Insufficient stock';
    return null;
  }

  AccountingSummary recomputeForPeriod({
    required List<Sale> sales,
    required List<Purchase> purchases,
    required List<Expense> expenses,
    required List<Payment> payments,
    required List<SupplierPayment> supplierPayments,
    required List<Product> products,
    required OpeningBalance? openingBal,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    final filteredSales = sales.where((s) =>
        !s.date.isBefore(startDate) && !s.date.isAfter(endOfDay)).toList();
    final filteredPurchases = purchases.where((p) =>
        !p.date.isBefore(startDate) && !p.date.isAfter(endOfDay)).toList();
    final filteredExpenses = expenses.where((e) =>
        !e.date.isBefore(startDate) && !e.date.isAfter(endOfDay)).toList();
    final filteredPayments = payments.where((p) =>
        !p.date.isBefore(startDate) && !p.date.isAfter(endOfDay)).toList();
    final filteredSupplierPayments = supplierPayments.where((sp) =>
        !sp.date.isBefore(startDate) && !sp.date.isAfter(endOfDay)).toList();

    return compute(
      sales: filteredSales,
      purchases: filteredPurchases,
      expenses: filteredExpenses,
      payments: filteredPayments,
      supplierPayments: filteredSupplierPayments,
      products: products,
      openingBal: openingBal,
    );
  }

  double calculateProductCostAfterRestock(Product product, double restockQty, double restockUnitCost) {
    if (restockQty <= 0) return product.costPrice;
    if (product.currentStock <= 0) return restockUnitCost;
    final totalCurrentValue = sanitize(product.currentStock) * sanitize(product.costPrice);
    final totalNewValue = sanitize(restockQty) * sanitize(restockUnitCost);
    final totalUnits = sanitize(product.currentStock) + sanitize(restockQty);
    if (totalUnits <= 0) return 0;
    return (totalCurrentValue + totalNewValue) / totalUnits;
  }

  Product restockProduct(Product product, double restockQty, double restockUnitCost) {
    final newCost = calculateProductCostAfterRestock(product, restockQty, restockUnitCost);
    return product.copyWith(
      currentStock: product.currentStock + restockQty,
      costPrice: newCost,
    );
  }

  String? validateRestock(double quantity, double unitCost) {
    if (quantity <= 0) return 'Restock quantity must be positive';
    if (unitCost <= 0) return 'Unit cost must be positive';
    return null;
  }

  bool canCancelSale(Sale sale) {
    if (sale.isVoided) return false;
    if (sale.isQuote) return false;
    return true;
  }

  String? validatePayment(double amount, double outstanding) {
    if (amount <= 0) return 'Enter a positive amount';
    if (amount > outstanding) return 'Amount exceeds outstanding balance';
    return null;
  }
}
