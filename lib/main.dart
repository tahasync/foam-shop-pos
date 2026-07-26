import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/shop_provider.dart';
import 'services/auth_service.dart';
import 'screens/sign_in_screen.dart';
import 'screens/home_screen.dart';
import 'screens/shop_onboarding_screen.dart';
import 'screens/subscription_expired_screen.dart';
import 'utils/constants.dart';
import 'services/notification_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    ErrorWidget.builder = (details) {
      debugPrint('[FATAL] Widget error: ${details.exception}');
      final theme = AppTheme.light();
      return Material(
        color: theme.colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Something went wrong', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    };

    try {
      if (Firebase.apps.isNotEmpty) {
        debugPrint('[Firebase] Already initialized by native auto-init — skipping.');
      } else {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } on FirebaseException catch (e) {
          if (e.code == 'duplicate-app') {
            debugPrint('[Firebase] Duplicate init suppressed (native auto-init won).');
          } else {
            rethrow;
          }
        }
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } catch (e) {
      runApp(ProviderScope(child: _FatalError(message: 'Failed to initialize: $e')));
      return;
    }

    unawaited(_initBackgroundServices());
    unawaited(LocalNotificationService.initialize());

    final authService = AuthService();
    await authService.initialize();

    runApp(const ProviderScope(child: FoamShopApp()));
  }, (Object error, StackTrace stack) {
    debugPrint('[FATAL] Unhandled error: $error');
    debugPrint('[FATAL] Stack trace: $stack');
    runApp(ProviderScope(child: _FatalError(message: 'Unexpected error occurred')));
  });
}

bool get _isEmulator {
  if (!Platform.isAndroid) return false;
  try {
    return Platform.environment['ANDROID_EMULATOR'] == '1' ||
           Platform.environment['ANDROID_SERIAL']?.contains('emulator') == true;
  } catch (_) {
    return false;
  }
}

Future<void> _initBackgroundServices() async {
  try {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack);
      return true;
    };
    if (!_isEmulator) {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
    }
  } catch (_) {
  }
}

class _FatalError extends StatelessWidget {
  final String message;
  const _FatalError({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.light();
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text('Digital Register', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FoamShopApp extends ConsumerWidget {
  const FoamShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Foam Shop — Digital Register',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return Consumer(builder: (context, ref, _) {
            final shopAsync = ref.watch(shopProfileFutureProvider);
            return shopAsync.when(
              data: (profile) {
                if (profile != null) {
                  final email = user.email ?? '';
                  final isFounder = AppConstants.foundingAccountEmails.any(
                      (e) => e.toLowerCase() == email.toLowerCase());
                  if (isFounder || profile.founderExempt ||
                      profile.subscriptionStatus == 'free_forever') {
                    return const HomeScreen();
                  }
                  if (!profile.isSubscriptionActive) {
                    return SubscriptionExpiredScreen(shopName: profile.shopName);
                  }
                  return const HomeScreen();
                }
                return const ShopOnboardingScreen();
              },
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const HomeScreen(),
            );
          });
        }
        return const SignInScreen();
      },
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading...', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Digital Register')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 64),
              const SizedBox(height: 16),
              const Text('Could not sign in', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.invalidate(authStateProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}