import 'dart:developer' as developer;

class SafeError {
  final String userMessage;
  final String? diagnosticCode;

  const SafeError({required this.userMessage, this.diagnosticCode});

  @override
  String toString() => userMessage;
}

String sanitizeErrorMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
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

  if (msg.contains('Firebase') || msg.contains('PlatformException') || msg.contains('firestore')) {
    developer.log('[SafeError] Firebase error masked: $msg', name: 'security');
    return fallback;
  }

  if (msg.contains('Null check operator') || msg.contains('type') && msg.contains('null')) {
    developer.log('[SafeError] Null safety error masked: $msg', name: 'security');
    return fallback;
  }

  return msg;
}

void logSecureError(Object error, StackTrace? stack, {String tag = 'security'}) {
  developer.log(
    '[ERROR][$tag] ${error.toString()}',
    stackTrace: stack,
    name: tag,
  );
}