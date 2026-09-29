import 'package:flutter_test/flutter_test.dart';

import 'package:foam_shop_register/utils/safe_error_handler.dart';

void main() {
  group('log redaction', () {
    // A real Firestore PERMISSION_DENIED string. Unredacted, this is a durable
    // record of the user's Firebase UID in Crashlytics, which is wired to
    // collect logs unconditionally in main.dart.
    const denied = 'Error 7: PERMISSION_DENIED: Missing or insufficient '
        'permissions at: /users/K7zGP2DC1ccBVtAWiRzSwMUD0Pv1/customers/abc123';

    test('strips the Firebase UID out of a Firestore error path', () {
      final redacted = redactForLog(denied);
      expect(redacted, isNot(contains('K7zGP2DC1ccBVtAWiRzSwMUD0Pv1')),
          reason: 'The UID must never reach a log sink.');
      expect(redacted, contains('/users/<uid>'),
          reason: 'Redaction should be legible, not just destructive: the path '
              'shape is what makes the log useful.');
      // The diagnostic value must survive.
      expect(redacted, contains('PERMISSION_DENIED'));
      expect(redacted, contains('customers'));
    });

    test('strips a bare Firestore auto-ID', () {
      // `_db.collection('_ids').doc().id` produces a 20-character base-62
      // auto-ID. That is the exact length of the shortest id this app mints,
      // so it is the shortest token redaction must catch.
      const autoId = 'K7zGP2DC1ccBVtAWiRzS';
      expect(autoId.length, 20,
          reason: 'Firestore auto-IDs are 20 characters; guard the fixture '
              'itself so it cannot silently drift away from the real format.');
      expect(
          redactForLog('Sale failed for doc $autoId'), isNot(contains(autoId)));
    });

    test('leaves ordinary diagnostics readable', () {
      // Redaction must not eat the message that makes a log useful.
      const msg = 'Sale blocked: cart products not found in inventory';
      expect(redactForLog(msg), msg);
      expect(redactForLog('Insufficient stock'), 'Insufficient stock');
    });

    test('does not mangle short numbers or currency', () {
      // Money and quantities are the thing we most need to see in a log, and
      // they must survive. This is the regression that would make the
      // redaction too aggressive to keep.
      expect(redactForLog('Restocked 2500 units at Rs 1234.50'),
          'Restocked 2500 units at Rs 1234.50');
    });
  });
}
