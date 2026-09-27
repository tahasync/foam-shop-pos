import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/design_system/design_system.dart';

enum SupportChannel { whatsapp, email }

class SupportFeedbackScreen extends ConsumerStatefulWidget {
  const SupportFeedbackScreen({super.key});
  @override
  ConsumerState<SupportFeedbackScreen> createState() =>
      _SupportFeedbackScreenState();
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
    final fullMsg = '$msg\n\n\u2014 Sent from $shopName (v$appVersion)';

    if (_channel == SupportChannel.whatsapp) {
      final number =
          AppConstants.supportWhatsAppNumber.replaceAll(RegExp(r'[^\d]'), '');
      final uri = Uri.parse(
          'https://wa.me/$number?text=${Uri.encodeComponent(fullMsg)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } else {
      final uri = Uri(
        scheme: 'mailto',
        path: AppConstants.supportEmail,
        queryParameters: {
          'subject': 'Feedback: $shopName',
          'body': fullMsg,
        },
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _channel == SupportChannel.email
              ? 'No email app found. Contact us at ${AppConstants.supportEmail}'
              : 'No WhatsApp app found. Contact us at ${AppConstants.supportWhatsAppNumber}',
        ),
        backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return FullScreenOverlay(
      title: 'Support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title: 'Send via'),
          Row(children: [
            Expanded(
              child: _ChannelCard(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                selected: _channel == SupportChannel.whatsapp,
                onTap: () => setState(() => _channel = SupportChannel.whatsapp),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChannelCard(
                icon: Icons.email_rounded,
                label: 'Email',
                selected: _channel == SupportChannel.email,
                onTap: () => setState(() => _channel = SupportChannel.email),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          AppField(
            label: 'Your message',
            controller: _msgCtrl,
            hintText: 'Describe the issue or feedback\u2026',
            maxLines: 5,
            onChanged: (_) => setState(() {}),
          ),
          AppButton(
            label: _channel == SupportChannel.whatsapp
                ? 'Send via WhatsApp'
                : 'Send via Email',
            onTap: _msgCtrl.text.trim().isEmpty ? null : _send,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Shop name and app version included automatically',
              style: TextStyle(fontSize: 10.5, color: ac.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? ac.saleTint : ac.glassFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? ac.saleFg : ac.glassBorder,
              width: selected ? 1.5 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 24, color: selected ? ac.saleFg : ac.inkSoft),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? ac.saleFg : ac.inkSoft,
              )),
        ]),
      ),
    );
  }
}
