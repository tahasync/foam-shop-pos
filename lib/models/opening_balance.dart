class OpeningBalance {
  final String id;
  final DateTime date;
  final double capitalAmount;

  OpeningBalance({
    required this.id,
    required this.date,
    required this.capitalAmount,
  }) : assert(capitalAmount >= 0, 'Capital amount cannot be negative');

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'capital_amount': capitalAmount,
      };

  factory OpeningBalance.fromMap(Map<String, dynamic> map) {
    final date = map['date'];
    if (date is! String) throw const FormatException('Invalid opening balance: missing date');
    return OpeningBalance(
      id: map['id'] as String? ?? '',
      date: DateTime.parse(date),
      capitalAmount: ((map['capital_amount'] as num?)?.toDouble() ?? 0).clamp(0, 1e12),
    );
  }
}
