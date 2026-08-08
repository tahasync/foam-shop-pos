import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../widgets/design_system/design_system.dart';
import 'notification_history_screen.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  NotificationSettings _settings = const NotificationSettings();
  final _phoneCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await NotificationSettings.load();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _phoneCtrl.text = s.phoneNumber;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final updated = _settings.copyWith(phoneNumber: _phoneCtrl.text.trim());
    await updated.save();
    setState(() => _settings = updated);
    if (!mounted) return;
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FullScreenOverlay(
      title: 'Notifications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppField(
            label: 'Your phone number',
            controller: _phoneCtrl,
            hintText: '+92 3XX XXXXXXX',
            keyboardType: TextInputType.phone,
          ),
          SectionLabel(title: 'Alert types'),
          FoamCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                MenuRow(
                  icon: Icons.inventory_2_rounded,
                  title: 'Low stock alerts',
                  subtitle: 'When a product hits its reorder threshold',
                  trailing: AppSwitch(
                    value: _settings.lowStockEnabled,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(lowStockEnabled: v)),
                  ),
                ),
                MenuRow(
                  icon: Icons.person_rounded,
                  title: 'Overdue baqaya reminders',
                  subtitle: 'Customer balances outstanding 30+ days',
                  trailing: AppSwitch(
                    value: _settings.overdueBaqayaEnabled,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(overdueBaqayaEnabled: v)),
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
              onPressed: () => Navigator.push(context, slideUpRoute(const NotificationHistoryScreen())),
              child: Text('View notification history', style: TextStyle(fontSize: 12.5, color: ac.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
