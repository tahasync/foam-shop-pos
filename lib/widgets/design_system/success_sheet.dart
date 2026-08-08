import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';

/// Success confirmation (mockup `.success-card`): animated check, title,
/// subtitle, and two actions.
class SuccessSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  const SuccessSheet({
    super.key,
    required this.title,
    required this.subtitle,
    this.primaryLabel = 'Continue',
    this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    String primaryLabel = 'Continue',
    String? secondaryLabel,
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x800A0814),
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SuccessSheet(
          title: title,
          subtitle: subtitle,
          primaryLabel: primaryLabel,
          secondaryLabel: secondaryLabel,
          onPrimary: onPrimary,
          onSecondary: onSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 32, 26, 26),
      decoration: BoxDecoration(
        color: ac.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AnimatedCheck(),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTheme.display(context, size: 19),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: ac.inkSoft),
          ),
          const SizedBox(height: 20),
          Row(children: [
            if (secondaryLabel != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSecondary?.call();
                  },
                  child: Text(secondaryLabel!),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onPrimary?.call();
                },
                child: Text(primaryLabel),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Toast-style message shown above the nav bar. Uses the theme's snackbar
/// chrome (rounded 14px floating).
void showAppToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 2200),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
