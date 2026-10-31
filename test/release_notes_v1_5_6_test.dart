import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/services/update_checker.dart';

void main() {
  String readBody() {
    final raw = File('RELEASE_NOTES_v1.5.6.md').readAsStringSync();
    const start = '<!-- RELEASE BODY START -->';
    const end = '<!-- RELEASE BODY END -->';
    expect(raw, contains(start));
    expect(raw, contains(end));
    return raw.substring(raw.indexOf(start) + start.length, raw.indexOf(end));
  }

  String readChangelogSection() {
    final raw = File('CHANGELOG.md').readAsStringSync();
    const heading = '## v1.5.6';
    final start = raw.indexOf(heading);
    expect(start, greaterThanOrEqualTo(0));
    final headingEnd = raw.indexOf('\n', start);
    final next = raw.indexOf('\n## ', start + heading.length);
    return raw.substring(
      headingEnd + 1,
      next < 0 ? raw.length : next,
    );
  }

  test('release body is fenced and contains the expected sections', () {
    final body = readBody();
    expect(body, contains('### Improved'));
    expect(body, contains('### Fixed'));
    expect(body, isNot(contains('Maintainer details')));
  });

  test('release notes render as plain text in the update dialog', () {
    final formatted = formatChangelog(readBody());
    expect(formatted, contains('IMPROVED'));
    expect(formatted, contains('FIXED'));
    expect(formatted, isNot(contains('###')));
    expect(formatted, isNot(contains('**')));
  });

  test('hard-wrapped lines rejoin into complete sentences', () {
    final formatted = formatChangelog(readBody());
    expect(formatted, contains('Foam Shop has a new, consistent brand.'));
    expect(formatted, isNot(contains('a new,\nconsistent brand')));
  });

  test('the user-facing brand, export, and Spark fixes are included', () {
    final formatted = formatChangelog(readBody()).toLowerCase();
    expect(formatted, contains('printed receipt'));
    expect(formatted, contains('xlsx'));
    expect(formatted, contains('spark plan'));
  });

  test('the tagged changelog section also formats cleanly for the dialog', () {
    final formatted = formatChangelog(readChangelogSection());
    expect(formatted, contains('IMPROVED'));
    expect(formatted, contains('FIXED'));
    expect(formatted, contains('sale cannot be reclassified as a quote'));
    expect(formatted, isNot(contains('**')));
    expect(formatted, isNot(contains('—')));
  });
}
