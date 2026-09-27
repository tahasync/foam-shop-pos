import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system/design_system.dart';

Future<bool> showDeleteAccountSheet(BuildContext context, WidgetRef ref) async {
  final result = await showAppSheet<bool>(
    context: context,
    builder: (_) => _DeleteAccountSheet(),
  );
  return result ?? false;
}

class _DeleteAccountSheet extends StatefulWidget {
  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _confirmCtrl = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      _confirmCtrl.text.trim().toUpperCase() == 'DELETE' && !_deleting;

  Future<void> _delete() async {
    if (!_canDelete) return;
    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      final uid = user.uid;
      final db = FirebaseFirestore.instance;

      final googleSignIn = GoogleSignIn.instance;
      final clientId = DefaultFirebaseOptions.webClientId;
      await googleSignIn.initialize(serverClientId: clientId);

      final googleAccount = await googleSignIn.authenticate();
      final googleAuth = await googleAccount.authentication;
      final credential =
          GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      await user.reauthenticateWithCredential(credential);

      final batchSize = 500;
      final collections = [
        'products',
        'customers',
        'suppliers',
        'sales',
        'purchases',
        'expenses',
        'payments',
        'supplier_payments',
        'opening_balances',
        'settings',
      ];

      for (final col in collections) {
        var hasMore = true;
        while (hasMore) {
          final snapshot = await db
              .collection('users')
              .doc(uid)
              .collection(col)
              .limit(batchSize)
              .get();
          if (snapshot.docs.isEmpty) {
            hasMore = false;
            break;
          }
          final batch = db.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          if (snapshot.docs.length < batchSize) {
            hasMore = false;
          }
        }
      }

      await user.delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' ||
          e.code == 'credential-already-in-use') {
        setState(() {
          _deleting = false;
          _error = 'Re-authentication failed. Please sign out and try again.';
        });
      } else {
        setState(() {
          _deleting = false;
          _error = e.message ?? 'Authentication error. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _deleting = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return AppSheetContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: ac.expenseTint, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.warning_amber_rounded,
                size: 20, color: ac.expenseFg),
          ),
          const SizedBox(height: 12),
          Text(
            'Delete your account?',
            style: AppTheme.display(context, size: 19),
          ),
          const SizedBox(height: 6),
          Text(
            'This permanently deletes your shop profile and all products, sales, customers, and history. This cannot be undone.',
            style: TextStyle(fontSize: 12, color: ac.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: ac.saleTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.file_download_rounded, size: 16, color: ac.saleFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Export your data first (recommended)',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ac.saleFg)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          AppField(
            label: 'Type DELETE to confirm',
            controller: _confirmCtrl,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: ac.expenseTint,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.error_outline_rounded,
                    size: 16, color: ac.expenseFg),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: TextStyle(fontSize: 11, color: ac.expenseFg))),
                GestureDetector(
                    onTap: () => setState(() => _error = null),
                    child: Icon(Icons.close_rounded,
                        size: 14, color: ac.expenseFg)),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          Row(children: [
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.ghost,
                label: 'Cancel',
                onTap: _deleting ? null : () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.danger,
                label: _deleting ? 'Deleting\u2026' : 'Permanently Delete',
                onTap: _canDelete ? _delete : null,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
