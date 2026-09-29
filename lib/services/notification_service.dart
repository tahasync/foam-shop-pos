import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/payment.dart';
import '../utils/safe_error_handler.dart';

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

/// Stable notification channel IDs.
///
/// These are constants on purpose. A channel is created once by the system and
/// its importance, sound and vibration are then owned by the *user*; if the app
/// generated a new ID on every launch (or timestamped one) it would spawn a
/// fresh channel each time, and every one of those channels would appear in
/// Android's per-app notification settings for the user to clean up.
///
/// Renaming a constant silently orphans the old channel. To change a channel,
/// add a new constant and post to it; do not edit the value of an existing one.
class NotificationChannels {
  const NotificationChannels._();

  /// Low-stock and overdue-baqaya alerts raised by the app itself. Matches the
  /// `default_notification_channel_id` declared in AndroidManifest.xml so an
  /// FCM fallback message lands on this channel rather than an auto-created one.
  static const String general = 'foam_shop_general';
}

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// The dedicated status-bar icon.
  ///
  /// This must NOT be `@mipmap/ic_launcher`. The launcher icon is an adaptive
  /// icon whose background layer is an opaque brand square; Android draws a
  /// notification small icon as an alpha-only mask, so that square gets masked
  /// into a solid black/white block. `@drawable/ic_stat_foam_shop` is a
  /// standalone monochrome vector with a transparent background, which is what
  /// the status bar expects. It is also declared as the FCM default icon in the
  /// manifest so background and terminated-app messages use the same asset.
  static const String _smallIcon = '@drawable/ic_stat_foam_shop';

  /// Matches `@color/notification_color` in res/values/colors.xml.
  static const Color _accent = Color(0xFF3D5387);

  static Future<void> initialize() async {
    if (_initialized) return;

    // Create the channel explicitly and exactly once. flutter_local_notifications
    // skips creation if the channel already exists, so repeated app launches
    // leave the user's own importance/sound/vibration choices untouched.
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_stat_foam_shop');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);

    try {
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationChannels.general,
          'Shop Alerts',
          description: 'Low stock and overdue baqaya alerts',
          importance: Importance.high,
        ),
      );
    } catch (e) {
      logSecureError('Notification channel creation failed', StackTrace.current,
          tag: 'notifications');
    }

    // The runtime permission is deliberately NOT requested here. initialize()
    // runs during app start-up, before the user has seen anything that would
    // explain why alerts matter. It is requested from the notification settings
    // screen instead, where the prompt has context. See [requestPermission].
    _initialized = true;
  }

  /// Whether notifications are currently allowed to be shown.
  ///
  /// On Android 13+ this reflects the POST_NOTIFICATIONS grant. On older
  /// versions the permission does not exist and notifications are always
  /// allowed, so the plugin reports true and callers show no guidance.
  static Future<bool> hasPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;
    try {
      final granted = await androidPlugin.areNotificationsEnabled();
      return granted ?? false;
    } catch (e) {
      logSecureError('Notification permission read failed', StackTrace.current,
          tag: 'notifications');
      return false;
    }
  }

  /// Requests POST_NOTIFICATIONS (Android 13+). Call from a screen that already
  /// explains the benefit. Returns true if notifications may be shown.
  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;
    try {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      logSecureError(
          'Notification permission request failed', StackTrace.current,
          tag: 'notifications');
      return false;
    }
  }

  static Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.general,
      'Shop Alerts',
      channelDescription: 'Low stock and overdue baqaya alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      color: _accent,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      // A failure to post must never propagate into the caller's business logic -
      // checkAndNotify runs alongside sale entry and must not break it.
      logSecureError('Failed to post notification', StackTrace.current,
          tag: 'notifications');
    }
  }

  static Future<void> checkAndNotify({
    required List<Product> products,
    required List<Sale> sales,
    required List<Payment> payments,
  }) async {
    final settings = await NotificationSettings.load();
    if (!settings.lowStockEnabled && !settings.overdueBaqayaEnabled) {
      return;
    }

    final messages = <String>[];

    if (settings.lowStockEnabled) {
      final lowStock = products.where((p) => p.isLowStock).toList();
      if (lowStock.isNotEmpty) {
        // Only the first few names are ever shown, so only the first few are
        // worth reading. This previously logged one line per low-stock product
        // on every check, which for a shop with 40 low items meant 40 log lines
        // describing a notification the user never sees in detail.
        final names = lowStock.take(3).map((p) => p.name).join(', ');
        messages.add(
            'Low stock: ${lowStock.length} item${lowStock.length == 1 ? '' : 's'} '
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
        final cSales = sales
            .where((s) => s.customerId == cid && !s.isVoided && !s.isQuote);
        final cPayments = payments.where((p) => p.customerId == cid);
        final total = cSales.fold(0.0, (s, x) => s + x.amount);
        final paid = cSales.fold(0.0, (s, x) => s + x.paid);
        final recv = cPayments.fold(0.0, (s, x) => s + x.amountCollected);
        final bal = total - paid - recv;

        if (bal > 0) {
          final lastActivity = cSales.fold<DateTime?>(
              null,
              (prev, s) =>
                  prev == null || s.date.isAfter(prev) ? s.date : prev);
          if (lastActivity != null && lastActivity.isBefore(thirtyDaysAgo)) {
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
