import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop_profile.dart';
import '../providers/firebase_providers.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';

class ShopOnboardingScreen extends ConsumerStatefulWidget {
  const ShopOnboardingScreen({super.key});
  @override
  ConsumerState<ShopOnboardingScreen> createState() => _ShopOnboardingScreenState();
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
      final profile = ShopProfile(
        shopName: _nameCtrl.text.trim(),
        location: _locCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        currency: _selectedCurrency,
        createdAt: DateTime.now(),
      );
      await service.setShopProfile(profile);
      ref.invalidate(shopProfileFutureProvider);
      ref.invalidate(shopProfileProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: Theme.of(context).colorScheme.error),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.teal, AppTheme.tealDark]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.store_rounded, size: 30, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text('Set Up Your Shop',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Shown once after your first Google sign-in. Used across receipts, reports, and every screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(height: 32),
                _buildField('Shop Name', _nameCtrl, required: true),
                const SizedBox(height: 14),
                _buildField('Shop Location / City', _locCtrl, required: true),
                const SizedBox(height: 14),
                _buildField('Phone (optional)', _phoneCtrl, keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                _buildCurrencySelector(),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Continue \u2192', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                Text('Editable anytime in Settings',
                    style: TextStyle(fontSize: 11, color: ac.inkFaint)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {bool required = false, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (required)
            Text(' *', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error)),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            hintText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildCurrencySelector() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Currency',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCurrency,
              isExpanded: true,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
              items: _currencies.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c),
              )).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCurrency = v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
