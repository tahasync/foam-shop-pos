import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

class SubscriptionExpiredScreen extends StatelessWidget {
  final String shopName;
  const SubscriptionExpiredScreen({super.key, this.shopName = ''});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: ac.expenseTint,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(Icons.lock_outline_rounded, size: 32, color: ac.expenseFg),
                ),
                const SizedBox(height: 20),
                Text('Subscription Expired',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  'Your 14-day trial has ended. Your data is safe and nothing has been deleted '
                  '${shopName.isNotEmpty ? '— $shopName ' : ''}— renew to continue using the Digital Register.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant, height: 1.6),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(children: [
                    Text('Renew via WhatsApp',
                        style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700, letterSpacing: 0.05)),
                    const SizedBox(height: 6),
                    Text(AppConstants.supportWhatsAppNumber,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                            color: ac.saleFg)),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openWhatsApp,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('Message on WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: ac.inkFaint),
                    const SizedBox(width: 6),
                    Text('Data preserved · resumes instantly after renewal',
                        style: TextStyle(fontSize: 11, color: ac.inkFaint)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openWhatsApp() async {
    final number = AppConstants.supportWhatsAppNumber.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent('I want to renew my subscription')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
