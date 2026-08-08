class CostPriceHistory {
  final String id;
  final String productId;
  final double oldCostPrice;
  final double newCostPrice;
  final DateTime date;
  final String note;

  CostPriceHistory({
    required this.id,
    required this.productId,
    required this.oldCostPrice,
    required this.newCostPrice,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'old_cost_price': oldCostPrice,
    'new_cost_price': newCostPrice,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory CostPriceHistory.fromMap(Map<String, dynamic> map) {
    return CostPriceHistory(
      id: map['id'] as String? ?? '',
      productId: map['product_id'] as String? ?? '',
      oldCostPrice: ((map['old_cost_price'] as num?)?.toDouble() ?? 0),
      newCostPrice: ((map['new_cost_price'] as num?)?.toDouble() ?? 0),
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now(),
      note: map['note'] as String? ?? '',
    );
  }
}
