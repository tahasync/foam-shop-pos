import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/opening_balance.dart';
import '../models/shop_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/safe_error_handler.dart';
import '../utils/currency.dart';
import 'delete_account_sheet.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final authState = ref.watch(authStateProvider);
    final authService = ref.watch(authServiceProvider);
    final user = authState.asData?.value;
    final obAsync = ref.watch(openingBalanceStreamProvider);
    final themeMode = ref.watch(themeModeProvider);
    final shopAsync = ref.watch(shopProfileProvider);

    final openingBal = obAsync.asData?.value;
    final profile = shopAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Account / Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null ? const Icon(Icons.person_rounded, size: 36) : null,
                ),
                const SizedBox(height: 12),
                Text(user?.displayName ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(user?.email ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              ListTile(
                leading: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.store_rounded, color: cs.onPrimaryContainer)),
                title: const Text('Shop Profile'),
                subtitle: Text(
                  profile != null ? '${profile.shopName} \u00b7 ${profile.location}' : 'Not set up',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _editShopProfile(context, ref, profile),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              ListTile(
                leading: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.account_balance_rounded, color: cs.onPrimaryContainer)),
                title: const Text('Shuru ka Capital'),
                subtitle: Text('${currencySymbolFromCode(profile?.currency ?? 'PKR')}. ${(openingBal?.capitalAmount ?? 0).toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.edit_rounded),
                onTap: () => _editCapital(context, ref, openingBal, profile),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.brightness_6_rounded, size: 18, color: cs.onSecondaryContainer)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Theme: ${themeMode == ThemeMode.light ? 'Light' : themeMode == ThemeMode.dark ? 'Dark' : 'System'}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(
                    width: 150,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.wb_sunny_outlined, size: 18)),
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 18)),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.nights_stay_outlined, size: 18)),
                      ],
                      selected: {themeMode},
                      showSelectedIcon: false,
                      emptySelectionAllowed: false,
                      onSelectionChanged: (v) => ref.read(themeModeProvider.notifier).setMode(v.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: cs.primaryContainer,
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: cs.error),
              title: Text('Sign Out', style: TextStyle(color: cs.error)),
              onTap: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Local data will be cleared. Cloud copy stays safe.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
                  ],
                ));
                if (ok == true) await authService.signOut();
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildDangerZone(context, ref),
        ],
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ac.expenseFg.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: ac.expenseFg),
              const SizedBox(width: 6),
              Text('Danger Zone',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ac.expenseFg, letterSpacing: 0.05)),
            ]),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _confirmDeleteAccount(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(Icons.delete_forever_rounded, size: 18, color: ac.expenseFg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Delete Account',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ac.expenseFg)),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: ac.expenseFg),
              ]),
            ),
          ),
        ],
      ),
    );
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

  void _editShopProfile(BuildContext context, WidgetRef ref, ShopProfile? current) {
    final nameCtrl = TextEditingController(text: current?.shopName ?? '');
    final locCtrl = TextEditingController(text: current?.location ?? '');
    final phoneCtrl = TextEditingController(text: current?.phone ?? '');
    final currencies = ['PKR', 'USD', 'EUR', 'GBP', 'INR', 'AED', 'SAR'];
    String selectedCurrency = current?.currency ?? 'PKR';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSD) => AlertDialog(
          title: const Text('Shop Profile', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Shop Name *', filled: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locCtrl,
                decoration: const InputDecoration(labelText: 'Shop Location / City *', filled: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone (optional)', filled: true),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCurrency,
                decoration: const InputDecoration(labelText: 'Currency', filled: true),
                items: currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) {
                  if (v != null) setSD(() => selectedCurrency = v);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
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
                        ref.invalidate(shopProfileProvider);
                        ref.invalidate(shopProfileFutureProvider);
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
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      locCtrl.dispose();
      phoneCtrl.dispose();
    });
  }

  void _editCapital(BuildContext context, WidgetRef ref, OpeningBalance? current, ShopProfile? profile) {
    final ctrl = TextEditingController(text: (current?.capitalAmount ?? 0).toStringAsFixed(0));
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Shuru ka Capital'),
      content: SingleChildScrollView(child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: 'Opening Capital (${profile?.currency ?? 'PKR'})',
          filled: true,
        ),
        keyboardType: TextInputType.number,
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          try {
            final a = double.tryParse(ctrl.text) ?? 0;
            if (a < 0) return;
            final s = ref.read(firestoreServiceProvider);
            await s.setOpeningBalance(OpeningBalance(
                id: current?.id ?? s.generateId(), date: DateTime.now(), capitalAmount: a));
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e, st) {
            if (ctx.mounted) {
              final safeMsg = sanitizeErrorMessage(e, fallback: 'Could not save opening balance.');
              logSecureError(e, st, tag: 'opening_balance');
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(safeMsg), backgroundColor: Theme.of(ctx).colorScheme.error));
            }
          }
        }, child: const Text('Save')),
      ],
    )).then((_) => ctrl.dispose());
  }
}
