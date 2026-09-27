import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/safe_error_handler.dart';
import '../widgets/design_system/design_system.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  static const String _googleGSvg = '''
<svg width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.85A11 11 0 0 0 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.09A6.6 6.6 0 0 1 5.5 12c0-.73.13-1.43.34-2.09V7.06H2.18a11 11 0 0 0 0 9.88l3.66-2.85z"/>
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1a11 11 0 0 0-9.82 6.06l3.66 2.85C6.71 7.31 9.14 5.38 12 5.38z"/>
</svg>
''';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final authService = ref.watch(authServiceProvider);

    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 64, iconSize: 30),
                  const SizedBox(height: 22),
                  Text(
                    'Digital Register',
                    style: AppTheme.display(context, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Smart POS for your shop',
                    style: TextStyle(fontSize: 12.5, color: ac.inkSoft),
                  ),
                  const SizedBox(height: 28),
                  _FeatureCard(icon: '📊', title: 'Track Sales', subtitle: 'Every transaction recorded'),
                  const SizedBox(height: 10),
                  _FeatureCard(icon: '📦', title: 'Manage Inventory', subtitle: 'Stock levels in real time'),
                  const SizedBox(height: 10),
                  _FeatureCard(icon: '📈', title: 'Smart Analytics', subtitle: 'Profit & loss insights'),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      variant: AppButtonVariant.primary,
                      label: 'Sign in with Google',
                      leading: SvgPicture.string(_googleGSvg, width: 18, height: 18),
                      onTap: () async {
                        try {
                          await authService.signInWithGoogle();
                          if (context.mounted) {
                            // Android 10+ uses MediaStore for receipt writes,
                            // which needs no runtime permission, so this is only a
                            // best-effort request for the legacy storage path.
                            // A denial must never block a completed sign-in, so
                            // it is requested and discarded.
                            try {
                              await Permission.storage.request();
                            } catch (_) {
                              // Unsupported on this platform/version — receipts
                              // still save through MediaStore.
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            // AuthService already returns user-safe, actionable
                            // messages (e.g. the SHA-1 registration hint). Only
                            // fall back to the generic sanitizer for anything else.
                            final safeMsg = e is AuthSignInException
                                ? e.message
                                : sanitizeErrorMessage(
                                    e,
                                    fallback:
                                        'Sign in failed. Please try again.',
                                  );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(safeMsg),
                                backgroundColor: cs.error,
                                duration: const Duration(seconds: 8),
                              ),
                            );
                            logSecureError(e, StackTrace.current, tag: 'auth');
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    level: AppGlassLevel.raised,
                    gloss: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 13, color: ac.inkFaint),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'Your data stays on your device. No tracking, ever.',
                            style: TextStyle(fontSize: 10.5, color: ac.inkFaint),
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

class _FeatureCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GlassContainer(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      level: AppGlassLevel.raised,
      gloss: false,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ac.brandSolid.withValues(alpha: 0.25),
                  ac.brandSolid.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: ac.ink)),
                const SizedBox(height: 1),
                Text(subtitle, style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
