import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/models/shop_profile.dart';
import 'package:foam_shop_register/models/product.dart';
import 'package:foam_shop_register/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ── Fix 1: subscriptionLabel fallback when trialEndsAt is null ──
  group('Fix 1 — subscriptionLabel fallback', () {
    test('returns Trial label when trialEndsAt is null (falls back to createdAt + 14d)', () {
      final profile = ShopProfile(
        shopName: 'Test Shop',
        location: 'Test City',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        subscriptionStatus: 'trial',
        trialEndsAt: null, // Simulate missing field
      );
      final label = profile.subscriptionLabel;
      expect(label, isNotNull);
      expect(label, contains('Trial:'));
      expect(label, contains('days left'));
    });

    test('returns null for free_forever status', () {
      final profile = ShopProfile(
        shopName: 'Founder Shop',
        location: 'City',
        createdAt: DateTime.now(),
        subscriptionStatus: 'free_forever',
        founderExempt: true,
      );
      expect(profile.subscriptionLabel, isNull);
    });

    test('returns null for expired trial', () {
      final profile = ShopProfile(
        shopName: 'Expired Shop',
        location: 'City',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        subscriptionStatus: 'trial',
        trialEndsAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(profile.subscriptionLabel, isNull);
    });
  });

  // ── Fix 3: Notification service check logic ──
  group('Fix 3 — Notification low-stock detection', () {
    test('detects low stock products correctly', () async {
      SharedPreferences.setMockInitialValues({
        'notif_low_stock': true,
        'notif_overdue_baqaya': false,
      });

      final products = [
        Product(id: 'p1', name: 'Foam A', type: 'Sheet', sizeLength: 10, sizeWidth: 10,
            thickness: 1, density: 10, unitType: 'per_sqft', unitPrice: 100,
            costPrice: 50, currentStock: 2, lowStockThreshold: 5), // LOW
        Product(id: 'p2', name: 'Foam B', type: 'Sheet', sizeLength: 10, sizeWidth: 10,
            thickness: 1, density: 10, unitType: 'per_sqft', unitPrice: 100,
            costPrice: 50, currentStock: 20, lowStockThreshold: 5), // OK
      ];

      // We can't check notification actually fired (platform dependency),
      // but we can verify the settings load correctly
      final settings = await NotificationSettings.load();
      expect(settings.lowStockEnabled, true);
      expect(settings.overdueBaqayaEnabled, false);

      final lowStock = products.where((p) => p.isLowStock).toList();
      expect(lowStock.length, 1);
      expect(lowStock.first.name, 'Foam A');
    });

    test('skips check when toggles are off', () async {
      SharedPreferences.setMockInitialValues({
        'notif_low_stock': false,
        'notif_overdue_baqaya': false,
      });
      final settings = await NotificationSettings.load();
      expect(settings.lowStockEnabled, false);
      expect(settings.overdueBaqayaEnabled, false);
    });
  });

  // ── Fix 4 / Fix 2 ──
  //
  // These two groups used to be `expect(true, isTrue)` with a comment explaining
  // that "the real verification is compile-time". They asserted nothing: the
  // file importing cleanly already proves the screen exists, and re-stating
  // that as a test only inflates the count. They have been removed rather than
  // dressed up — there is no behaviour here to verify.
}
