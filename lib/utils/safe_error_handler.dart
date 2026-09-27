import 'dart:developer' as developer;

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
    developer.log('[SafeError] Firebase error masked: $msg', name: 'security');
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
    developer.log('[SafeError] Null safety error masked: $msg',
        name: 'security');
    return fallback;
  }

  return msg;
}

void logSecureError(Object error, StackTrace? stack,
    {String tag = 'security'}) {
  developer.log(
    '[ERROR][$tag] ${error.toString()}',
    stackTrace: stack,
    name: tag,
  );
}
