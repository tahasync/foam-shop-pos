import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/services/update_checker.dart';

/// Guards the pasted GitHub release body for v1.5.5.
///
/// The update dialog shows `formatChangelog(release.body)`, so the notes only
/// render as clean prose if the body is written the way that parser expects.
/// This is a formatting guard, not a test of the parser: it fails if someone
/// edits RELEASE_NOTES_v1.5.5.md into a form that would print raw Markdown or
/// break sentences mid-clause in a 280dp dialog.
///
/// The maintainer-facing block at the end of the file is fenced OUT of the
/// release body below, which is the block actually pasted into GitHub.
void main() {
  // The body is read inside each test rather than at `main()` scope. Reading it
  // during the test-declaration phase throws `OutsideTestException`, because
  // `expect` is not yet available to the test runner.
  String readBody() {
    final raw = File('RELEASE_NOTES_v1.5.5.md').readAsStringSync();
    const start = '<!-- RELEASE BODY START -->';
    const end = '<!-- RELEASE BODY END -->';
    expect(raw, contains(start), reason: 'Missing the start marker.');
    expect(raw, contains(end), reason: 'Missing the end marker.');
    final from = raw.indexOf(start) + start.length;
    return raw.substring(from, raw.indexOf(end)).trim();
  }

  test('the fenced block is the release body', () {
    final body = readBody();
    expect(body, contains('### Fixed'),
        reason: 'The parser keeps headings but strips the hashes, so the body '
            'must use GitHub heading syntax.');
    expect(body, isNot(contains('Release body for')),
        reason: 'The explanatory header must stay outside the fenced block or '
            'it would be published as release notes.');
  });

  test('the notes render without raw Markdown', () {
    final out = formatChangelog(readBody());
    expect(out, isNot(contains('###')),
        reason: 'Headings must not print their hash characters.');
    expect(out, isNot(contains('**')),
        reason: 'Bold markers must not survive into the dialog.');
    expect(out, isNot(contains('---')),
        reason: 'Horizontal rules are not notes and must not be shown.');
  });

  test('hard wraps are unwrapped so sentences stay whole', () {
    final out = formatChangelog(readBody());
    expect(out, contains('FIXED'),
        reason: 'Section headings are kept and uppercased: "Fixed" carries '
            'meaning a flat list would lose.');
    // A sentence split across the hard wrap must rejoin.
    expect(out, contains('choked on a record missing a field'),
        reason: 'The bullet body should be one continuous run of text.');
    expect(out, isNot(contains('missing a\nfield')),
        reason: 'A preserved newline mid-sentence splits the sentence in the '
            'dialog.');
  });

  test('both user-facing fixes are described', () {
    final out = formatChangelog(readBody()).toLowerCase();
    expect(out, contains('sales history'),
        reason: 'The data-loss fix is the reason to ship this release.');
    expect(out, contains('sales screen'),
        reason: 'The empty product list is the other half of the release.');
  });
}
