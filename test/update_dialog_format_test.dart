import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/services/update_checker.dart';

/// `formatChangelog` feeds the "What's New" body of the update dialog, which is
/// the first time a shop owner sees what changed. Two defects were visible on a
/// real device, and neither is caught by just rendering the raw body:
///
///  - Markdown leaked into the text: `### Fixed` printed its hashes, list items
///    printed their `-`, and `` `paid` `` printed its backticks.
///  - CHANGELOG.md is hard-wrapped at ~80 columns, and those newlines were
///    preserved, so sentences broke mid-clause in the middle of a paragraph.
///
/// These tests pin the *output*, and use the real v1.5.4 release body rather
/// than a synthetic string, so a future change to how CHANGELOG.md is written
/// cannot quietly reintroduce either defect.
void main() {
  group('formatChangelog — markup never reaches the dialog', () {
    test('strips heading hashes', () {
      final out = formatChangelog('### Fixed\n- Something broke');
      expect(out, isNot(contains('#')));
      expect(out, contains('FIXED'));
    });

    test('replaces list markers with a bullet', () {
      final out = formatChangelog('### Fixed\n- Cash was overstated');
      expect(out, isNot(contains('- Cash')));
      expect(out, contains('• Cash was overstated'));
    });

    test('strips bold and inline-code delimiters', () {
      final out = formatChangelog(
          '- Read `netCashReceived` and **exclude** the rest. See *the* note.');
      expect(out, isNot(contains('`')));
      expect(out, isNot(contains('**')));
      expect(out, isNot(contains('*the*')));
      expect(out, contains('Read netCashReceived and exclude the rest.'));
    });

    test('strips markdown links down to their label', () {
      final out = formatChangelog('- See [the notes](https://example.com/x).');
      expect(out, isNot(contains('https://')));
      expect(out, isNot(contains('](')));
      expect(out, contains('See the notes.'));
    });

    test('drops the Full Changelog trailer and bare URLs', () {
      final out = formatChangelog(
          '- Fixed a bug.\n\n**Full Changelog**: https://github.com/a/b/compare/v1..v2');
      expect(out, isNot(contains('Full Changelog')));
      expect(out, isNot(contains('github.com')));
    });
  });

  group('formatChangelog — hard-wrapped source is unwrapped', () {
    test('re-joins a bullet broken across lines', () {
      // Exactly the shape CHANGELOG.md produces at 80 columns.
      const wrapped =
          '- **Overpayment was banked as revenue.** When a customer\n'
          '  hands over more than the total, the surplus was added to the\n'
          '  amount received.';
      final out = formatChangelog(wrapped);

      // One bullet, one line: the sentence is contiguous again.
      expect(
          out,
          contains('more than the total, the surplus was added to the '
              'amount received.'));
    });

    test('re-joins a paragraph broken across lines', () {
      const wrapped = 'Two accounting bugs that misstated a shop\'s money,\n'
          'plus the CI gate that keeps source formatting from drifting.';
      final out = formatChangelog(wrapped);
      expect(
        out,
        'Two accounting bugs that misstated a shop\'s money, plus the CI gate '
        'that keeps source formatting from drifting.',
      );
    });

    test('normalizes CRLF input', () {
      final out = formatChangelog('### Fixed\r\n- A bug\r\n  was fixed.');
      expect(out, contains('FIXED'));
      expect(out, contains('• A bug was fixed.'));
      expect(out, isNot(contains('\r')));
    });

    test('keeps real paragraph breaks', () {
      final out =
          formatChangelog('First para line one.\nFirst para line two.\n\n'
              'Second para.');
      expect(out, 'First para line one. First para line two.\n\nSecond para.');
    });
  });

  group('formatChangelog — structure', () {
    test('a heading separates blocks with a blank line', () {
      final out = formatChangelog('### Fixed\n- One\n\n### Added\n- Two');
      expect(out, 'FIXED\n\n• One\n\nADDED\n\n• Two');
    });

    test('a paragraph after a blank line is not absorbed into the bullet', () {
      final out = formatChangelog('- A bullet\n\nA separate paragraph.');
      expect(out, '• A bullet\n\nA separate paragraph.');
    });

    test('empty and whitespace-only input gets a real message', () {
      const fallback = 'No changelog available for this release.';
      expect(formatChangelog(''), fallback);
      expect(formatChangelog('   \n\n  '), fallback);
    });

    test('input that is only markup and URLs gets the fallback', () {
      expect(
        formatChangelog(
            '**Full Changelog**: https://github.com/a/b/compare/1..2'),
        'No changelog available for this release.',
      );
    });
  });

  group('formatChangelog — the real v1.5.4 release body', () {
    // Verbatim from the published GitHub Release, which is the section the
    // workflow extracts from CHANGELOG.md.
    const v154 = '''
Two accounting bugs that misstated a shop's money, plus the CI gate that keeps
source formatting from drifting.

### Fixed
- **Overpayment was banked as revenue and sat in the till.** When a customer hands
  over more than the total, the surplus was added to the amount received, so the
  change owed back was counted as cash the shop had kept *and* was added to
  revenue. Every figure that reads the gross `paid` now reads
  `netCashReceived`, and overpayment is surfaced separately as `changeDue` in
  `Sale`.
- **Voiding a sale failed on real Firestore and never restored stock.** The void
  transaction performed its product reads *after* its first write. All
  product reads now happen before any write.
''';

    test('contains no markdown delimiters anywhere', () {
      final out = formatChangelog(v154);
      for (final forbidden in ['#', '**', '`', '](']) {
        expect(out, isNot(contains(forbidden)),
            reason: 'leaked "$forbidden" into the dialog body');
      }
    });

    test('preserves both the section and both bullets', () {
      final out = formatChangelog(v154);
      expect(out, contains('FIXED'));
      expect(out, contains('• Overpayment was banked as revenue'));
      expect(out, contains('• Voiding a sale failed on real Firestore'));
    });

    test('the till sentence is contiguous, not split mid-clause', () {
      final out = formatChangelog(v154);
      expect(
          out,
          contains('the change owed back was counted as cash the shop '
              'had kept and was added to revenue.'));
    });

    test('each bullet renders as exactly one line', () {
      final out = formatChangelog(v154);
      final bullets = out.split('\n').where((l) => l.startsWith('• ')).toList();
      expect(bullets, hasLength(2));
      for (final bullet in bullets) {
        // A hard-wrapped bullet would leave a stray 2-space indent behind.
        expect(bullet, isNot(contains('  ')));
      }
    });
  });

  group('formatChangelog — against the real CHANGELOG.md', () {
    // The copy above can drift from the file. This reads the actual section for
    // the tag, exactly as the release workflow does, so the formatter is proven
    // against the text that will really be published.
    test('the v1.5.4 section produces clean, unwrapped output', () {
      final file = File('CHANGELOG.md');
      expect(file.existsSync(), isTrue,
          reason: 'CHANGELOG.md must exist at the repo root');

      final text = file.readAsStringSync();
      // Match the workflow's own extraction: the `## v1.5.4` line itself is
      // skipped, and the section runs to the next `## ` heading.
      final heading =
          RegExp(r'^## v1\.5\.4.*$', multiLine: true).firstMatch(text);
      expect(heading, isNotNull, reason: 'no v1.5.4 section in CHANGELOG.md');

      final rest = text.substring(heading!.end);
      final next = rest.indexOf(RegExp(r'^## ', multiLine: true));
      final section = next == -1 ? rest : rest.substring(0, next);

      final out = formatChangelog(section);

      // No markup of any kind survives.
      for (final forbidden in ['#', '**', '`', '](', 'http']) {
        expect(out, isNot(contains(forbidden)),
            reason: 'leaked "$forbidden" into the dialog body');
      }

      // Every line is either a heading, a bullet, a paragraph, or blank — and
      // no line retains a hard-wrap indent, which is the wrapping defect.
      for (final line in out.split('\n')) {
        if (line.trim().isEmpty) continue;
        expect(line, isNot(startsWith(' ')),
            reason: 'line still carries a hard-wrap indent: "$line"');
        expect(line, isNot(endsWith(',')),
            reason: 'line was split mid-sentence: "$line"');
      }

      // Sanity: the content is actually there, not stripped away.
      expect(out, contains('FIXED'));
      expect(out, contains('CHANGE'));
      expect(out.length, greaterThan(400));
    });
  });
}
