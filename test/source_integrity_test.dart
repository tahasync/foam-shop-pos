import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against a class of defect that unit/widget tests cannot catch:
/// UTF-8 punctuation in Dart source literals being silently corrupted into
/// U+003F '?' replacement characters.
///
/// This actually shipped: the product search row in `sales_entry_screen.dart`
/// rendered `78in ? 72in ? 6in ? 15 in stock` on a real device, because the
/// `×` (U+00D7) and `·` (U+00B7) separators had been written as literal '?'
/// bytes. Nothing failed `flutter analyze` and no host test covered the string,
/// so it was only caught by looking at a screenshot of a physical phone.
///
/// The check is deliberately source-level rather than widget-level: the
/// corrupted text sits inside a private build method, so asserting on rendered
/// output would mean standing up the whole sales screen plus a Product.
void main() {
  group('Source integrity — no corrupted punctuation in user-facing text', () {
    // A '?' that is a Dart ternary or null-aware operator is legitimate, so
    // only flag '?' characters sitting *between* literal text — the shape a
    // mangled separator takes: "78in ? 72in" rather than "x ? y : z".
    final separator = RegExp(r'[A-Za-z0-9)}\]]\s\?\s[A-Za-z0-9$]');

    test('no Dart file under lib/ contains a " ? " separator in code', () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trim().startsWith('//')) continue;
          if (!separator.hasMatch(line)) continue;
          // Reject a genuine ternary: it always has a matching ':' branch.
          if (line.contains(':')) continue;

          offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Found " ? " where a punctuation separator (e.g. \\u00d7 ×, '
            '\\u00b7 ·, \\u2014 —) belongs. These render as "?" on device.\n'
            '${offenders.join('\n')}',
      );
    });

    test('the product search row uses real multiplication and middot', () {
      final source =
          File('lib/screens/sales_entry_screen.dart').readAsStringSync();

      expect(
        source,
        contains(r'in \u00d7 ${p.sizeWidth'),
        reason: 'Search result dimensions must use the × escape (\\u00d7), not "?"',
      );
      expect(
        source,
        isNot(contains(r'in ? ${p.sizeWidth')),
        reason: 'The "?" separator regressed — it renders as "?" on device.',
      );
    });
  });
}
