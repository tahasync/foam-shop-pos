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

  // These assert the masking behaviour of `sanitizeErrorMessage`, which decides
  // what a shopkeeper actually reads when a write fails. Two failure modes
  // matter and they pull in opposite directions:
  //
  //   * showing a raw Firebase error leaks the document path, i.e. the shop's
  //     UID, into the UI;
  //   * masking too eagerly destroys the app's OWN validation messages, which
  //     are the ones that tell the user what to fix ("Insufficient stock").
  //
  // `ui_regression_test.dart` covers the pass-through and the two mask classes.
  // What is asserted here is the interaction between them and the redaction
  // path, which is the part most likely to regress silently.
  group('error sanitisation', () {
    test('passes the app\'s own validation messages through unchanged', () {
      // These are deliberately NOT masked. They carry no internal detail and
      // they are the difference between an actionable message and "something
      // went wrong".
      for (final message in const [
        'Insufficient stock',
        'Product not found',
        'Sale not found',
        'Select a customer',
        'Enter a positive amount',
        'Cannot exceed the outstanding balance',
      ]) {
        expect(
          sanitizeErrorMessage(Exception(message)),
          'Exception: $message',
          reason: '"$message" is the app\'s own guidance and must reach the '
              'user verbatim. Masking it turns an actionable error into a '
              'dead end.',
        );
      }
    });

    test('masks a Firebase error behind the fallback, not the raw text', () {
      // The raw form embeds `/users/{uid}/...`, so returning it would put the
      // shop's UID on screen.
      final raw = Exception('[firebase_firestore/failed-precondition] '
          'permission denied at /users/K7zGP2DC1ccBVtAWiRzSwMUD0Pv1/sales/abc');
      final shown = sanitizeErrorMessage(raw);
      expect(shown, 'Something went wrong. Please try again.');
      expect(shown, isNot(contains('K7zGP2DC1ccBVtAWiRzSwMUD0Pv1')),
          reason: 'A UID must never be rendered to the user.');
    });

    test('honours a custom fallback', () {
      expect(
        sanitizeErrorMessage(
          // The shape a real FirestoreException stringifies to. The prefix
          // matters: the mask keys on the `firestore` / `Firebase` /
          // `PlatformException` markers, so a fixture lacking one is not a
          // Firebase error and is correctly passed through instead.
          Exception('[firebase_firestore/unavailable] '
              'The service is currently unavailable.'),
          fallback: 'Could not save the sale. Please try again.',
        ),
        'Could not save the sale. Please try again.',
        reason:
            'Callers supply a message that names the action that failed, so '
            'the fallback must be substitutable rather than hard-coded.',
      );
    });

    test('masks a genuine null-safety fault', () {
      for (final raw in const [
        'Null check operator used on a null value',
        "type 'String' is not a subtype of type 'int'",
        'LateInitializationError: field _controller',
        'The widget was called before being initialized',
      ]) {
        expect(
          sanitizeErrorMessage(Exception(raw)),
          'Something went wrong. Please try again.',
          reason:
              'A null-safety fault is an internal bug and must not be shown '
              'to a shopkeeper as if it were their problem. Input: $raw',
        );
      }
    });

    test('does not mask an unrelated error for containing both words', () {
      // This is the over-broad-guard regression. The original condition was
      // `contains('type') && contains('null')`, which matched the mere presence
      // of those two words ANYWHERE in the message. Real operational messages
      // hit that constantly, so the true cause was swapped for a generic
      // string - the log lost the only useful information it had.
      const real = 'Could not resolve type size for the null terminator table';
      expect(
        sanitizeErrorMessage(Exception(real)),
        'Exception: $real',
        reason: 'The null-safety guard must key on real fault signatures, not '
            'on unrelated words appearing together.',
      );
    });

    test('redacts a UID even when the error is returned rather than logged',
        () {
      // Belt and braces. `sanitizeErrorMessage` returns the fallback for a
      // Firebase error, so the UID is already gone from the RETURNED value; the
      // redaction is what protects the internal log it writes on the way past.
      // Asserting both sides keeps the two mechanisms from being conflated by
      // a future refactor that routes one through the other.
      const raw = '[firebase_firestore/permission-denied] PERMISSION_DENIED at '
          '/users/K7zGP2DC1ccBVtAWiRzSwMUD0Pv1/customers/x';
      expect(sanitizeErrorMessage(Exception(raw)),
          isNot(contains('K7zGP2DC1ccBVtAWiRzSwMUD0Pv1')));
      expect(
          redactForLog(raw), isNot(contains('K7zGP2DC1ccBVtAWiRzSwMUD0Pv1')));
    });
  });
}
