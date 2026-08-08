class Payment {
  final String id;
  final DateTime date;
  final String customerId;
  final double amountCollected;

  Payment({
    required this.id,
    required this.date,
    required this.customerId,
    required this.amountCollected,
  }) : assert(amountCollected > 0, 'Payment amount must be positive');

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'customer_id': customerId,
        'amount_collected': amountCollected,
      };

  factory Payment.fromMap(Map<String, dynamic> map) {
    final date = map['date'];
    if (date is! String) throw const FormatException('Invalid payment: missing date');
    return Payment(
      id: map['id'] as String? ?? '',
      date: DateTime.parse(date),
      customerId: map['customer_id'] as String? ?? '',
      amountCollected: ((map['amount_collected'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
    );
  }
}
