class Purchase {
  final String id;
  final DateTime date;
  final String supplierId;
  final String productId;
  final double qtyOrArea;
  final double costAmount;
  final double paid;
  final double balance;

  Purchase({
    required this.id,
    required this.date,
    required this.supplierId,
    required this.productId,
    required this.qtyOrArea,
    required this.costAmount,
    required this.paid,
    required this.balance,
  }) : assert(qtyOrArea > 0, 'Purchase quantity must be positive'),
       assert(costAmount >= 0, 'Cost amount cannot be negative'),
       assert(paid >= 0, 'Paid amount cannot be negative');

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'supplier_id': supplierId,
        'product_id': productId,
        'qty_or_area': qtyOrArea,
        'cost_amount': costAmount,
        'paid': paid,
        'balance': balance,
      };

  factory Purchase.fromMap(Map<String, dynamic> map) {
    final date = map['date'];
    if (date is! String) throw const FormatException('Invalid purchase: missing date');
    return Purchase(
      id: map['id'] as String? ?? '',
      date: DateTime.parse(date),
      supplierId: map['supplier_id'] as String? ?? '',
      productId: map['product_id'] as String? ?? '',
      qtyOrArea: ((map['qty_or_area'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      costAmount: ((map['cost_amount'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      paid: ((map['paid'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      balance: ((map['balance'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
    );
  }
}
