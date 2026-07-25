class SaleLineItem {
  final String productId;
  final String? name;
  final double? customLength;
  final double? customWidth;
  final double qtyOrArea;
  final double salePrice;
  final double lineDiscountAmount;
  final double costPriceAtSale;

  SaleLineItem({
    required this.productId,
    this.name,
    this.customLength,
    this.customWidth,
    required this.qtyOrArea,
    required this.salePrice,
    this.lineDiscountAmount = 0,
    this.costPriceAtSale = 0,
  }) : assert(productId.trim().isNotEmpty, 'Line item must have a product ID'),
       assert(qtyOrArea > 0, 'Quantity must be positive'),
       assert(salePrice >= 0, 'Price cannot be negative'),
       assert(lineDiscountAmount >= 0, 'Discount cannot be negative');

  double get lineTotal => (qtyOrArea * salePrice) - lineDiscountAmount;

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'name': name,
        'custom_length': customLength,
        'custom_width': customWidth,
        'qty_or_area': qtyOrArea,
        'sale_price': salePrice,
        'line_discount_amount': lineDiscountAmount,
        'cost_price_at_sale': costPriceAtSale,
      };

  factory SaleLineItem.fromMap(Map<String, dynamic> map) {
    final productId = map['product_id'];
    if (productId is! String || productId.trim().isEmpty) {
      throw const FormatException('Invalid sale line item: missing product_id');
    }
    final qtyOrArea = map['qty_or_area'];
    if (qtyOrArea == null || (qtyOrArea is! num) || qtyOrArea.toDouble() <= 0) {
      throw const FormatException('Invalid sale line item: qty_or_area must be positive');
    }
    return SaleLineItem(
      productId: productId.trim(),
      name: map['name'] as String?,
      customLength: (map['custom_length'] as num?)?.toDouble(),
      customWidth: (map['custom_width'] as num?)?.toDouble(),
      qtyOrArea: qtyOrArea.toDouble(),
      salePrice: ((map['sale_price'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      lineDiscountAmount: ((map['line_discount_amount'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      costPriceAtSale: ((map['cost_price_at_sale'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
    );
  }
}

class Sale {
  final String id;
  final DateTime date;
  final String customerId;
  final String? customerName;
  final List<SaleLineItem> lineItems;
  final double paid;
  final double? discountAmount;
  final double? discountPercent;
  final double? deliveryCharge;
  final double? cuttingCharge;
  final bool isVoided;
  final String? voidReason;
  final bool isQuote;
  final String? transactionUuid;

  Sale({
    required this.id,
    required this.date,
    required this.customerId,
    this.customerName,
    required this.lineItems,
    required this.paid,
    this.discountAmount,
    this.discountPercent,
    this.deliveryCharge,
    this.cuttingCharge,
    this.isVoided = false,
    this.voidReason,
    this.isQuote = false,
    this.transactionUuid,
  }) : assert(id.trim().isNotEmpty, 'Sale ID is required'),
       assert(lineItems.isNotEmpty, 'Sale must have at least one line item'),
       assert(paid >= 0, 'Paid amount cannot be negative');

  double get subtotal => lineItems.fold(0.0, (s, li) => s + li.lineTotal);
  double get totalDiscount => discountAmount ?? (subtotal * (discountPercent ?? 0) / 100);
  double get amount => subtotal - totalDiscount + (deliveryCharge ?? 0) + (cuttingCharge ?? 0);
  double get balance => amount - paid;

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'customer_id': customerId,
        'customer_name': customerName,
        'line_items': lineItems.map((li) => li.toMap()).toList(),
        'paid': paid,
        'discount_amount': discountAmount,
        'discount_percent': discountPercent,
        'delivery_charge': deliveryCharge,
        'cutting_charge': cuttingCharge,
        'is_voided': isVoided,
        'void_reason': voidReason,
        'is_quote': isQuote,
        'transaction_uuid': transactionUuid ?? id,
      };

  factory Sale.fromMap(Map<String, dynamic> map) {
    // Backward compat: old flat schema -> line item
    List<SaleLineItem> items;
    if (map.containsKey('line_items')) {
      items = (map['line_items'] as List<dynamic>)
          .map((li) => SaleLineItem.fromMap(li as Map<String, dynamic>))
          .toList();
    } else {
      items = [
        SaleLineItem(
          productId: map['product_id'] as String,
          customLength: (map['custom_length'] as num?)?.toDouble(),
          customWidth: (map['custom_width'] as num?)?.toDouble(),
          qtyOrArea: (map['qty_or_area'] as num).toDouble(),
          salePrice: (map['sale_price'] as num?)?.toDouble() ?? (map['amount'] as num).toDouble() / (map['qty_or_area'] as num).toDouble(),
        ),
      ];
    }
    return Sale(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      customerId: map['customer_id'] as String,
      customerName: map['customer_name'] as String?,
      lineItems: items,
      paid: (map['paid'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble(),
      discountPercent: (map['discount_percent'] as num?)?.toDouble(),
      deliveryCharge: (map['delivery_charge'] as num?)?.toDouble(),
      cuttingCharge: (map['cutting_charge'] as num?)?.toDouble(),
      isVoided: map['is_voided'] as bool? ?? false,
      voidReason: map['void_reason'] as String?,
      isQuote: map['is_quote'] as bool? ?? false,
      transactionUuid: map['transaction_uuid'] as String?,
    );
  }
}
