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

  Future<void> initialize() async {
    _googleSignIn = GoogleSignIn.instance;
    final clientId = DefaultFirebaseOptions.webClientId;
    if (clientId.isEmpty) {
      developer.log(
        '[Auth] FIREBASE_WEB_CLIENT_ID not set — Google Sign-In will fail at use time. '
        'Build with: flutter run --dart-define-from-file=env/firebase_config.json',
        name: 'auth',
      );
      return;
    }
    await _googleSignIn!.initialize(serverClientId: clientId);
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    final deviceId = _auth.currentUser?.uid;
    final result = _rateLimiter.attempt(deviceId: 'device_sign_in', accountId: deviceId);
    if (!result.allowed) {
      logSecureError(
        RateLimitError(result.reason ?? 'Rate limit exceeded'),
        null,
        tag: 'auth',
      );
      throw result.reason ?? 'Too many attempts. Please wait.';
    }
    final GoogleSignInAccount account =
        await _googleSignIn!.authenticate();
    final GoogleSignInAuthentication auth = account.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
    );

    _rateLimiter.reset(deviceId: 'device_sign_in', accountId: deviceId);
    return await _auth.signInWithCredential(credential);
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