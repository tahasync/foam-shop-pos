import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../firebase_options.dart';
import '../utils/rate_limiter.dart';
import '../utils/safe_error_handler.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;
  final RateLimiter _rateLimiter = RateLimiter(
    config: const RateLimitConfig(
      maxAttempts: 5,
      window: Duration(minutes: 1),
      cooldown: Duration(minutes: 5),
    ),
  );

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// True once [initialize] has completed. [GoogleSignIn.instance] must have
  /// `initialize()` awaited exactly once before any other method is called —
  /// calling `authenticate()` on an uninitialised singleton is undefined
  /// behaviour and surfaces to the user as a bare "Sign in failed".
  bool _initialized = false;

  /// The web OAuth client id actually passed to [GoogleSignIn.initialize].
  String? _serverClientId;

  /// This project's Web OAuth client id, mirroring the `client_type: 3` entry
  /// in `android/app/google-services.json`.
  static const String _fallbackWebClientId =
      '279323547618-e1n7bobp7b81f99idi7c4dkfoqoik435.apps.googleusercontent.com';

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    _googleSignIn = GoogleSignIn.instance;
    if (_initialized) return;

    final clientId = DefaultFirebaseOptions.webClientId.trim();

    if (clientId.isEmpty) {
      // Not fatal on Android: when the google-services Gradle plugin is applied,
      // the plugin reads the web OAuth client id from the generated
      // `default_web_client_id` string resource, so serverClientId is optional.
      //
      // This fallback is a real safety net, not decoration. That resource is
      // only generated when `google-services.json` contains a `client_type: 3`
      // (Web) client; if it is absent, `serverClientId` ends up null and Google
      // Sign-In fails with error 10 (clientConfigurationError) on every build.
      // Hardcoding the project's web client id means a trimmed-down config file
      // can no longer break sign-in for everyone.
      _serverClientId = _fallbackWebClientId;
      developer.log(
        '[Auth] FIREBASE_WEB_CLIENT_ID not set — using the built-in web client '
        'id fallback. For other platforms build with: '
        'flutter run --dart-define-from-file=env/firebase_config.json',
        name: 'auth',
      );
    } else {
      _serverClientId = clientId;
    }

    try {
      await _googleSignIn!.initialize(serverClientId: _serverClientId);
      _initialized = true;
    } catch (e, stack) {
      developer.log(
        '[Auth] GoogleSignIn.initialize() failed: $e',
        stackTrace: stack,
        name: 'auth',
      );
      // Not rethrown. A Play Services problem must not propagate: callers
      // treat initialize() as best-effort, and signInWithGoogle() retries it on
      // demand. Rethrowing here meant a single GMS failure escalated into a
      // fatal start-up error for the whole app.
      _initialized = false;
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    final deviceId = _auth.currentUser?.uid;
    final result =
        _rateLimiter.attempt(deviceId: 'device_sign_in', accountId: deviceId);
    if (!result.allowed) {
      logSecureError(
        RateLimitError(result.reason ?? 'Rate limit exceeded'),
        null,
        tag: 'auth',
      );
      throw result.reason ?? 'Too many attempts. Please wait.';
    }
    // Guard against authenticate() ever being reached on an uninitialised
    // GoogleSignIn singleton (e.g. initialize() failed at startup).
    if (!_initialized) {
      await initialize();
    }

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn!.authenticate();
    } on GoogleSignInException catch (e, stack) {
      logSecureError(e, stack, tag: 'auth');
      throw AuthSignInException(describeGoogleSignInError(e));
    }

    final GoogleSignInAuthentication auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthSignInException(
        'Google sign-in returned no ID token. Please try again.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);

    _rateLimiter.reset(deviceId: 'device_sign_in', accountId: deviceId);
    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e, stack) {
      logSecureError(e, stack, tag: 'auth');
      throw AuthSignInException(_describeFirebaseAuthError(e));
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  String? get userId => _auth.currentUser?.uid;
}

class RateLimitError implements Exception {
  final String message;
  const RateLimitError(this.message);
  @override
  String toString() => message;
}

/// A sign-in failure that already carries a user-safe, actionable message.
class AuthSignInException implements Exception {
  final String message;
  const AuthSignInException(this.message);
  @override
  String toString() => message;
}

/// Translates a platform [GoogleSignInException] into an actionable message.
///
/// The most common real-world cause is a signing-certificate mismatch: Google
/// validates the SHA-1 of the certificate the running APK was signed with
/// against the Android OAuth client registered in the Firebase/Cloud project.
/// A debug build signed by an unregistered keystore fails here with
/// `clientConfigurationError` (Google error 10 / DEVELOPER_ERROR).
String describeGoogleSignInError(GoogleSignInException e) {
  switch (e.code) {
    case GoogleSignInExceptionCode.clientConfigurationError:
      return 'Google Sign-In is not configured for this build.\n\n'
          'This app was signed with a certificate that is not registered in '
          'the Firebase project. Add the build\'s SHA-1 fingerprint under '
          'Firebase Console → Project settings → Your Android app → SHA keys, '
          'then rebuild.';
    case GoogleSignInExceptionCode.canceled:
    case GoogleSignInExceptionCode.interrupted:
      return 'Sign-in was cancelled. Please try again.';
    case GoogleSignInExceptionCode.uiUnavailable:
      return 'The Google Sign-In screen is unavailable right now. '
          'Check your internet connection and try again.';
    case GoogleSignInExceptionCode.providerConfigurationError:
      return 'Google Sign-In provider is not set up for this project. '
          'Please contact support.';
    case GoogleSignInExceptionCode.userMismatch:
      return 'The selected account is not allowed to sign in to this app.';
    default:
      return 'Google sign-in failed. Please try again.';
  }
}

String _describeFirebaseAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-credential':
    case 'account-exists-with-different-credential':
      return 'This Google account could not be linked. Please try again.';
    case 'operation-not-allowed':
      return 'Google sign-in is disabled for this project. '
          'Enable it in the Firebase console.';
    case 'web-context-canceled':
      return 'Sign-in was cancelled.';
    default:
      return 'Could not complete sign-in. Please try again.';
  }
}
