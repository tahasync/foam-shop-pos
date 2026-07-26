import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../theme/app_theme.dart';

Future<bool> showDeleteAccountSheet(BuildContext context, WidgetRef ref) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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

  bool get _canDelete => _confirmCtrl.text.trim().toUpperCase() == 'DELETE' && !_deleting;

  Future<void> _delete() async {
    if (!_canDelete) return;
    setState(() { _deleting = true; _error = null; });

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
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      await user.reauthenticateWithCredential(credential);

      final batchSize = 500;
      final collections = [
        'products', 'customers', 'suppliers', 'sales',
        'purchases', 'expenses', 'payments', 'supplier_payments',
        'opening_balances', 'settings',
      ];

      for (final col in collections) {
        var hasMore = true;
        while (hasMore) {
          final snapshot = await db
              .collection('users').doc(uid)
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
      if (e.code == 'requires-recent-login' || e.code == 'credential-already-in-use') {
        setState(() { _deleting = false; _error = 'Re-authentication failed. Please sign out and try again.'; });
      } else {
        setState(() { _deleting = false; _error = e.message ?? 'Authentication error. Please try again.'; });
      }
    } catch (e) {
      setState(() { _deleting = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: ac.expenseTint, shape: BoxShape.circle),
          child: Icon(Icons.warning_rounded, size: 22, color: ac.expenseFg),
        ),
        const SizedBox(height: 14),
        Text('Delete Your Account?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(
          'This permanently deletes your shop profile and all products, sales, customers, and history. This cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ac.saleTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.file_download_rounded, size: 16, color: ac.saleFg),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Export your data first (recommended)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ac.saleFg)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type DELETE to confirm',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _confirmCtrl,
              decoration: InputDecoration(
                hintText: 'DELETE',
                filled: true,
                fillColor: cs.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ac.expenseFg, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ac.expenseFg.withValues(alpha: 0.5), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ac.expenseFg, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ac.expenseTint, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, size: 16, color: ac.expenseFg),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: TextStyle(fontSize: 11, color: ac.expenseFg))),
              GestureDetector(onTap: () => setState(() => _error = null), child: Icon(Icons.close_rounded, size: 14, color: ac.expenseFg)),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _canDelete ? _delete : null,
          style: FilledButton.styleFrom(
            backgroundColor: ac.expenseFg,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            disabledBackgroundColor: cs.onSurfaceVariant.withValues(alpha: 0.2),
          ),
          child: _deleting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Permanently Delete Account', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        ),
      ]),
    );
  }
}
