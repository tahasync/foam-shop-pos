import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression test for the empty product list on the sales screen.
///
/// `_filteredProducts` returned `[]` for an empty query, and the result list was
/// gated on `_searchCtrl.text.isNotEmpty`, so on a first run the entire area
/// between the search field and the cart rendered blank. A new cashier saw no
/// product to tap and no instruction to type; the screen read as broken rather
/// than as "search for something".
///
/// Browsing the catalogue is the default now, with search narrowing it. The
/// second half of the fix is the no-match case, which rendered an empty bordered
/// box indistinguishable from a still-loading list.
///
/// Asserted at the source level because `_filteredProducts` is private to the
/// screen's State and the screen pulls live products from Firestore, which a
/// widget test cannot provide.
void main() {
  final source = File('lib/screens/sales_entry_screen.dart').readAsStringSync();

  group('empty query must browse, not blank out', () {
    test('an empty query returns the catalogue rather than nothing', () {
      final start = source.indexOf('List<Product> _filteredProducts');
      expect(start, greaterThan(-1),
          reason: '_filteredProducts must still exist - test is stale.');
      final body = source.substring(start, start + 400);

      expect(body, isNot(contains('if (q.isEmpty) return []')),
          reason: 'Returning [] for an empty query is the exact bug: the '
              'search field then has nothing to show and no way to recover '
              'except typing, which the UI never told the user to do.');
      expect(body, contains('if (q.isEmpty) return products'),
          reason: 'The empty query should be the WIDEST one - it shows '
              'everything and lets search narrow it.');
    });

    test('the result list is not gated on a non-empty query alone', () {
      expect(source, isNot(contains('if (_searchCtrl.text.isNotEmpty)')),
          reason: 'Gating the list on a typed query is what kept the area '
              'blank on a first run. It must open for browsing too.');
      expect(source, contains('if (_showsProductList(salesState))'),
          reason: 'The list should be shown whenever a query is typed OR there '
              'are no recent chips to occupy the space. The gate must pass the '
              'watched state, not read the provider.');
    });

    test('recent chips and the browse list do not both fill the gap', () {
      expect(source, contains('recentProductIds.isEmpty'),
          reason: 'With no query the browse list only opens when there are no '
              'recent chips, so the chips are not buried under a full '
              'catalogue list.');
    });

    test('a query matching nothing says so', () {
      expect(source, contains('No product matches'),
          reason: 'A no-match query must be distinguishable from a loading '
              'list; an empty bordered box explains nothing.');
    });
  });

  group('browsing must not eagerly build the whole catalogue', () {
    test('an untyped browse is capped', () {
      expect(source, contains('kBrowseRowCap'),
          reason: 'The screen is a ListView built from children:, so every row '
              'is constructed eagerly each frame. Showing the whole catalogue '
              'by default makes typing into the search field slow on a shop '
              'with many products.');
      expect(source, contains('matches.take(kBrowseRowCap)'),
          reason: 'The cap must actually truncate the rows that get built.');
    });

    test('a typed query is never truncated', () {
      final start = source.indexOf('List<Product> _visibleProducts');
      expect(start, greaterThan(-1), reason: '_visibleProducts must exist.');
      final body = source.substring(start, start + 500);

      final capAt = body.indexOf('kBrowseRowCap');
      expect(capAt, greaterThan(-1), reason: 'The cap must be in this method.');

      final earlyReturn = body.indexOf('return matches;');
      expect(earlyReturn, greaterThan(-1));
      expect(earlyReturn, lessThan(capAt),
          reason: 'A typed query must return its matches untouched. Capping '
              'them too would hide the very product the user searched for, '
              're-creating the "my product vanished" problem.');
    });

    test('the cap is disclosed rather than silent', () {
      expect(source, contains('Showing \${visible.length} of \$total products'),
          reason: 'A silent cap makes a stocked shop look like it only has 8 '
              'products. State what is hidden and how to reveal it.');
    });

    test('the row count is computed once per build', () {
      final start = source.indexOf('data: (products) {');
      expect(start, greaterThan(-1),
          reason: 'The data branch must be a block '
              'so the filter can be computed once.');
      final body = source.substring(start, start + 400);
      expect(body, contains('final visible = _visibleProducts(products)'),
          reason: 'The visible rows and the total must be derived once and '
              'reused, not recomputed inline per row.');
    });
  });

  group('the list must react to recent chips appearing', () {
    test('the gate takes the state instead of reading the provider', () {
      expect(source, isNot(contains('bool get _showsProductList')),
          reason: 'A getter that calls ref.read does not subscribe, so the '
              'list would not reopen when a recent chip appears until some '
              'unrelated rebuild.');
      expect(source, contains('bool _showsProductList(SalesState salesState)'),
          reason: 'Passing the already-watched state keeps the gate reactive '
              'without a second subscription.');
    });
  });

  group('highlighting must survive the empty query', () {
    test('an empty query does not highlight at index 0', () {
      expect(source, contains('q.isEmpty ? -1'),
          reason: "indexOf('') returns 0, so an unguarded empty query paints a "
              'zero-width highlight span at the start of every product name.');
    });

    test('the query is trimmed consistently', () {
      // `.trim()` was added to the filter and the index lookup together. A
      // query of only spaces is a real case: it is non-empty as a string but
      // matches nothing, which would blank the list the user is looking at.
      final start = source.indexOf('List<Product> _filteredProducts');
      final filter = source.substring(start, start + 300);
      expect(filter, contains('trim()'),
          reason: 'A whitespace-only query must behave like an empty one.');

      // Both the filter and the highlighter derive `q` from the same field, so
      // both have to trim. A query of only spaces is a real case: non-empty as
      // a string, but matching nothing, which would blank the visible list.
      //
      // Asserted on EVERY assignment of `q` rather than on the two known sites,
      // so a third site added later cannot quietly skip the trim.
      final assignments = RegExp(r'final q = _searchCtrl\.text[^\n]*;')
          .allMatches(source)
          .map((m) => m.group(0)!)
          .toList();
      expect(assignments, hasLength(2),
          reason: 'Expected the filter and the highlighter each to read the '
              'query. Found ${assignments.length}.');

      for (final line in assignments) {
        expect(line, contains('trim()'),
            reason: 'Filter and highlight must trim identically, or a padded '
                'query highlights a substring the filter did not match: '
                '"$line"');
      }
    });
  });
}
