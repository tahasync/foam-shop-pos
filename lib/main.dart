import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'services/notification_service.dart';
import 'utils/safe_error_handler.dart';
import 'widgets/design_system/design_system.dart';

void main() {
  // Inter/Manrope/Fraunces are bundled in assets/fonts — never attempt a
  // runtime fetch (failing DNS must never crash the app with an unhandled
  // exception on a device without connectivity).
  GoogleFonts.config.allowRuntimeFetching = false;
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    ErrorWidget.builder = (details) {
      logDiagnostic('Widget error: ${details.exception}', tag: 'FATAL');
      final theme = AppTheme.light();
      return Material(
        color: theme.colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Something went wrong',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    };

    try {
      if (Firebase.apps.isNotEmpty) {
        logDiagnostic('Already initialized by native auto-init — skipping.',
            tag: 'Firebase');
      } else {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } on FirebaseException catch (e) {
          if (e.code == 'duplicate-app') {
            logDiagnostic('Duplicate init suppressed (native auto-init won).',
                tag: 'Firebase');
          } else {
            rethrow;
          }
        }
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } catch (e) {
      runApp(ProviderScope(
          child: _FatalError(message: 'Failed to initialize: $e')));
      return;
    }

    unawaited(_initBackgroundServices());
    unawaited(LocalNotificationService.initialize());

    // GoogleSignIn.initialize() is awaited here but must NEVER be able to hold
    // the app on the native splash. It talks to Play Services, and on a device
    // with no Play Services, a locked/disabled GMS, or a network that never
    // answers, the platform-channel call simply never completes. Because this
    // await sat in front of runApp(), that produced a permanently blank splash
    // with no error, no spinner, and no way forward - the app looked hung
    // rather than broken.
    //
    // Two things change:
    //  * the wait is bounded, so a hung call is abandoned after a short window;
    //  * a failure no longer aborts start-up. Google sign-in is one entry
    //    point; the app is still useful for an already-signed-in user, and
    //    signInWithGoogle() re-runs initialize() on demand (it is idempotent),
    //    so a later retry with working GMS can still succeed.
    final authService = AuthService();
    await _initializeAuthWithTimeout(authService);

    runApp(const ProviderScope(child: FoamShopApp()));
  }, (Object error, StackTrace stack) {
    // The stack carries absolute build paths, so it is debug-only. The error
    // itself still reaches Crashlytics via the handlers in _initBackgroundServices.
    logDiagnosticWithStack('Unhandled error: $error', stack, tag: 'FATAL');
    runApp(ProviderScope(
        child: _FatalError(message: 'Unexpected error occurred')));
  });
}

/// Runs [AuthService.initialize] under a hard time limit.
///
/// Returns normally whether init succeeded, failed, or never finished. The
/// underlying future is intentionally not cancelled: abandoning the `await`
/// is enough to unblock start-up, and letting the original call settle in the
/// background avoids tearing down a partially-initialised plugin mid-flight.
Future<void> _initializeAuthWithTimeout(AuthService authService) async {
  const timeout = Duration(seconds: 8);
  try {
    await authService.initialize().timeout(timeout);
  } on TimeoutException {
    logDiagnostic(
      'GoogleSignIn.initialize() did not complete within '
      '${timeout.inSeconds}s - continuing to the UI. Sign-in will retry on '
      'demand.',
      tag: 'Auth',
    );
  } catch (e) {
    // Deliberately swallowed and logged only. Rethrowing here would replace
    // the app with the fatal-error screen over a non-essential service.
    logDiagnostic('GoogleSignIn.initialize() failed: $e', tag: 'Auth');
  }
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
  } catch (_) {}
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
                Icon(Icons.error_outline_rounded,
                    size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text('Digital Register', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(message,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center),
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
                  // Entitlement is read from the server-stored profile only.
                  //
                  // This used to ALSO trust `AppConstants.foundingAccountEmails`
                  // - a list of personal email addresses compiled into the APK -
                  // and treat a match as proof of founder status. That was never
                  // a security control: the person holding the phone chooses
                  // which account they sign in with. `founder_exempt` and
                  // `subscription_status` are now server-owned (a client write
                  // that changes them is denied by the Firestore rules), so the
                  // server flag is the only thing consulted.
                  if (profile.founderExempt ||
                      profile.subscriptionStatus == 'free_forever') {
                    return const HomeScreen();
                  }
                  if (!profile.isSubscriptionActive) {
                    return SubscriptionExpiredScreen(
                        shopName: profile.shopName);
                  }
                  return const HomeScreen();
                }
                return const ShopOnboardingScreen();
              },
              loading: () => const LoadingScreen(
                title: 'Setting up your shop',
                subtitle: 'Fetching your products, sales and khata. '
                    'This can take a moment on a slow connection.',
              ),
              error: (_, __) => const HomeScreen(),
            );
          });
        }
        return const SignInScreen();
      },
      loading: () => const LoadingScreen(
        title: 'Loading',
        subtitle: 'Checking your account.',
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
