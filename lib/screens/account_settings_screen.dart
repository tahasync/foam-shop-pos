import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/opening_balance.dart';
import '../models/shop_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/safe_error_handler.dart';
import '../utils/constants.dart';
import '../widgets/design_system/design_system.dart';
import 'delete_account_sheet.dart';
import 'notification_history_screen.dart';
import 'notification_settings_screen.dart';
import 'subscription_screen.dart';
import 'support_feedback_screen.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    final obAsync = ref.watch(openingBalanceStreamProvider);
    final themeMode = ref.watch(themeModeProvider);
    final shopAsync = ref.watch(shopProfileProvider);

    final openingBal = obAsync.asData?.value;
    final profile = shopAsync.asData?.value;
    final shopName = profile?.shopName ?? 'Digital Register';
    final subLabel = profile?.subscriptionLabel;
    final initials = (user?.displayName ?? shopName).isNotEmpty
        ? (user?.displayName ?? shopName)[0].toUpperCase()
        : '?';

    return FullScreenOverlay(
      title: 'Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.of(context).brandFill,
                  AppColors.of(context).brandFillDeep,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                // Neutral, not `brandFill`.
                //
                // A 40%-alpha wash of the brand colour under a 24px blur put a
                // wide blue halo around this card — the same "glowing slab"
                // effect the buttons had. On the near-black dark page it read
                // as a light leak rather than as depth. A short black shadow
                // grounds the card in both themes.
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
            child: Stack(
              children: [
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
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$shopName \u00b7 Owner',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                          if (subLabel != null) ...[
                            const SizedBox(height: 8),
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
                                  trialChipLabel(subLabel),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SectionLabel(title: 'Shop'),
          FoamCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                MenuRow(
                  icon: Icons.home_rounded,
                  title: 'Shop profile',
                  subtitle: 'Name, location, phone, currency',
                  onTap: () => _editShopProfile(context, ref, profile, openingBal),
                ),
                MenuRow(
                  icon: Icons.credit_card_rounded,
                  title: 'Billing & subscription',
                  subtitle: subLabel != null ? trialChipLabel(subLabel) : 'Subscription',
                  onTap: () => Navigator.push(context, slideUpRoute(const SubscriptionScreen())),
                ),
              ],
            ),
          ),
          SectionLabel(title: 'Preferences'),
          FoamCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                MenuRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notification settings',
                  subtitle: 'Phone number & alert types',
                  onTap: () => Navigator.push(context, slideUpRoute(const NotificationSettingsScreen())),
                ),
                MenuRow(
                  icon: Icons.schedule_rounded,
                  title: 'Notification history',
                  onTap: () => Navigator.push(context, slideUpRoute(const NotificationHistoryScreen())),
                ),
                MenuRow(
                  icon: Icons.wb_sunny_rounded,
                  title: 'Dark mode',
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.wb_sunny_outlined, size: 16)),
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 16)),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.nights_stay_outlined, size: 16)),
                    ],
                    selected: {themeMode},
                    showSelectedIcon: false,
                    emptySelectionAllowed: false,
                    onSelectionChanged: (v) => ref.read(themeModeProvider.notifier).setMode(v.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.of(context).primaryContainer,
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                MenuRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Support & Feedback',
                  onTap: () => Navigator.push(context, slideUpRoute(const SupportFeedbackScreen())),
                ),
              ],
            ),
          ),
          SectionLabel(title: 'Account'),
          FoamCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                MenuRow(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  danger: true,
                  onTap: () => _signOut(context, ref),
                ),
                MenuRow(
                  icon: Icons.delete_forever_rounded,
                  title: 'Delete account',
                  danger: true,
                  onTap: () => _confirmDeleteAccount(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(authServiceProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Local data will be cleared. Cloud copy stays safe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (ok != true) return;
    await authService.signOut();
    // The AuthGate (root route) already swaps to the Sign-In screen once the
    // auth stream emits null. Pop every pushed route (Account screen, overlays)
    // so the user lands on Sign-In immediately — no stale authenticated screen
    // can remain on top, and back-press from Sign-In cannot return to it.
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final deleted = await showDeleteAccountSheet(context, ref);
    if (deleted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account deleted successfully.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _editShopProfile(BuildContext context, WidgetRef ref, ShopProfile? current, OpeningBalance? openingBal) {
    final nameCtrl = TextEditingController(text: current?.shopName ?? '');
    final locCtrl = TextEditingController(text: current?.location ?? '');
    final phoneCtrl = TextEditingController(text: current?.phone ?? '');
    final capitalCtrl = TextEditingController(text: (openingBal?.capitalAmount ?? 0).toStringAsFixed(0));
    final currencies = ['PKR', 'USD', 'EUR', 'GBP', 'INR', 'AED', 'SAR'];
    String selectedCurrency = current?.currency ?? 'PKR';
    bool saving = false;

    showAppSheet<void>(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: StatefulBuilder(
          builder: (ctx, setSD) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shop Profile',
                style: AppTheme.display(context, size: 19),
              ),
              const SizedBox(height: 14),
              AppField(label: 'Shop Name *', controller: nameCtrl),
              AppField(label: 'Shop Location / City *', controller: locCtrl),
              AppField(label: 'Phone (optional)', controller: phoneCtrl, keyboardType: TextInputType.phone),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 6),
                      child: Text(
                        'CURRENCY',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.of(ctx).inkSoft, letterSpacing: 0.03),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.of(ctx).surface,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.of(ctx).outline, width: 1.5),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCurrency,
                          isExpanded: true,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.of(ctx).ink),
                          dropdownColor: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                          items: currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) {
                            if (v != null) setSD(() => selectedCurrency = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppField(
                label: 'Shuru ka Capital',
                controller: capitalCtrl,
                hintText: '0',
                keyboardType: TextInputType.number,
              ),
              Row(children: [
                Expanded(
                  child: AppButton(
                    variant: AppButtonVariant.ghost,
                    label: 'Cancel',
                    onTap: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: saving ? 'Saving\u2026' : 'Save',
                    onTap: saving
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty || locCtrl.text.trim().isEmpty) return;
                            setSD(() => saving = true);
                            try {
                              final service = ref.read(firestoreServiceProvider);
                              final profile = ShopProfile(
                                shopName: nameCtrl.text.trim(),
                                location: locCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                currency: selectedCurrency,
                                createdAt: current?.createdAt ?? DateTime.now(),
                              );
                              await service.setShopProfile(profile);
                              final cap = double.tryParse(capitalCtrl.text) ?? (openingBal?.capitalAmount ?? 0);
                              if (cap >= 0) {
                                await service.setOpeningBalance(OpeningBalance(
                                    id: openingBal?.id ?? service.generateId(),
                                    date: DateTime.now(),
                                    capitalAmount: cap));
                              }
                              ref.invalidate(shopProfileProvider);
                              ref.invalidate(shopProfileFutureProvider);
                              ref.invalidate(openingBalanceStreamProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e, st) {
                              logSecureError(e, st, tag: 'shop_profile');
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text('Could not save: $e'),
                                  backgroundColor: Theme.of(ctx).colorScheme.error,
                                ));
                              }
                              setSD(() => saving = false);
                            }
                          },
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      locCtrl.dispose();
      phoneCtrl.dispose();
      capitalCtrl.dispose();
    });
  }
}
