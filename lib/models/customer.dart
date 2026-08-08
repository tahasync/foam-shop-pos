class Customer {
  final String id;
  final String name;
  final String phone;
  final double baqaya;
  final bool isArchived;

  static const int _maxNameLength = 200;
  static const int _maxPhoneLength = 20;

  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.baqaya = 0,
    this.isArchived = false,
  }) : assert(name.trim().isNotEmpty, 'Customer name is required'),
       assert(name.length <= _maxNameLength, 'Customer name exceeds $_maxNameLength characters'),
       assert(phone.length <= _maxPhoneLength, 'Phone exceeds $_maxPhoneLength characters'),
       assert(!baqaya.isNaN && !baqaya.isInfinite, 'Invalid baqaya value');

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'baqaya': baqaya,
        'is_archived': isArchived,
      };

  factory Customer.fromMap(Map<String, dynamic> map) {
    final name = map['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid or missing customer name');
    }
    return Customer(
      id: (map['id'] as String?) ?? '',
      name: name.trim(),
      phone: (map['phone'] as String?)?.trim() ?? '',
      baqaya: ((map['baqaya'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      isArchived: map['is_archived'] as bool? ?? false,
    );
  }

  Customer copyWith({String? id, String? name, String? phone, double? baqaya, bool? isArchived}) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        baqaya: baqaya ?? this.baqaya,
        isArchived: isArchived ?? this.isArchived,
      );
}
