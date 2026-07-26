import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/payment.dart';

class NotificationSettings {
  final bool lowStockEnabled;
  final bool overdueBaqayaEnabled;
  final String phoneNumber;

  const NotificationSettings({
    this.lowStockEnabled = false,
    this.overdueBaqayaEnabled = false,
    this.phoneNumber = '',
  });

  static const _keyLowStock = 'notif_low_stock';
  static const _keyOverdueBaqaya = 'notif_overdue_baqaya';
  static const _keyPhone = 'notif_phone';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLowStock, lowStockEnabled);
    await prefs.setBool(_keyOverdueBaqaya, overdueBaqayaEnabled);
    await prefs.setString(_keyPhone, phoneNumber);
  }

  static Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      lowStockEnabled: prefs.getBool(_keyLowStock) ?? false,
      overdueBaqayaEnabled: prefs.getBool(_keyOverdueBaqaya) ?? false,
      phoneNumber: prefs.getString(_keyPhone) ?? '',
    );
  }

  NotificationSettings copyWith({
    bool? lowStockEnabled,
    bool? overdueBaqayaEnabled,
    String? phoneNumber,
  }) =>
      NotificationSettings(
        lowStockEnabled: lowStockEnabled ?? this.lowStockEnabled,
        overdueBaqayaEnabled: overdueBaqayaEnabled ?? this.overdueBaqayaEnabled,
        phoneNumber: phoneNumber ?? this.phoneNumber,
      );
}

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {}
    _initialized = true;
  }

  static Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'shop_alerts',
      'Shop Alerts',
      channelDescription: 'Low stock and overdue baqaya alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(id, title, body, details);
  }

  static Future<void> checkAndNotify({
    required List<Product> products,
    required List<Sale> sales,
    required List<Payment> payments,
  }) async {
    final settings = await NotificationSettings.load();
    developer.log('[Notif] checkAndNotify: lowStock=${settings.lowStockEnabled}, '
        'overdueBaqaya=${settings.overdueBaqayaEnabled}, '
        'products=${products.length}', name: 'notif');
    if (!settings.lowStockEnabled && !settings.overdueBaqayaEnabled) {
      developer.log('[Notif] Both toggles off, skipping', name: 'notif');
      return;
    }

    final messages = <String>[];

    if (settings.lowStockEnabled) {
      final lowStock = products.where((p) => p.isLowStock).toList();
      developer.log('[Notif] Low stock check: ${lowStock.length} low out of ${products.length} products',
          name: 'notif');
      for (final p in lowStock) {
        developer.log('[Notif]   Low: ${p.name} (stock=${p.currentStock}, threshold=${p.lowStockThreshold})',
            name: 'notif');
      }
      if (lowStock.isNotEmpty) {
        final names = lowStock.take(3).map((p) => p.name).join(', ');
        messages.add('Low stock: ${lowStock.length} item${lowStock.length == 1 ? '' : 's'} '
            '(${lowStock.length > 3 ? '$names +${lowStock.length - 3} more' : names})');
      }
    }

    if (settings.overdueBaqayaEnabled) {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final overdueIds = <String>{};
      final customerBalances = <String, double>{};

      for (final s in sales) {
        if (s.isVoided || s.isQuote || s.customerId.isEmpty) continue;
        overdueIds.add(s.customerId);
      }
      for (final p in payments) {
        if (p.customerId.isNotEmpty) overdueIds.add(p.customerId);
      }

      for (final cid in overdueIds) {
        final cSales = sales.where(
            (s) => s.customerId == cid && !s.isVoided && !s.isQuote);
        final cPayments = payments.where((p) => p.customerId == cid);
        final total = cSales.fold(0.0, (s, x) => s + x.amount);
        final paid = cSales.fold(0.0, (s, x) => s + x.paid);
        final recv = cPayments.fold(0.0, (s, x) => s + x.amountCollected);
        final bal = total - paid - recv;

        if (bal > 0) {
          final lastActivity = cSales.fold<DateTime?>(
              null, (prev, s) => prev == null || s.date.isAfter(prev) ? s.date : prev);
          if (lastActivity != null &&
              lastActivity.isBefore(thirtyDaysAgo)) {
            customerBalances[cid] = bal;
          }
        }
      }

      if (customerBalances.isNotEmpty) {
        messages.add('Overdue Baqaya: ${customerBalances.length} '
            'customer${customerBalances.length == 1 ? '' : 's'} with outstanding 30+ days');
      }
    }

    if (messages.isNotEmpty) {
      await showNotification(
        title: 'Shop Alerts',
        body: messages.join('\n'),
      );
    }
  }
}
