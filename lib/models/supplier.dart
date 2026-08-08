class Supplier {
  final String id;
  final String name;
  final String phone;
  final bool isArchived;

  static const int _maxNameLength = 200;

  Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.isArchived = false,
  }) : assert(name.trim().isNotEmpty, 'Supplier name is required'),
       assert(name.length <= _maxNameLength, 'Supplier name exceeds $_maxNameLength characters');

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'is_archived': isArchived,
      };

  factory Supplier.fromMap(Map<String, dynamic> map) {
    final name = map['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid or missing supplier name');
    }
    return Supplier(
      id: map['id'] as String? ?? '',
      name: name.trim(),
      phone: (map['phone'] as String?)?.trim() ?? '',
      isArchived: map['is_archived'] as bool? ?? false,
    );
  }

  Supplier copyWith({String? id, String? name, String? phone, bool? isArchived}) =>
      Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        isArchived: isArchived ?? this.isArchived,
      );
}
