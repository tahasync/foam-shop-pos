import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/constants.dart';
import '../widgets/design_system/design_system.dart';
import 'billing_screen.dart';

/// Billing & Subscription (mockup `overlay-subscription`): plan/trial status
/// with live days-remaining, an upgrade call to action, and a link into the
/// full receipt/invoice history (which remains a sub-destination, not the
/// direct target of this screen).
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);
    final profile = ref.watch(shopProfileProvider).asData?.value;
    final subLabel = profile?.subscriptionLabel;
    final isTrial = subLabel != null;

    return FullScreenOverlay(
      title: 'Billing & Subscription',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ac.brandFill, ac.brandFillDeep],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                // Neutral, not `brandFill` — see the note in
                // `account_settings_screen.dart`. A 45%-alpha brand wash under a
                // 24px blur read as a light leak around the card on the dark
                // page instead of as depth.
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark ? 0.36 : 0.18,
                  ),
                  blurRadius: 18,
                  spreadRadius: -6,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            // See the note in `account_settings_screen.dart`: `Stack.clipBehavior`
            // defaults to `Clip.hardEdge`, which cut these negatively-offset orbs
            // off along the Stack's rectangular bounds and left a hard-edged pale
            // rectangle on the card. Overflow, then clip to the card's radius.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  top: -70,
                  right: -50,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -55,
                  right: 40,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.schedule_rounded, size: 10, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          isTrial ? trialChipLabel(subLabel) : 'Active',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isTrial ? 'Free Trial' : 'Digital Register',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTrial
                          ? 'Full access to every feature until your trial ends'
                          : 'Your shop is fully active on the Digital Register plan.',
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                    ),
                  ],
                ),
              ]),
            ),
          ),
          SectionLabel(title: 'Plan'),
          FoamCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Digital Register \u2014 Monthly',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ac.ink)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Rs 1,500',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ac.ink,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                        Text('/mo',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ac.inkFaint)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Renews automatically once your trial ends. Cancel anytime.',
                  style: TextStyle(fontSize: 11.5, color: ac.inkFaint),
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Upgrade now',
                  onTap: _upgradeNow,
                ),
              ],
            ),
          ),
          SectionLabel(title: 'History'),
          FoamCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: MenuRow(
              icon: Icons.receipt_long_rounded,
              title: 'View all receipts',
              subtitle: 'Sale invoices, paid/due/void',
              onTap: () => Navigator.push(context, slideUpRoute(const BillingScreen())),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _upgradeNow() async {
    final number = AppConstants.supportWhatsAppNumber.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent('I want to upgrade my subscription')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
