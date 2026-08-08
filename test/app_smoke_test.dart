import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/services/accounting_service.dart';
import 'package:foam_shop_register/models/product.dart';
import 'package:foam_shop_register/models/sale.dart';

void main() {
  testWidgets('App smoke test — basic Material rendering', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Digital Register')),
        ),
      ),
    );
    expect(find.text('Digital Register'), findsOneWidget);
  });

  test('Core model + COGS formula - product with distinct buy/sell computes correct gross profit', () {
    final product = Product(
      id: 'test1', name: 'Foam', type: 'Sheet', sizeLength: 72, sizeWidth: 36,
      thickness: 4, density: 16, unitType: 'per_sqft', unitPrice: 0,
      costPrice: 100, currentStock: 50, lowStockThreshold: 5,
    );

    // Sell at 150 (negotiated per-sale, not from product)
    final sale = Sale(
      id: 's1', date: DateTime(2026, 7, 26), customerId: 'c1',
      lineItems: [
        SaleLineItem(productId: 'test1', qtyOrArea: 5, salePrice: 150, costPriceAtSale: 100),
      ],
      paid: 750,
    );

    final result = AccountingService().compute(
      sales: [sale], purchases: [], expenses: [],
      payments: [], supplierPayments: [],
      products: [product], openingBal: null,
    );
    expect(result.revenue, 750.0);     // 5 × 150
    expect(result.cogs, 500.0);        // 5 × 100
    expect(result.grossProfit, 250.0); // 750 - 500

    // Sell SAME product at different price 180
    final sale2 = Sale(
      id: 's2', date: DateTime(2026, 7, 26), customerId: 'c1',
      lineItems: [
        SaleLineItem(productId: 'test1', qtyOrArea: 5, salePrice: 180, costPriceAtSale: 100),
      ],
      paid: 900,
    );

    final result2 = AccountingService().compute(
      sales: [sale2], purchases: [], expenses: [],
      payments: [], supplierPayments: [],
      products: [product], openingBal: null,
    );
    expect(result2.revenue, 900.0);     // 5 × 180
    expect(result2.cogs, 500.0);        // 5 × 100
    expect(result2.grossProfit, 400.0); // 900 - 500
  });
}
