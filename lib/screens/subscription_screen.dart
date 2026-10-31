import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/constants.dart';
import '../widgets/design_system/design_system.dart';
import 'billing_screen.dart';

/// Subscription status, plan details, and a direct path to the shop's receipt
/// history. Plan support opens WhatsApp; the app does not process payments.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);
    final profile = ref.watch(shopProfileProvider).asData?.value;
    final subLabel = profile?.subscriptionLabel;
    final isTrial = subLabel?.startsWith('Trial:') ?? false;
    final isFreeForever = profile?.founderExempt == true ||
        profile?.subscriptionStatus == 'free_forever';
    final statusLabel = isFreeForever
        ? 'Lifetime access'
        : subLabel == null
            ? 'Active'
            : trialChipLabel(subLabel);

    return FullScreenOverlay(
      title: 'Billing & Subscription',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubscriptionHero(
            statusLabel: statusLabel,
            heading: isFreeForever
                ? 'Foam Shop Founder'
                : isTrial
                    ? 'Free Trial'
                    : 'Digital Register',
            description: isFreeForever
                ? 'Your shop has complimentary lifetime access to the register.'
                : isTrial
                    ? 'Your trial includes the complete shop register.'
                    : 'Your shop register and business history are active.',
            isTrial: isTrial,
          ),
          SectionLabel(title: 'Plan details'),
          FoamCard(
            foam: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFreeForever
                                ? 'Founding account'
                                : 'Digital Register · Monthly',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: ac.ink,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            isFreeForever
                                ? 'No monthly charge'
                                : 'One plan for your complete shop workflow',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: ac.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isFreeForever) ...[
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs 1,500',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ac.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            'per month',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: ac.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Divider(color: ac.outline, height: 1),
                const SizedBox(height: AppSpacing.md),
                const _PlanFeature(
                  icon: Icons.point_of_sale_rounded,
                  label: 'Sales, stock and khata in one place',
                ),
                const SizedBox(height: AppSpacing.md),
                const _PlanFeature(
                  icon: Icons.insights_rounded,
                  label: 'Reports, receipts and business history',
                ),
                if (!isFreeForever) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    isTrial
                        ? 'Contact us when you are ready to continue after your trial.'
                        : 'For renewals, billing dates or plan changes, contact our team.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: ac.inkFaint,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Message plan support',
                    icon: Icons.chat_rounded,
                    onTap: _contactPlanSupport,
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Your founding account keeps access available at no charge.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: ac.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SectionLabel(title: 'Receipt history'),
          FoamCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs,
            ),
            child: MenuRow(
              icon: Icons.receipt_long_rounded,
              title: 'View all receipts',
              subtitle: 'Invoices, quotes and payment status',
              onTap: () => Navigator.push(
                context,
                slideUpRoute(const BillingScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactPlanSupport() async {
    final number =
        AppConstants.supportWhatsAppNumber.replaceAll(RegExp(r'[^\d]'), '');
    final message = Uri.encodeComponent(
      'I have a question about my Digital Register plan',
    );
    final uri = Uri.parse('https://wa.me/$number?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SubscriptionHero extends StatelessWidget {
  const _SubscriptionHero({
    required this.statusLabel,
    required this.heading,
    required this.description,
    required this.isTrial,
  });

  final String statusLabel;
  final String heading;
  final String description;
  final bool isTrial;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return FoamCard(
      foam: true,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ac.brandFill, ac.brandFillDeep],
          ),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: AppHit.min),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isTrial ? Icons.schedule_rounded : Icons.verified_rounded,
                    size: AppIconSize.sm,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              heading,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 21,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFFDCE1F2),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanFeature extends StatelessWidget {
  const _PlanFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Row(
      children: [
        Icon(icon, size: AppIconSize.sm, color: ac.saleFg),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: ac.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}
