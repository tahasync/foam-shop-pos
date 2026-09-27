import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop_profile.dart';
import '../providers/firebase_providers.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/design_system/design_system.dart';

class ShopOnboardingScreen extends ConsumerStatefulWidget {
  const ShopOnboardingScreen({super.key});
  @override
  ConsumerState<ShopOnboardingScreen> createState() =>
      _ShopOnboardingScreenState();
}

class _ShopOnboardingScreenState extends ConsumerState<ShopOnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _currencies = ['PKR', 'USD', 'EUR', 'GBP', 'INR', 'AED', 'SAR'];
  late String _selectedCurrency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = _currencies[0];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameCtrl.text.trim().isNotEmpty &&
      _locCtrl.text.trim().isNotEmpty &&
      !_saving;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(firestoreServiceProvider);
      final user = ref.read(authServiceProvider).currentUser;
      final email = user?.email ?? '';
      final isFounder = AppConstants.foundingAccountEmails
          .any((e) => e.toLowerCase() == email.toLowerCase());
      final now = DateTime.now();
      final profile = ShopProfile(
        shopName: _nameCtrl.text.trim(),
        location: _locCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        currency: _selectedCurrency,
        createdAt: now,
        subscriptionStatus: isFounder ? 'free_forever' : 'trial',
        trialEndsAt:
            isFounder ? null : now.add(Duration(days: AppConstants.trialDays)),
        founderExempt: isFounder,
      );
      await service.setShopProfile(profile);
      ref.invalidate(shopProfileFutureProvider);
      ref.invalidate(shopProfileProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);

    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassContainer(
                    radius: 22,
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [ac.brandFill, ac.brandFillDeep],
                          ),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            size: 30, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Set Up Your Shop',
                    style: AppTheme.display(context, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shown once after your first Google sign-in. Used across receipts, reports, and every screen.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 13, color: ac.inkSoft, height: 1.6),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppField(
                            label: 'Shop name *',
                            controller: _nameCtrl,
                            onChanged: (_) => setState(() {})),
                        AppField(
                            label: 'Location',
                            controller: _locCtrl,
                            onChanged: (_) => setState(() {})),
                        AppField(
                          label: 'Phone (optional)',
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          onChanged: (_) => setState(() {}),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 2, bottom: 6),
                                child: Text(
                                  'CURRENCY',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: ac.inkSoft,
                                      letterSpacing: 0.03),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: GlassContainer(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  radius: 13,
                                  level: AppGlassLevel.raised,
                                  gloss: false,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCurrency,
                                      isExpanded: true,
                                      style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: ac.ink),
                                      dropdownColor: cs.surfaceContainerHigh,
                                      items: _currencies
                                          .map((c) => DropdownMenuItem(
                                                value: c,
                                                child: Text(c),
                                              ))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null)
                                          setState(() => _selectedCurrency = v);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppButton(
                          label: _saving ? 'Saving\u2026' : 'Continue \u2192',
                          onTap: _canSubmit ? _submit : null,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Editable anytime in Settings',
                            style:
                                TextStyle(fontSize: 10.5, color: ac.inkFaint),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
