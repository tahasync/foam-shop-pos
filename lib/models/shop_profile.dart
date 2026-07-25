class ShopProfile {
  final String shopName;
  final String location;
  final String phone;
  final String currency;
  final DateTime createdAt;

  ShopProfile({
    required this.shopName,
    required this.location,
    this.phone = '',
    this.currency = 'PKR',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'shop_name': shopName,
    'location': location,
    'phone': phone,
    'currency': currency,
    'created_at': createdAt.toIso8601String(),
  };

  factory ShopProfile.fromMap(Map<String, dynamic> map) {
    return ShopProfile(
      shopName: map['shop_name'] as String? ?? '',
      location: map['location'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      currency: map['currency'] as String? ?? 'PKR',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  ShopProfile copyWith({
    String? shopName,
    String? location,
    String? phone,
    String? currency,
    DateTime? createdAt,
  }) =>
      ShopProfile(
        shopName: shopName ?? this.shopName,
        location: location ?? this.location,
        phone: phone ?? this.phone,
        currency: currency ?? this.currency,
        createdAt: createdAt ?? this.createdAt,
      );
}
