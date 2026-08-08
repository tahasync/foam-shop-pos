class Product {
  static const int _maxNameLength = 200;
  static const int _maxTypeLength = 100;

  final String id;
  final String name;
  final String type;
  final double sizeLength;
  final double sizeWidth;
  final double thickness;
  final double density;
  final String unitType;
  final double unitPrice;
  final double costPrice;
  final double currentStock;
  final double lowStockThreshold;
  final bool isArchived;

  Product({
    required this.id,
    required this.name,
    required this.type,
    required this.sizeLength,
    required this.sizeWidth,
    required this.thickness,
    required this.density,
    required this.unitType,
    required this.unitPrice,
    this.costPrice = 0,
    required this.currentStock,
    required this.lowStockThreshold,
    this.isArchived = false,
  }) : assert(name.trim().isNotEmpty, 'Product name is required'),
       assert(name.length <= _maxNameLength, 'Product name exceeds $_maxNameLength characters'),
       assert(type.length <= _maxTypeLength, 'Product type exceeds $_maxTypeLength characters'),
       assert(!sizeLength.isNaN && !sizeLength.isInfinite, 'Invalid size length'),
       assert(!sizeWidth.isNaN && !sizeWidth.isInfinite, 'Invalid size width'),
       assert(!thickness.isNaN && !thickness.isInfinite, 'Invalid thickness'),
       assert(!density.isNaN && !density.isInfinite, 'Invalid density'),
       assert(!currentStock.isNaN && !currentStock.isInfinite, 'Invalid stock'),
       assert(!costPrice.isNaN && !costPrice.isInfinite, 'Invalid cost price');

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'size_length': sizeLength,
        'size_width': sizeWidth,
        'thickness': thickness,
        'density': density,
        'unit_type': unitType,
        'unit_price': unitPrice,
        'cost_price': costPrice,
        'current_stock': currentStock,
        'low_stock_threshold': lowStockThreshold,
        'is_archived': isArchived,
      };

  factory Product.fromMap(Map<String, dynamic> map) {
    final name = map['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid or missing product name');
    }
    return Product(
      id: map['id'] as String? ?? '',
      name: name.trim(),
      type: (map['type'] as String?)?.trim() ?? '',
      sizeLength: ((map['size_length'] as num?)?.toDouble() ?? 0).clamp(0, 9999),
      sizeWidth: ((map['size_width'] as num?)?.toDouble() ?? 0).clamp(0, 9999),
      thickness: ((map['thickness'] as num?)?.toDouble() ?? 0).clamp(0, 9999),
      density: ((map['density'] as num?)?.toDouble() ?? 0).clamp(0, 9999),
      unitType: (map['unit_type'] as String?) ?? 'per_sqft',
      unitPrice: ((map['unit_price'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      costPrice: ((map['cost_price'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      currentStock: ((map['current_stock'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      lowStockThreshold: ((map['low_stock_threshold'] as num?)?.toDouble() ?? 0).clamp(0, 1e9),
      isArchived: map['is_archived'] as bool? ?? false,
    );
  }

  Product copyWith({
    String? id, String? name, String? type,
    double? sizeLength, double? sizeWidth, double? thickness, double? density,
    String? unitType, double? unitPrice, double? costPrice,
    double? currentStock, double? lowStockThreshold, bool? isArchived,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        sizeLength: sizeLength ?? this.sizeLength,
        sizeWidth: sizeWidth ?? this.sizeWidth,
        thickness: thickness ?? this.thickness,
        density: density ?? this.density,
        unitType: unitType ?? this.unitType,
        unitPrice: unitPrice ?? this.unitPrice,
        costPrice: costPrice ?? this.costPrice,
        currentStock: currentStock ?? this.currentStock,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        isArchived: isArchived ?? this.isArchived,
      );

  double get effectivePrice {
    if (unitPrice > 0) return unitPrice;
    if (costPrice > 0) return costPrice;
    return 0.0;
  }

  String get unitLabel => unitType == 'per_sqft' ? 'sq.ft' : 'pcs';

  bool get isLowStock => currentStock <= lowStockThreshold;

  String get stockLabel => '${currentStock.toInt()} pcs';
}
