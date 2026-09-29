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
  })  : assert(productId.trim().isNotEmpty, 'Line item must have a product ID'),
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
      throw const FormatException(
          'Invalid sale line item: qty_or_area must be positive');
    }
    return SaleLineItem(
      productId: productId.trim(),
      name: map['name'] as String?,
      customLength: (map['custom_length'] as num?)?.toDouble(),
      customWidth: (map['custom_width'] as num?)?.toDouble(),
      qtyOrArea: qtyOrArea.toDouble(),
      salePrice: ((map['sale_price'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      lineDiscountAmount:
          ((map['line_discount_amount'] as num?)?.toDouble() ?? 0)
              .clamp(0, 1e9),
      costPriceAtSale:
          ((map['cost_price_at_sale'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
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
  })  : assert(id.trim().isNotEmpty, 'Sale ID is required'),
        assert(lineItems.isNotEmpty, 'Sale must have at least one line item'),
        assert(paid >= 0, 'Paid amount cannot be negative');

  double get subtotal => lineItems.fold(0.0, (s, li) => s + li.lineTotal);
  double get totalDiscount =>
      discountAmount ?? (subtotal * (discountPercent ?? 0) / 100);
  double get amount =>
      subtotal - totalDiscount + (deliveryCharge ?? 0) + (cuttingCharge ?? 0);

  /// What the customer still owes. Never negative.
  ///
  /// This used to be the raw `amount - paid`, which goes *negative* the moment
  /// the customer hands over more than the bill (pay Rs 70,000 for a Rs 69,000
  /// sale and this returned -1,000). A negative balance is not a real thing on a
  /// khata: it is not a debt the customer owes, it is change the shop has to
  /// give back, and every caller had to re-derive that distinction. It also fed
  /// the receipt, which printed "Balance Rs 0 / FULLY PAID" and so stated
  /// nothing at all about the Rs 1,000 the customer was owed — the cashier had
  /// to work it out by hand. Floored here so "balance" can only ever mean
  /// "outstanding", and [changeDue] owns the other direction.
  double get balance {
    final due = amount - paid;
    return due > 0 ? due : 0.0;
  }

  /// Money handed back to the customer because they overpaid.
  ///
  /// Zero when the sale is exact or only partly paid. This is the figure the
  /// receipt prints as "Change" and the cashier reads out before handing over
  /// the goods, so an overpayment is never silently swallowed.
  double get changeDue {
    final over = paid - amount;
    return over > 0 ? over : 0.0;
  }

  /// True when the customer handed over more than the bill, so there is change
  /// to return rather than a balance to collect.
  bool get hasChange => changeDue > 0;

  /// Cash this sale actually leaves in the till.
  ///
  /// An overpayment does not stay in the drawer: the shop gives the excess back
  /// as change, so only `amount` is ever retained. Counting the full `paid`
  /// overstated Cash in Hand by exactly the change on every overpaid sale.
  double get netCashReceived => paid - changeDue;

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
      // Legacy flat document: one product, with the bill as a single `amount`.
      //
      // Both of these used to be hard casts, and one of them a bare division.
      // A legacy document missing `amount`, or carrying `qty_or_area` of 0,
      // therefore threw - and because the sales stream maps every document
      // eagerly, a single such row took down the whole shop's billing list,
      // dashboard, reports and khata. One malformed archived sale should cost
      // that one sale, not the business.
      final qty = (map['qty_or_area'] as num?)?.toDouble() ?? 0;
      final flatAmount = (map['amount'] as num?)?.toDouble() ?? 0;
      // `qty` of 0 would divide to Infinity/NaN and then trip the
      // `qtyOrArea > 0` assert in the constructor. Fall back to 1 so the
      // document still loads with its bill intact, which is what a shopkeeper
      // reading the record needs; the line is flagged by its own quantity.
      final effectiveQty = qty > 0 ? qty : 1.0;
      items = [
        SaleLineItem(
          productId: (map['product_id'] as String?)?.trim().isNotEmpty == true
              ? (map['product_id'] as String).trim()
              : 'unknown',
          customLength: (map['custom_length'] as num?)?.toDouble(),
          customWidth: (map['custom_width'] as num?)?.toDouble(),
          qtyOrArea: effectiveQty,
          // A legacy row with no `sale_price` recovers it from the bill. If the
          // bill is missing too, the price is 0 rather than a crash.
          salePrice: (map['sale_price'] as num?)?.toDouble() ??
              (flatAmount / effectiveQty),
        ),
      ];
    }
    // `id` and `date` were hard casts too. A document missing either threw, and
    // because the sales stream is eager, that removed the entire shop's sales
    // from the billing list, dashboard, reports and khata over one bad row.
    // Both now degrade instead: an unknown id, and an epoch date that sorts to
    // the bottom of a list rather than taking the screen down with it.
    final rawId = map['id'];
    final id = rawId is String && rawId.trim().isNotEmpty
        ? rawId.trim()
        : 'unknown-sale';
    DateTime date;
    // Deliberately no `Timestamp` branch: this model stays free of any
    // cloud_firestore import so it can be unit-tested without Firebase. The
    // app writes ISO-8601 strings; a raw Firestore timestamp here would be a
    // schema this model has never produced, and the epoch fallback keeps the
    // row visible rather than crashing the stream.
    final rawDate = map['date'];
    if (rawDate is String) {
      date =
          DateTime.tryParse(rawDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (rawDate is int) {
      date = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else {
      date = DateTime.fromMillisecondsSinceEpoch(0);
    }
    // `customer_id` was a hard cast, the same single-row-take-down-the-stream
    // risk. A walk-in sale legitimately has no customer, and an archived row
    // missing the field must not blank the shop's sales.
    final rawCustomerId = map['customer_id'];
    final customerId = rawCustomerId is String && rawCustomerId.isNotEmpty
        ? rawCustomerId
        : '';

    // `paid` was a hard cast too. Fall back to the bill the lines add up to,
    // which is what the record was worth, rather than throwing the stream away.
    final lineSubtotal = items.fold(0.0, (s, li) => s + li.lineTotal);
    final computedAmount = lineSubtotal +
        ((map['delivery_charge'] as num?)?.toDouble() ?? 0) +
        ((map['cutting_charge'] as num?)?.toDouble() ?? 0) -
        ((map['discount_amount'] as num?)?.toDouble() ??
            lineSubtotal *
                ((map['discount_percent'] as num?)?.toDouble() ?? 0) /
                100);

    return Sale(
      id: id,
      date: date,
      customerId: customerId,
      customerName: map['customer_name'] as String?,
      lineItems: items,
      paid: (map['paid'] as num?)?.toDouble() ?? computedAmount,
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
