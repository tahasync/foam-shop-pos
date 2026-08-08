class Expense {
  final String id;
  final DateTime date;
  final String category;
  final String description;
  final double amount;

  Expense({
    required this.id,
    required this.date,
    required this.category,
    this.description = '',
    required this.amount,
  }) : assert(category.trim().isNotEmpty, 'Expense category is required'),
       assert(amount > 0, 'Expense amount must be positive'),
       assert(description.length <= 500, 'Description too long');

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'category': category,
        'description': description,
        'amount': amount,
      };

  factory Expense.fromMap(Map<String, dynamic> map) {
    final category = map['category'];
    if (category is! String || category.trim().isEmpty) {
      throw const FormatException('Invalid expense: missing category');
    }
    final date = map['date'];
    if (date is! String) throw const FormatException('Invalid expense: missing date');
    return Expense(
      id: map['id'] as String? ?? '',
      date: DateTime.parse(date),
      category: category.trim(),
      description: (map['description'] as String?)?.trim() ?? '',
      amount: ((map['amount'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
    );
  }
}
