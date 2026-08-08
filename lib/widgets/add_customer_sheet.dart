import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../providers/firebase_providers.dart';
import '../theme/app_theme.dart';
import '../utils/safe_error_handler.dart';
import 'design_system/design_system.dart';

/// Shared "Add Customer" sheet (mockup `sheet-addCustomer`) used by the Khata
/// screen and the Sales change-customer sheet. Saves the customer to Firestore
/// and returns the created [Customer] (or null when cancelled).
Future<Customer?> showAddCustomerSheet(BuildContext context, WidgetRef ref) async {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  final result = await showAppSheet<Customer>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSD) => AppSheetContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Customer', style: AppTheme.display(context, size: 19)),
            const SizedBox(height: 14),
            AppField(
              label: 'Name',
              controller: nameCtrl,
              hintText: 'e.g. Hafsa Traders',
              onChanged: (_) => setSD(() {}),
            ),
            AppField(
              label: 'Phone (optional)',
              controller: phoneCtrl,
              hintText: '03xx xxxxxxx',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 4),
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
                  label: 'Add Customer',
                  icon: Icons.check_rounded,
                  onTap: nameCtrl.text.trim().isEmpty
                      ? null
                      : () {
                          final svc = ref.read(firestoreServiceProvider);
                          final customer = Customer(
                            id: svc.generateId(),
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                          );
                          svc.addCustomer(customer).catchError((e, st) {
                            logSecureError(e, st, tag: 'customer_add');
                          });
                          Navigator.pop(ctx, customer);
                        },
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );

  nameCtrl.dispose();
  phoneCtrl.dispose();
  return result;
}
