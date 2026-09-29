import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Logs a diagnostic only in debug builds.
///
/// Release-path diagnostics are a privacy surface, not just noise. A Firebase
/// `PERMISSION_DENIED` message embeds the full resource path, which contains
/// the shop's Firebase UID; a full Dart stack trace contains build-time absolute
/// file paths. Both were written unconditionally with `debugPrint`, and both
/// reach Google: `main.dart` wires `FirebaseCrashlytics.instance
/// .recordFlutterFatalError` and `setCrashlyticsCollectionEnabled(true)`
/// without a `kDebugMode` guard, so every one of these lines was uploaded to
/// Crashlytics on every crash, for every user.
///
/// Crash reports are still worth having in release - that is the point of
/// Crashlytics. What is not worth having is the *payload*: the message text.
/// Use [logSecureError] for anything that must survive to production, and
/// redact identifiers there rather than silencing the whole report.
///
/// [message] is only built when the guard passes, so callers can pass an
/// interpolated string without paying for it in release.
void logDiagnostic(String message, {String tag = 'app'}) {
  if (kDebugMode) debugPrint('[$tag] $message');
}

/// As [logDiagnostic], but attaches a [StackTrace].
///
/// The stack is the most sensitive part: it carries absolute build paths, and
/// in release it was being written verbatim to both logcat and Crashlytics.
void logDiagnosticWithStack(String message, StackTrace? stack,
    {String tag = 'app'}) {
  if (kDebugMode) {
    debugPrint('[$tag] $message');
    if (stack != null) debugPrint('[$tag] $stack');
  }
}

/// Maps a raw exception onto a message that is safe to show a user, and logs the
/// original for Crashlytics.
String sanitizeErrorMessage(Object error,
    {String fallback = 'Something went wrong. Please try again.'}) {
  final msg = error.toString();

  final safeMessages = [
    'Insufficient stock',
    'Product not found',
    'Sale not found',
    'User not authenticated',
    'Sale amount must be positive',
    'Paid amount cannot be negative',
    'Add at least one product',
    'Select a customer',
    'Restock quantity must be positive',
    'Unit cost must be positive',
    'Enter a positive amount',
    'Amount exceeds outstanding balance',
    'Cannot exceed',
  ];

  for (final safe in safeMessages) {
    if (msg.contains(safe)) return msg;
  }

  if (msg.contains('Firebase') ||
      msg.contains('PlatformException') ||
      msg.contains('firestore')) {
    developer.log('[SafeError] Firebase error masked: ${redactForLog(msg)}',
        name: 'security');
    return fallback;
  }

  // Null-safety faults. The parenthesisation here is explicit because the
  // original read `a || b && c`, which Dart evaluates as `a || (b && c)` — and
  // the `b && c` clause tested for the *substrings* "type" and "null" anywhere
  // in the message. That is far too broad to be a null-safety test: any error
  // whose text happened to contain both words was silently replaced with a
  // generic message, hiding the actual cause from the log as well as the user.
  // Match the real fault signatures instead.
  final isNullSafetyFault = msg.contains('Null check operator') ||
      msg.contains('is not a subtype of') ||
      msg.contains('_TypeError') ||
      msg.contains('LateInitializationError') ||
      msg.contains('was called before being initialized') ||
      msg.contains('Null check operator used on a null value');
  if (isNullSafetyFault) {
    developer.log('[SafeError] Null safety error masked: ${redactForLog(msg)}',
        name: 'security');
    return fallback;
  }

  return msg;
}

/// Redacts identifiers from a message before it is written to a log sink.
///
/// `logSecureError` is the app's primary logging sink, and Crashlytics is wired
/// to it unconditionally in `main.dart`. Logged verbatim, a Firestore
/// PERMISSION_DENIED message carries the full document path, which means the
/// user's Firebase UID:
///
///   Missing or insufficient permissions at: /users/K7zGP2DC1ccBVtAWiRzSwMUD0Pv1/customers/abc123
///
/// That makes Crashlytics a durable store of UIDs, document paths and - for the
/// call sites that interpolate business data - product names and file paths,
/// retained under Google's policy. A UID is a stable per-person identifier, so
/// for an app holding customer names and phone numbers that is a privacy
/// surface, not just noise.
///
/// The diagnostic value is preserved: the *shape* of the failure still reaches
/// the log, and the stack trace is unaffected.
final _uidPathRe = RegExp(r'/users/[A-Za-z0-9_-]{20,}');

/// A bare id token, matched with a word boundary on each side.
///
/// 20 is the length of the ids this app actually mints - `generateId()` calls
/// `_db.collection('_ids').doc().id`, which is a 20-character base-62 auto-ID,
/// and a Firebase UID is 28. Setting the floor at the SHORTEST id we can
/// produce is what makes the guarantee hold: a threshold above 20 would let
/// every auto-ID this app mints through untouched.
///
/// A word boundary on each side is what keeps ordinary diagnostics readable.
/// Money, quantities and the words of a product name are all separated by
/// spaces or punctuation and so are not matched; what this catches is
/// unbroken random-looking tokens, which is exactly what a generated id looks
/// like. The trade-off is a single unbroken word longer than 20 characters also
/// being redacted, which errs toward privacy and costs only legibility.
final _bareIdRe = RegExp(r'\b[A-Za-z0-9_-]{20,}\b');

String redactForLog(String message) => message
    // Full `users/{uid}/...` paths, including any subcollection beneath.
    .replaceAll(_uidPathRe, '/users/<uid>')
    .replaceAll(_bareIdRe, '<id>');

void logSecureError(Object error, StackTrace? stack,
    {String tag = 'security'}) {
  developer.log(
    '[ERROR][$tag] ${redactForLog(error.toString())}',
    stackTrace: stack,
    name: tag,
  );
}
