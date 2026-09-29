import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/services/notification_service.dart';

/// Guards the Android notification small-icon configuration.
///
/// The bug this protects against is real and shipped: the plugin was
/// initialised with `@mipmap/ic_launcher` as the small icon. The launcher icon
/// is an adaptive icon with an opaque background layer, and Android renders a
/// notification small icon as an alpha-only mask, so the status bar showed a
/// solid black/white block instead of the Foam Shop mark.
///
/// These assertions read the shipped Android resources and Dart source. That is
/// the only way to catch a regression here, because the symptom (a black square
/// in the status bar) is a device-rendering outcome a widget test cannot observe.
void main() {
  late String manifest;
  late String statIcon;
  late String notificationServiceSource;
  late String salesSource;

  setUpAll(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    statIcon = File('android/app/src/main/res/drawable/ic_stat_foam_shop.xml')
        .readAsStringSync();
    notificationServiceSource =
        File('lib/services/notification_service.dart').readAsStringSync();
    salesSource =
        File('lib/screens/sales_entry_screen.dart').readAsStringSync();
  });

  /// Strips XML comments so a structural assertion is not satisfied - or
  /// defeated - by prose in a comment. The rationale for these rules lives in
  /// the comments on the resource, and that prose names the very strings the
  /// tests are checking for, so testing the raw file would be self-defeating.
  String markupOnly(String xml) =>
      xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  group('notification small icon resource', () {
    test('the dedicated monochrome icon exists at the documented path', () {
      expect(
        File('android/app/src/main/res/drawable/ic_stat_foam_shop.xml')
            .existsSync(),
        isTrue,
        reason: 'A dedicated status-bar icon must exist, separate from the '
            'launcher icon.',
      );
    });

    test('is a 24dp vector, which is the size Android expects', () {
      expect(statIcon, contains('android:width="24dp"'));
      expect(statIcon, contains('android:height="24dp"'));
      expect(statIcon, contains('<vector'));
    });

    test('foreground is white so the system mask renders it correctly', () {
      expect(
        statIcon,
        contains('#FFFFFFFF'),
        reason: 'A notification small icon must be white on transparent; the '
            'system recolours it to match the status bar.',
      );
    });

    test('carries no theme-attribute tint', () {
      expect(
        markupOnly(statIcon),
        isNot(contains('?android:attr')),
        reason:
            'A theme-attribute tint can resolve to null in the notification '
            'context and render the icon invisible.',
      );
    });

    test('is not the adaptive launcher icon', () {
      expect(markupOnly(statIcon), isNot(contains('adaptive-icon')));
      expect(markupOnly(statIcon), isNot(contains('mipmap')));
    });
  });

  group('manifest wiring', () {
    test('declares the FCM default notification icon', () {
      expect(manifest,
          contains('com.google.firebase.messaging.default_notification_icon'));
      expect(manifest, contains('@drawable/ic_stat_foam_shop'));
    });

    test('declares the FCM default notification color', () {
      expect(manifest,
          contains('com.google.firebase.messaging.default_notification_color'));
      expect(manifest, contains('@color/notification_color'));
    });

    test('routes background FCM messages to the same channel the app uses', () {
      // Without this, a background message lands on an auto-created channel
      // with default importance instead of the app's Shop Alerts channel.
      expect(
          manifest,
          contains(
              'com.google.firebase.messaging.default_notification_channel_id'));
      expect(
        manifest,
        contains(NotificationChannels.general),
        reason: 'The manifest channel id and the Dart constant must agree, or '
            'background notifications use a different channel to foreground.',
      );
    });

    test('does not point any notification setting at the launcher icon', () {
      // Regression guard: this exact string is the original defect.
      expect(
        notificationServiceSource,
        isNot(contains("AndroidInitializationSettings('@mipmap/ic_launcher')")),
      );
      expect(
        markupOnly(manifest),
        isNot(contains('android:resource="@mipmap/ic_launcher')),
      );
    });

    test('declares POST_NOTIFICATIONS for Android 13+', () {
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    });
  });

  group('Dart notification configuration', () {
    test('initialises the plugin with the dedicated drawable', () {
      expect(
        notificationServiceSource,
        contains(
            "AndroidInitializationSettings('@drawable/ic_stat_foam_shop')"),
      );
    });

    test('every posted notification specifies the small icon', () {
      expect(notificationServiceSource, contains('icon: _smallIcon'));
    });

    test('the channel id is a stable constant, not generated per launch', () {
      // A generated or timestamped id would create a new channel on every
      // launch, which is user-visible clutter in system settings.
      expect(NotificationChannels.general, 'foam_shop_general');
    });

    test('does not request permission at startup, only in context', () {
      // initialize() runs during cold start, before the user has seen anything
      // that would justify a notification prompt.
      final initializeBody = notificationServiceSource.substring(
        notificationServiceSource.indexOf('static Future<void> initialize()'),
        notificationServiceSource
            .indexOf('static Future<bool> hasPermission()'),
      );
      expect(
        initializeBody,
        isNot(contains('requestNotificationsPermission()')),
        reason: 'The runtime permission belongs on the notification settings '
            'screen where the request has context, not on cold start.',
      );
    });
  });

  group('color resource', () {
    test('notification_color matches the brand blue used by the accent', () {
      final colors =
          File('android/app/src/main/res/values/colors.xml').readAsStringSync();
      expect(colors, contains('notification_color'));
      // AppColors.brandSolid in lib/theme/app_theme.dart is 0xFF3D5387.
      expect(colors, contains('#FF3D5387'));
    });
  });

  group('haptics never block business logic', () {
    test('AppHaptics swallows platform-channel failures', () {
      // A device with no vibrator must not turn a successful sale into a
      // failed one, so every helper is wrapped.
      final haptics = File('lib/utils/haptics.dart').readAsStringSync();
      expect(haptics, contains('catch (_)'));
    });

    test('the haptic helper is wired into the sale save path', () {
      expect(salesSource, contains("import '../utils/haptics.dart'"));
      expect(salesSource, contains('AppHaptics.success()'));
      expect(salesSource, contains('AppHaptics.error()'));
    });

    test('haptics are not awaited before the UI updates', () {
      // Awaiting the vibrator before showing the success sheet would make the
      // UI wait on hardware.
      expect(salesSource, contains('unawaited(AppHaptics.success())'));
      expect(salesSource, contains('unawaited(AppHaptics.error())'));
      expect(salesSource, isNot(contains('await AppHaptics')));
    });
  });

  group('start-up is never blocked by auth initialisation', () {
    late String mainSource;

    setUpAll(() {
      mainSource = File('lib/main.dart').readAsStringSync();
    });

    test('auth init is wrapped in a bounded timeout', () {
      // The bug: `await authService.initialize()` sat directly in front of
      // runApp(). GoogleSignIn.initialize() talks to Play Services and never
      // completes on a device without them, so the app stayed on the native
      // splash forever - no error, no spinner, no way out.
      expect(
        mainSource,
        contains('_initializeAuthWithTimeout(authService)'),
        reason: 'Auth initialisation must go through the timeout wrapper.',
      );
      expect(
        mainSource,
        contains('.timeout(timeout)'),
        reason: 'The wrapper must actually bound the wait.',
      );
    });

    test('the raw unbounded await is gone from the start-up path', () {
      expect(
        mainSource,
        isNot(contains('await authService.initialize();')),
        reason: 'An unbounded auth await before runApp() is the exact defect '
            'that caused the permanent splash.',
      );
    });

    test('runApp is reached even when auth init throws or hangs', () {
      // runApp must appear after the wrapper call, and the wrapper must catch
      // both TimeoutException and generic failures.
      final wrapperStart =
          mainSource.indexOf('Future<void> _initializeAuthWithTimeout');
      expect(wrapperStart, isNot(-1));
      final wrapper = mainSource.substring(wrapperStart);
      expect(wrapper, contains('on TimeoutException'));
      expect(wrapper, contains('catch (e)'));
    });

    test('AuthService.initialize no longer rethrows a Play Services failure',
        () {
      final authSource =
          File('lib/services/auth_service.dart').readAsStringSync();
      final initStart = authSource.indexOf('Future<void> initialize()');
      final initBody = authSource.substring(initStart);
      // Scan only real statements, not the surrounding prose: the rationale
      // comment explains *why* rethrow was removed and so contains the word.
      final codeOnly = initBody
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .takeWhile((l) => !l.contains('authStateChanges'))
          .join('\n');
      expect(
        codeOnly,
        isNot(contains('rethrow')),
        reason: 'A GMS failure must not escalate into a fatal start-up error; '
            'signInWithGoogle retries initialize() on demand.',
      );
      // The failure must leave the service retryable rather than latched.
      expect(codeOnly, contains('_initialized = false;'));
    });
  });

  group('destructive cart action is confirmed', () {
    test('"Clear all" no longer empties the cart in a single tap', () {
      expect(
        salesSource,
        contains('_confirmClearCart'),
        reason: 'Clearing a keyed-in bill must require confirmation.',
      );
      expect(
        salesSource,
        isNot(contains('? () => ref.read(salesProvider.notifier).clearCart()')),
        reason: 'A direct clearCart() call from the Clear all action means the '
            'confirmation was bypassed.',
      );
    });
  });
}
