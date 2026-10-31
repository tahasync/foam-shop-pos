import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/services/update_checker.dart';

void main() {
  String readChangelogSection() {
    final raw = File('CHANGELOG.md').readAsStringSync();
    const heading = '## v1.5.7';
    final start = raw.indexOf(heading);
    expect(start, greaterThanOrEqualTo(0));
    final headingEnd = raw.indexOf('\n', start);
    final next = raw.indexOf('\n## ', start + heading.length);
    return raw.substring(headingEnd + 1, next < 0 ? raw.length : next);
  }

  test('v1.5.7 release notes contain the customer-facing fix sections', () {
    final body = readChangelogSection();
    expect(body, contains('### Improved'));
    expect(body, contains('### Fixed'));
    expect(body, isNot(contains('Maintainer details')));
  });

  test('v1.5.7 notes render cleanly in the update dialog', () {
    final formatted = formatChangelog(readChangelogSection());
    expect(formatted, contains('IMPROVED'));
    expect(formatted, contains('FIXED'));
    expect(formatted, isNot(contains('###')));
    expect(formatted, isNot(contains('**')));
    expect(formatted, isNot(contains('—')));
  });

  test('release notes explain that CSV exports share as files', () {
    final formatted = formatChangelog(readChangelogSection()).toLowerCase();
    expect(formatted, contains('complete csv'));
    expect(formatted, contains('sales detail'));
    expect(formatted, contains('share sheet'));
  });

  test('release notes describe the updated receipt branding', () {
    final formatted = formatChangelog(readChangelogSection()).toLowerCase();
    expect(formatted, contains('foam layers mark'));
    expect(formatted, contains('printed receipt'));
    expect(formatted, contains('periwinkle'));
  });

  test('the release tag, app version, and changelog heading agree', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 1.5.7+10'));
    expect(readChangelogSection(), isNotEmpty);
  });
}
