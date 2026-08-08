import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/safe_error_handler.dart';
import '../widgets/design_system/design_system.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  static const String _googleGSvg = '''
<svg width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.99.66-2.25 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.85A11 11 0 0 0 12 23z"/>
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
      body: SafeArea(
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
                  style: AppTheme.display(context, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your shop data, backed up to your Google account. Sales, inventory and khata \u2014 all in one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: ac.inkSoft, height: 1.6),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 240,
                  child: AppButton(
                    variant: AppButtonVariant.outline,
                    label: 'Sign in with Google',
                    leading: SvgPicture.string(_googleGSvg, width: 18, height: 18),
                    onTap: () async {
                      try {
                        await authService.signInWithGoogle();
                        if (context.mounted) {
                          final status = await Permission.storage.request();
                          debugPrint('[Perm] Storage permission: $status');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          final safeMsg = sanitizeErrorMessage(e, fallback: 'Sign in failed. Please try again.');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(safeMsg), backgroundColor: cs.error),
                          );
                          logSecureError(e, StackTrace.current, tag: 'auth');
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
