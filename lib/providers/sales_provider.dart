import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';

class CartItem {
  final Product product;
  int quantity;
  double salePrice;

  CartItem({required this.product, this.quantity = 1, this.salePrice = 0});

  double get lineTotal => quantity * salePrice;
}

class SalesState {
  final List<CartItem> cart;
  final String customerId;
  final String customerName;
  final List<String> recentProductIds;

  const SalesState({
    this.cart = const [],
    this.customerId = '',
    this.customerName = 'Walk-in Customer',
    this.recentProductIds = const [],
  });

  int get totalItems => cart.fold(0, (s, i) => s + i.quantity);

  double get subtotal => cart.fold(0.0, (s, i) => s + i.lineTotal);

  SalesState copyWith({
    List<CartItem>? cart,
    String? customerId,
    String? customerName,
    List<String>? recentProductIds,
  }) {
    return SalesState(
      cart: cart ?? this.cart,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      recentProductIds: recentProductIds ?? this.recentProductIds,
    );
  }
}

class SalesNotifier extends Notifier<SalesState> {
  @override
  SalesState build() => const SalesState();

  void addToCart(Product product) {
    if (product.currentStock <= 0) return;
    final recent = List<String>.from(state.recentProductIds);
    recent.remove(product.id);
    recent.insert(0, product.id);
    if (recent.length > 6) recent.removeLast();
    final existing = state.cart.where((c) => c.product.id == product.id).firstOrNull;
    if (existing != null) {
      if (existing.quantity >= product.currentStock) return;
      existing.quantity++;
      state = state.copyWith(cart: [...state.cart], recentProductIds: recent);
    } else {
      state = state.copyWith(
        cart: [...state.cart, CartItem(product: product, quantity: 1)],
        recentProductIds: recent,
      );
    }
  }

  void removeFromCart(String productId) {
    state = state.copyWith(cart: state.cart.where((c) => c.product.id != productId).toList());
  }

  void changeQty(String productId, int delta) {
    final idx = state.cart.indexWhere((c) => c.product.id == productId);
    if (idx == -1) return;
    final item = state.cart[idx];
    final newQty = item.quantity + delta;
    if (newQty < 1) {
      removeFromCart(productId);
      return;
    }
    if (newQty > item.product.currentStock) return;
    final updated = [...state.cart];
    updated[idx] = CartItem(product: item.product, quantity: newQty, salePrice: item.salePrice);
    state = state.copyWith(cart: updated);
  }

  void updateItemPrice(String productId, double newPrice) {
    final idx = state.cart.indexWhere((c) => c.product.id == productId);
    if (idx == -1) return;
    final updated = [...state.cart];
    updated[idx] = CartItem(
      product: updated[idx].product,
      quantity: updated[idx].quantity,
      salePrice: newPrice,
    );
    state = state.copyWith(cart: updated);
  }

  void setCustomer(String id, String name) {
    state = state.copyWith(customerId: id, customerName: name);
  }

  void clearCart() {
    state = state.copyWith(cart: []);
  }
}

final salesProvider = NotifierProvider<SalesNotifier, SalesState>(SalesNotifier.new);
