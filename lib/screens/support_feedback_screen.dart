import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

enum SupportChannel { whatsapp, email }

class SupportFeedbackScreen extends ConsumerStatefulWidget {
  const SupportFeedbackScreen({super.key});
  @override
  ConsumerState<SupportFeedbackScreen> createState() => _SupportFeedbackScreenState();
}

class _SupportFeedbackScreenState extends ConsumerState<SupportFeedbackScreen> {
  final _msgCtrl = TextEditingController();
  SupportChannel _channel = SupportChannel.whatsapp;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) return;

    final shopProfile = ref.read(shopProfileProvider).asData?.value;
    final shopName = shopProfile?.shopName ?? 'Digital Register';
    final pkg = await PackageInfo.fromPlatform();
    final appVersion = pkg.version;
    final fullMsg = '$msg\n\n— Sent from $shopName (v$appVersion)';

    if (_channel == SupportChannel.whatsapp) {
      final number = AppConstants.supportWhatsAppNumber.replaceAll(RegExp(r'[^\d]'), '');
      final uri = Uri.parse(
          'https://wa.me/$number?text=${Uri.encodeComponent(fullMsg)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final subject = Uri.encodeComponent('Feedback: $shopName');
    final body = Uri.encodeComponent(fullMsg);
    final uri = Uri.parse(
        'mailto:${AppConstants.supportEmail}?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Send via',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _ChannelChip(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                selected: _channel == SupportChannel.whatsapp,
                onTap: () => setState(() => _channel = SupportChannel.whatsapp),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChannelChip(
                icon: Icons.email_rounded,
                label: 'Email',
                selected: _channel == SupportChannel.email,
                onTap: () => setState(() => _channel = SupportChannel.email),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Text('Your message',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _msgCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Describe the issue or feedback\u2026',
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.all(14),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _msgCtrl.text.trim().isEmpty ? null : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(_channel == SupportChannel.whatsapp ? 'Send via WhatsApp' : 'Send via Email',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Shop name and app version included automatically',
                style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
          ),
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChannelChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? ac.saleTint : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.teal : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon, size: 24, color: selected ? ac.saleFg : cs.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: selected ? ac.saleFg : cs.onSurfaceVariant,
              )),
        ]),
      ),
    );
  }
}
