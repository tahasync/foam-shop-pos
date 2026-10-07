import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/models/product.dart';
import 'package:foam_shop_register/providers/sales_provider.dart';

Product product(String id) => Product(
      id: id,
      name: 'Foam $id',
      type: 'Foam',
      sizeLength: 6,
      sizeWidth: 4,
      thickness: 2,
      density: 20,
      unitType: 'per_sqft',
      unitPrice: 450,
      currentStock: 100,
      lowStockThreshold: 5,
    );

void main() {
  test('the cart accepts up to the rules-supported line-item limit', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(salesProvider.notifier);

    for (var i = 0; i < maxSaleLineItems; i++) {
      notifier.addToCart(product('p$i'));
    }

    expect(container.read(salesProvider).cart, hasLength(maxSaleLineItems));
  });

  test('the cart cannot add an eighth distinct product', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(salesProvider.notifier);

    for (var i = 0; i < maxSaleLineItems + 1; i++) {
      notifier.addToCart(product('p$i'));
    }

    expect(container.read(salesProvider).cart, hasLength(maxSaleLineItems));
    expect(container.read(salesProvider).cart.last.product.id, 'p6');
  });

  test('adding an existing product still increments its quantity at the cap',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(salesProvider.notifier);

    for (var i = 0; i < maxSaleLineItems; i++) {
      notifier.addToCart(product('p$i'));
    }
    notifier.addToCart(product('p0'));

    expect(container.read(salesProvider).cart, hasLength(maxSaleLineItems));
    expect(container.read(salesProvider).cart.first.quantity, 2);
  });
}
