class ShopProfile {
  final String shopName;
  final String location;
  final String phone;
  final String currency;
  final DateTime createdAt;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionExpiresAt;
  final bool founderExempt;

  ShopProfile({
    required this.shopName,
    required this.location,
    this.phone = '',
    this.currency = 'PKR',
    required this.createdAt,
    this.subscriptionStatus = 'trial',
    this.trialEndsAt,
    this.subscriptionExpiresAt,
    this.founderExempt = false,
  });

  Map<String, dynamic> toMap() => {
    'shop_name': shopName,
    'location': location,
    'phone': phone,
    'currency': currency,
    'created_at': createdAt.toIso8601String(),
    'subscription_status': subscriptionStatus,
    'trial_ends_at': trialEndsAt?.toIso8601String(),
    'subscription_expires_at': subscriptionExpiresAt?.toIso8601String(),
    'founder_exempt': founderExempt,
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
      subscriptionStatus: map['subscription_status'] as String? ?? 'trial',
      trialEndsAt: map['trial_ends_at'] != null
          ? DateTime.parse(map['trial_ends_at'] as String)
          : null,
      subscriptionExpiresAt: map['subscription_expires_at'] != null
          ? DateTime.parse(map['subscription_expires_at'] as String)
          : null,
      founderExempt: map['founder_exempt'] as bool? ?? false,
    );
  }

  ShopProfile copyWith({
    String? shopName,
    String? location,
    String? phone,
    String? currency,
    DateTime? createdAt,
    String? subscriptionStatus,
    DateTime? trialEndsAt,
    DateTime? subscriptionExpiresAt,
    bool? founderExempt,
  }) =>
      ShopProfile(
        shopName: shopName ?? this.shopName,
        location: location ?? this.location,
        phone: phone ?? this.phone,
        currency: currency ?? this.currency,
        createdAt: createdAt ?? this.createdAt,
        subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
        trialEndsAt: trialEndsAt ?? this.trialEndsAt,
        subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
        founderExempt: founderExempt ?? this.founderExempt,
      );

  bool get isSubscriptionActive {
    if (founderExempt || subscriptionStatus == 'free_forever') return true;
    if (subscriptionStatus == 'active') {
      if (subscriptionExpiresAt == null) return true;
      return DateTime.now().isBefore(subscriptionExpiresAt!);
    }
    if (subscriptionStatus == 'trial') {
      if (trialEndsAt == null) return true;
      return DateTime.now().isBefore(trialEndsAt!);
    }
    return false;
  }

  String? get subscriptionLabel {
    if (founderExempt || subscriptionStatus == 'free_forever') return null;
    if (subscriptionStatus == 'trial' && trialEndsAt != null) {
      final days = trialEndsAt!.difference(DateTime.now()).inDays;
      if (days < 0) return null;
      return 'Trial: $days day${days == 1 ? '' : 's'} left';
    }
    if (subscriptionStatus == 'active' && subscriptionExpiresAt != null) {
      final days = subscriptionExpiresAt!.difference(DateTime.now()).inDays;
      if (days < 0 || days > 5) return null;
      return '$days day${days == 1 ? '' : 's'} left';
    }
    return null;
  }
}
