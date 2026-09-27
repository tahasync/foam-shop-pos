import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/design_system/design_system.dart';

class SubscriptionExpiredScreen extends StatelessWidget {
  final String shopName;
  const SubscriptionExpiredScreen({super.key, this.shopName = ''});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassContainer(
                    radius: 22,
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [ac.dangerSolid, ac.dangerSolid.withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: const Icon(Icons.lock_outline_rounded, size: 28, color: Colors.white),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Subscription Expired',
                  style: AppTheme.display(context, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your 14-day trial has ended. Your data is safe and nothing has been deleted '
                  '${shopName.isNotEmpty ? '\u2014 $shopName ' : ''}\u2014 renew to continue using the Digital Register.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: ac.inkSoft, height: 1.6),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 260,
                  child: AppButton(
                    variant: AppButtonVariant.success,
                    label: 'Message on WhatsApp',
                    leading: const Icon(Icons.chat_rounded, size: 18, color: Colors.white),
                    onTap: _openWhatsApp,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: ac.inkFaint),
                    const SizedBox(width: 6),
                    Text(
                      'Data preserved \u00b7 resumes instantly after renewal',
                      style: TextStyle(fontSize: 11, color: ac.inkFaint),
                    ),
                  ],
                ),
              ],
              ),
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
