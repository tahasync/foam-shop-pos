class SupplierPayment {
  final String id;
  final DateTime date;
  final String supplierId;
  final double amountPaid;

  SupplierPayment({
    required this.id,
    required this.date,
    required this.supplierId,
    required this.amountPaid,
  }) : assert(amountPaid > 0, 'Payment amount must be positive');

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'supplier_id': supplierId,
        'amount_paid': amountPaid,
      };

  factory SupplierPayment.fromMap(Map<String, dynamic> map) {
    final date = map['date'];
    if (date is! String) throw const FormatException('Invalid supplier payment: missing date');
    return SupplierPayment(
      id: map['id'] as String? ?? '',
      date: DateTime.parse(date),
      supplierId: map['supplier_id'] as String? ?? '',
      amountPaid: ((map['amount_paid'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
    );
  }
}
