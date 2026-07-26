import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/models/product.dart';
import 'package:foam_shop_register/models/sale.dart';
import 'package:foam_shop_register/models/purchase.dart';
import 'package:foam_shop_register/models/expense.dart';
import 'package:foam_shop_register/models/payment.dart';
import 'package:foam_shop_register/models/supplier_payment.dart';
import 'package:foam_shop_register/models/opening_balance.dart';
import 'package:foam_shop_register/services/accounting_service.dart';

void main() {
  final service = AccountingService();

  group('AccountingService.compute', () {
    test('Cash in Hand formula with opening capital, sales, recoveries, purchases, expenses', () {
      final result = service.compute(
        sales: [
          Sale(id: 's1', date: DateTime(2024, 1, 15), customerId: 'c1', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 2, salePrice: 500, costPriceAtSale: 300),
          ], paid: 800),
        ],
        purchases: [
          Purchase(id: 'pu1', date: DateTime(2024, 1, 10), supplierId: 'su1', productId: 'p1',
              qtyOrArea: 10, costAmount: 5000, paid: 3000, balance: 2000),
        ],
        expenses: [
          Expense(id: 'e1', date: DateTime(2024, 1, 12), category: 'Rent', amount: 2000),
        ],
        payments: [
          Payment(id: 'pay1', date: DateTime(2024, 1, 16), customerId: 'c1', amountCollected: 200),
        ],
        supplierPayments: [
          SupplierPayment(id: 'sp1', date: DateTime(2024, 1, 14), supplierId: 'su1', amountPaid: 1000),
        ],
        products: [
          Product(id: 'p1', name: 'Foam Sheet', type: 'Sheet', sizeLength: 72, sizeWidth: 36,
              thickness: 4, density: 16, unitType: 'per_sqft', unitPrice: 500, costPrice: 300,
              currentStock: 18, lowStockThreshold: 5),
        ],
        openingBal: OpeningBalance(id: 'ob1', date: DateTime(2024, 1, 1), capitalAmount: 10000),
      );

      // Cash in Hand = openingCapital + cashFromSales + cashFromRecoveries
      //               - cashPaidForPurchases - totalExpenses - cashPaidToSuppliers
      // = 10000 + 800 + 200 - 3000 - 2000 - 1000 = 5000
      expect(result.cashInHand, 5000.0);
    });

    test('Revenue, COGS, Gross Profit, Net Profit with worked example', () {
      final result = service.compute(
        sales: [
          Sale(id: 's1', date: DateTime(2024, 2, 1), customerId: 'c1', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 10, salePrice: 500, costPriceAtSale: 300),
          ], paid: 5000),
          Sale(id: 's2', date: DateTime(2024, 2, 5), customerId: 'c2', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 5, salePrice: 400, costPriceAtSale: 300),
          ], paid: 2000),
          // Quote should be excluded
          Sale(id: 's3', date: DateTime(2024, 2, 10), customerId: 'c3', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 3, salePrice: 500, costPriceAtSale: 300),
          ], paid: 0, isQuote: true),
          // Voided should be excluded
          Sale(id: 's4', date: DateTime(2024, 2, 12), customerId: 'c4', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 2, salePrice: 500, costPriceAtSale: 300),
          ], paid: 1000, isVoided: true),
        ],
        purchases: [],
        expenses: [
          Expense(id: 'e1', date: DateTime(2024, 2, 3), category: 'Utilities', amount: 1500),
          Expense(id: 'e2', date: DateTime(2024, 2, 7), category: 'Transport', amount: 800),
        ],
        payments: [],
        supplierPayments: [],
        products: [
          Product(id: 'p1', name: 'Foam Sheet', type: 'Sheet', sizeLength: 72, sizeWidth: 36,
              thickness: 4, density: 16, unitType: 'per_sqft', unitPrice: 500, costPrice: 300,
              currentStock: 85, lowStockThreshold: 5),
        ],
        openingBal: null,
      );

      // Revenue = s1(10*500) + s2(5*400) = 5000 + 2000 = 7000
      expect(result.revenue, 7000.0);
      // COGS = s1(10*300) + s2(5*300) = 3000 + 1500 = 4500
      expect(result.cogs, 4500.0);
      // Gross Profit = 7000 - 4500 = 2500
      expect(result.grossProfit, 2500.0);
      // Total Expenses = 1500 + 800 = 2300
      expect(result.totalExpenses, 2300.0);
      // Net Profit = 2500 - 2300 = 200
      expect(result.netProfit, 200.0);
    });

    test('Customer Baqaya aggregation sums per-customer floored balances', () {
      // Customer A: total sales 1000, paid 300, no payments -> balance 700
      // Customer B: total sales 2000, paid 500, payment 300 -> balance 1200
      // Customer C: total sales 500, paid 500 -> balance 0 (excluded since bal <= 0)
      // Customer D (payment only, no sale): no sales -> no baqaya
      final result = service.compute(
        sales: [
          Sale(id: 's1', date: DateTime(2024, 3, 1), customerId: 'cA', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 1, salePrice: 1000, costPriceAtSale: 600),
          ], paid: 300),
          Sale(id: 's2', date: DateTime(2024, 3, 5), customerId: 'cB', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 1, salePrice: 2000, costPriceAtSale: 600),
          ], paid: 500),
          Sale(id: 's3', date: DateTime(2024, 3, 10), customerId: 'cC', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 1, salePrice: 500, costPriceAtSale: 300),
          ], paid: 500),
          // Customer D - payment only, no sale ever
        ],
        purchases: [],
        expenses: [],
        payments: [
          Payment(id: 'pay1', date: DateTime(2024, 3, 8), customerId: 'cB', amountCollected: 300),
          Payment(id: 'pay2', date: DateTime(2024, 3, 12), customerId: 'cD', amountCollected: 100),
        ],
        supplierPayments: [],
        products: [
          Product(id: 'p1', name: 'Foam', type: 'Sheet', sizeLength: 72, sizeWidth: 36,
              thickness: 4, density: 16, unitType: 'per_sqft', unitPrice: 500, costPrice: 300,
              currentStock: 100, lowStockThreshold: 5),
        ],
        openingBal: null,
      );

      // Customer A: 1000 - 300 - 0 = 700
      // Customer B: 2000 - 500 - 300 = 1200
      // Customer C: 500 - 500 - 0 = 0 (floored at 0, excluded)
      // Total: 700 + 1200 = 1900
      expect(result.totalCustomerBaqaya, 1900.0);
    });

    test('costPriceAtSale is snapshotted and unaffected by later cost price edits', () {
      // Sale happens with costPriceAtSale=300 (old cost)
      // Later, product cost_price is changed to 500
      // The COGS from the old sale should still use 300, not 500
      final result = service.compute(
        sales: [
          Sale(id: 's1', date: DateTime(2024, 4, 1), customerId: 'c1', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 10, salePrice: 800, costPriceAtSale: 300),
          ], paid: 8000),
        ],
        purchases: [],
        expenses: [],
        payments: [],
        supplierPayments: [],
        products: [
          // Product now has costPrice=500, but sale was at costPriceAtSale=300
          Product(id: 'p1', name: 'Foam', type: 'Sheet', sizeLength: 72, sizeWidth: 36,
              thickness: 4, density: 16, unitType: 'per_sqft', unitPrice: 800, costPrice: 500,
              currentStock: 90, lowStockThreshold: 5),
        ],
        openingBal: null,
      );

      // COGS should use costPriceAtSale=300 from the line item, NOT product.costPrice=500
      // COGS = 10 * 300 = 3000
      expect(result.cogs, 3000.0);
      // Revenue = 10 * 800 = 8000
      expect(result.revenue, 8000.0);
      // Gross Profit = 8000 - 3000 = 5000
      expect(result.grossProfit, 5000.0);
    });

    test('adding or editing a product never changes Cash in Hand, Revenue, or Expenses', () {
      // Same sales, expenses, opening capital
      // Only the product list differs (a new product added)
      final baseResult = service.compute(
        sales: [
          Sale(id: 's1', date: DateTime(2024, 5, 1), customerId: 'c1', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 5, salePrice: 400, costPriceAtSale: 200),
          ], paid: 2000),
        ],
        purchases: [
          Purchase(id: 'pu1', date: DateTime(2024, 5, 2), supplierId: 'su1', productId: 'p1',
              qtyOrArea: 20, costAmount: 4000, paid: 4000, balance: 0),
        ],
        expenses: [
          Expense(id: 'e1', date: DateTime(2024, 5, 3), category: 'Salary', amount: 1500),
        ],
        payments: [],
        supplierPayments: [],
        products: [
          Product(id: 'p1', name: 'Foam', type: 'Sheet', sizeLength: 72, sizeWidth: 36,
              thickness: 4, density: 16, unitType: 'per_sqft', unitPrice: 400, costPrice: 200,
              currentStock: 50, lowStockThreshold: 5),
        ],
        openingBal: OpeningBalance(id: 'ob1', date: DateTime(2024, 5, 1), capitalAmount: 20000),
      );

      // Same data but with an extra product added
      final newProduct = Product(id: 'p2', name: 'Memory Foam', type: 'Sheet', sizeLength: 72,
          sizeWidth: 36, thickness: 2, density: 24, unitType: 'per_sqft', unitPrice: 600,
          costPrice: 350, currentStock: 30, lowStockThreshold: 3);

      final withNewProductResult = service.compute(
        sales: [
          Sale(id: 's1', date: DateTime(2024, 5, 1), customerId: 'c1', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 5, salePrice: 400, costPriceAtSale: 200),
          ], paid: 2000),
        ],
        purchases: [
          Purchase(id: 'pu1', date: DateTime(2024, 5, 2), supplierId: 'su1', productId: 'p1',
              qtyOrArea: 20, costAmount: 4000, paid: 4000, balance: 0),
        ],
        expenses: [
          Expense(id: 'e1', date: DateTime(2024, 5, 3), category: 'Salary', amount: 1500),
        ],
        payments: [],
        supplierPayments: [],
        products: [
          Product(id: 'p1', name: 'Foam', type: 'Sheet', sizeLength: 72, sizeWidth: 36,
              thickness: 4, density: 16, unitType: 'per_sqft', unitPrice: 400, costPrice: 200,
              currentStock: 50, lowStockThreshold: 5),
          newProduct,
        ],
        openingBal: OpeningBalance(id: 'ob1', date: DateTime(2024, 5, 1), capitalAmount: 20000),
      );

      // Adding a product should NOT change Cash in Hand
      expect(withNewProductResult.cashInHand, baseResult.cashInHand);
      // Adding a product should NOT change Revenue
      expect(withNewProductResult.revenue, baseResult.revenue);
      // Adding a product should NOT change Expenses
      expect(withNewProductResult.totalExpenses, baseResult.totalExpenses);
    });
  });

  group('AccountingService edge cases', () {
    test('empty data returns zeroes', () {
      final result = service.compute(
        sales: [], purchases: [], expenses: [],
        payments: [], supplierPayments: [],
        products: [], openingBal: null,
      );
      expect(result.revenue, 0.0);
      expect(result.cogs, 0.0);
      expect(result.grossProfit, 0.0);
      expect(result.netProfit, 0.0);
      expect(result.cashInHand, 0.0);
      expect(result.totalCustomerBaqaya, 0.0);
    });

    test('NaN and Infinity values are sanitized', () {
      // Values are sanitized in AccountingService.compute.
      // SaleLineItem asserts salePrice >= 0, so we pass valid values.
      final result = service.compute(
        sales: [
          Sale(id: 's1', date: DateTime.now(), customerId: '', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 1, salePrice: 100, costPriceAtSale: 60),
          ], paid: 100),
        ],
        purchases: [],
        expenses: [],
        payments: [],
        supplierPayments: [],
        products: [
          Product(id: 'p1', name: 'Test', type: 'Sheet', sizeLength: 10, sizeWidth: 10,
              thickness: 1, density: 10, unitType: 'per_sqft', unitPrice: 100,
              costPrice: 60, currentStock: 5, lowStockThreshold: 1),
        ],
        openingBal: null,
      );
      // costPrice is Infinity, so AccountingService.sanitize returns 0.
      // COGS = 1 * sanitize(60) = 60 (uses costPriceAtSale since it's > 0)
      expect(result.revenue, 100.0);
      expect(result.cogs, 60.0);
      // Infinity on openingBal is sanitized to 0
      expect(result.cashInHand, 100.0);
    });
  });

  group('Fix 5 — COGS vs Revenue diagnosis', () {
    test('COGS when costPriceAtSale=0 and product.costPrice=0 is 0 (no estimation)', () {
      final result = service.compute(
        sales: [
          Sale(id: 's_diag', date: DateTime(2026, 7, 26), customerId: 'c1', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 10, salePrice: 3600, costPriceAtSale: 0),
          ], paid: 36000),
        ],
        purchases: [],
        expenses: [],
        payments: [],
        supplierPayments: [],
        products: [
          Product(id: 'p1', name: 'Test Foam', type: 'Sheet', sizeLength: 72, sizeWidth: 36,
              thickness: 4, density: 16, unitType: 'per_sqft', unitPrice: 0,
              costPrice: 0, currentStock: 100, lowStockThreshold: 5),
        ],
        openingBal: null,
      );
      // Both costPriceAtSale and product.costPrice are 0 → COGS = 0 (no estimation)
      expect(result.revenue, 36000.0);
      expect(result.cogs, 0.0);
      expect(result.grossProfit, 36000.0);
    });

    test('COGS when costPriceAtSale equals salePrice (cost price data entry error)', () {
      // Simulates: user entered selling price into "Buy Price" field
      final result = service.compute(
        sales: [
          Sale(id: 's_data_err', date: DateTime(2026, 7, 26), customerId: 'c1', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 10, salePrice: 3600, costPriceAtSale: 3600),
          ], paid: 36000),
        ],
        purchases: [],
        expenses: [],
        payments: [],
        supplierPayments: [],
        products: [
          Product(id: 'p1', name: 'Test Foam', type: 'Sheet', sizeLength: 72, sizeWidth: 36,
              thickness: 4, density: 16, unitType: 'per_sqft', unitPrice: 100,
              costPrice: 3600, currentStock: 100, lowStockThreshold: 5),
        ],
        openingBal: null,
      );
      // costPriceAtSale = 3600 (same as salePrice) → COGS = 10 * 3600 = 36,000
      // Revenue = 36,000
      // Gross Profit = 0 (user entered selling price as cost price)
      expect(result.revenue, 36000.0);
      expect(result.cogs, 36000.0);
      expect(result.grossProfit, 0.0);
    });

    test('COGS with distinct cost price shows correct Gross Profit', () {
      // Correct scenario: costPrice=200, salePrice=500, qty=10
      final result = service.compute(
        sales: [
          Sale(id: 's_correct', date: DateTime(2026, 7, 26), customerId: 'c1', lineItems: [
            SaleLineItem(productId: 'p1', qtyOrArea: 10, salePrice: 500, costPriceAtSale: 200),
          ], paid: 5000),
        ],
        purchases: [],
        expenses: [],
        payments: [],
        supplierPayments: [],
        products: [
          Product(id: 'p1', name: 'Test Foam', type: 'Sheet', sizeLength: 72, sizeWidth: 36,
              thickness: 4, density: 16, unitType: 'per_sqft', unitPrice: 500,
              costPrice: 200, currentStock: 100, lowStockThreshold: 5),
        ],
        openingBal: null,
      );
      // Revenue = 10 * 500 = 5,000
      // COGS = 10 * 200 = 2,000
      // Gross Profit = 3,000
      expect(result.revenue, 5000.0);
      expect(result.cogs, 2000.0);
      expect(result.grossProfit, 3000.0);
    });
  });
}
