import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../widgets/design_system/design_system.dart';
import '../utils/safe_error_handler.dart';
import 'notification_history_screen.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationSettings _settings = const NotificationSettings();
  final _phoneCtrl = TextEditingController();
  bool _loaded = false;

  /// True once we have asked for POST_NOTIFICATIONS and know the answer, so the
  /// guidance row does not flash in before the state is known.
  bool _permissionKnown = false;
  bool _permissionGranted = false;

  /// Set when loading the settings failed. Distinct from `_loaded`, which means
  /// "we have something to render" - including the error case.
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Wrapped, because a throw here left `_loaded` false forever and this
    // screen stuck on a bare spinner with no AppBar and no way out. Both calls
    // can throw: `NotificationSettings.load()` touches SharedPreferences, and
    // `LocalNotificationService.hasPermission()` is a platform-channel call
    // that fails if the plugin is not registered.
    setState(() => _error = null);
    try {
      final s = await NotificationSettings.load();
      if (!mounted) return;
      setState(() {
        _settings = s;
        _phoneCtrl.text = s.phoneNumber;
        _loaded = true;
      });
    } catch (e, st) {
      logSecureError(e, st, tag: 'notification_settings_load');
      if (!mounted) return;
      // Mark loaded so the screen renders its real chrome - and therefore its
      // back button - instead of an escapeless spinner.
      setState(() {
        _loaded = true;
        _error = 'We could not load your notification settings.';
      });
      return;
    }
    try {
      await _refreshPermission();
    } catch (e, st) {
      // The settings themselves loaded, so this is a degraded screen rather
      // than a dead one: keep it usable and just omit the permission guidance.
      logSecureError(e, st, tag: 'notification_permission');
    }
  }

  /// Reads the current POST_NOTIFICATIONS grant. On API < 33 the permission
  /// does not exist, so the plugin reports notifications as allowed and the
  /// guidance row stays hidden.
  Future<void> _refreshPermission() async {
    final granted = await LocalNotificationService.hasPermission();
    if (!mounted) return;
    setState(() {
      _permissionKnown = true;
      _permissionGranted = granted;
    });
  }

  /// Asks for the runtime permission at the moment the user opts into an alert,
  /// so the system prompt is answered against a visible explanation rather than
  /// appearing on a cold start with no context.
  Future<void> _requestPermission() async {
    final granted = await LocalNotificationService.requestPermission();
    if (!mounted) return;
    setState(() {
      _permissionKnown = true;
      _permissionGranted = granted;
    });
    if (!granted) {
      showAppToast(
        context,
        'Alerts are switched on, but Android permission is off. '
        'Enable notifications for Foam Shop in system settings to receive them.',
      );
    }
  }

  /// Toggling an alert on is the contextual moment to request permission.
  void _onAlertToggled(bool enabled) {
    setState(() => _settings = _settings.copyWith(lowStockEnabled: enabled));
    if (enabled) _requestPermission();
  }

  /// Same rule as [_onAlertToggled], for the overdue-baqaya switch.
  void _onOverdueToggled(bool enabled) {
    setState(
        () => _settings = _settings.copyWith(overdueBaqayaEnabled: enabled));
    if (enabled) _requestPermission();
  }

  Future<void> _save() async {
    final updated = _settings.copyWith(phoneNumber: _phoneCtrl.text.trim());
    await updated.save();
    if (!mounted) return;
    setState(() => _settings = updated);
    if (updated.lowStockEnabled || updated.overdueBaqayaEnabled) {
      // Covers the case where the user enabled an alert and dismissed the
      // system prompt; save still succeeds, but the state is surfaced.
      if (_permissionKnown && !_permissionGranted) {
        showAppToast(
          context,
          'Settings saved. Android notification permission is still off.',
        );
        return;
      }
    }
    showAppToast(context, 'Notification settings saved');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    if (!_loaded) {
      // Keep the real overlay chrome even while loading. A bare
      // `Scaffold(body: CircularProgressIndicator())` has no AppBar and no back
      // affordance, so a slow or failed load meant the user was stuck.
      return const FullScreenOverlay(
        title: 'Notifications',
        child: SizedBox.shrink(),
      );
    }

    return FullScreenOverlay(
      title: 'Notifications',
      child: _error != null
          ? ErrorState(
              title: _error!,
              message: 'Check your connection, then try again.',
              onRetry: _load,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppField(
                  label: 'Your phone number',
                  controller: _phoneCtrl,
                  hintText: '+92 3XX XXXXXXX',
                  keyboardType: TextInputType.phone,
                ),
                SectionLabel(title: 'Alert types'),
                // Shown only when we know notifications are blocked AND the user has
                // opted into at least one alert. Without both conditions this row
                // would be noise for a user who has deliberately turned alerts off.
                if (_permissionKnown &&
                    !_permissionGranted &&
                    (_settings.lowStockEnabled ||
                        _settings.overdueBaqayaEnabled))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FoamCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notifications_off_rounded,
                              size: 20, color: ac.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Alerts are blocked by Android',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: ac.ink)),
                                const SizedBox(height: 4),
                                Text(
                                  'Foam Shop needs notification permission to tell you about low stock and overdue balances.',
                                  style: TextStyle(
                                      fontSize: 12.5, color: ac.inkSoft),
                                ),
                                const SizedBox(height: 10),
                                AppButton(
                                  label: 'Allow notifications',
                                  onTap: _requestPermission,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                FoamCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: Column(
                    children: [
                      MenuRow(
                        icon: Icons.inventory_2_rounded,
                        title: 'Low stock alerts',
                        subtitle: 'When a product hits its reorder threshold',
                        trailing: AppSwitch(
                          value: _settings.lowStockEnabled,
                          onChanged: _onAlertToggled,
                        ),
                      ),
                      MenuRow(
                        icon: Icons.person_rounded,
                        title: 'Overdue baqaya reminders',
                        subtitle: 'Customer balances outstanding 30+ days',
                        trailing: AppSwitch(
                          value: _settings.overdueBaqayaEnabled,
                          onChanged: _onOverdueToggled,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(label: 'Save Settings', onTap: _save),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context,
                        slideUpRoute(const NotificationHistoryScreen())),
                    child: Text('View notification history',
                        style: TextStyle(fontSize: 12.5, color: ac.primary)),
                  ),
                ),
              ],
            ),
    );
  }
}
