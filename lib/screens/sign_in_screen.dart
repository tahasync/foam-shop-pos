import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../utils/safe_error_handler.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final authService = ref.watch(authServiceProvider);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SvgPicture.asset('assets/logo.svg', width: 96, height: 96, fit: BoxFit.cover),
              ).animate().fadeIn(duration: 400.ms).scaleY(begin: 0.8),
              const SizedBox(height: 24),
              Text('Digital Register',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700))
                  .animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
              const SizedBox(height: 6),
              Text('Digital Register',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant))
                  .animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await authService.signInWithGoogle();
                    if (context.mounted) {
                      final status = await Permission.storage.request();
                      if (status.isGranted) {
                        debugPrint('[Perm] Storage permission granted');
                      } else {
                        debugPrint('[Perm] Storage permission denied: $status');
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final safeMsg = sanitizeErrorMessage(e, fallback: 'Sign in failed. Please try again.');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(safeMsg), backgroundColor: Theme.of(context).colorScheme.error),
                      );
                      logSecureError(e, StackTrace.current, tag: 'auth');
                    }
                  }
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in with Google'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(280, 54),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.3),
              const SizedBox(height: 32),
              Text('Your shop data, backed up to your Google account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
