import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification settings saved'),
        backgroundColor: AppTheme.teal,
      ),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);

    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingCard(
            icon: Icons.inventory_2_rounded,
            iconBg: ac.purchaseTint,
            iconFg: ac.purchaseFg,
            title: 'Low Stock Alerts',
            description: 'Notify when any product hits its threshold',
            value: _settings.lowStockEnabled,
            onChanged: (v) => setState(() => _settings = _settings.copyWith(lowStockEnabled: v)),
          ),
          const SizedBox(height: 12),
          _SettingCard(
            icon: Icons.person_rounded,
            iconBg: ac.expenseTint,
            iconFg: ac.expenseFg,
            title: 'Overdue Baqaya Reminders',
            description: 'Notify for balances outstanding 30+ days',
            value: _settings.overdueBaqayaEnabled,
            onChanged: (v) => setState(() => _settings = _settings.copyWith(overdueBaqayaEnabled: v)),
          ),
          const SizedBox(height: 20),
          Text('Your phone number',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneCtrl,
            decoration: InputDecoration(
              hintText: '+92 3XX XXXXXXX',
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: ac.inkFaint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'On-device notifications only — checked when you open the app. No server, no cost.',
                    style: TextStyle(fontSize: 11, color: ac.inkFaint, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 17, color: iconFg),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: cs.onSurface)),
            const SizedBox(height: 2),
            Text(description, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        ),
        Switch(
          value: value,
          activeTrackColor: AppTheme.teal,
          onChanged: onChanged,
        ),
      ]),
    );
  }
}
