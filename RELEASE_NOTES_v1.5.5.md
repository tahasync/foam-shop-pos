# Release body for v1.5.5

Paste the block between the two marker comments into the GitHub release body when
you publish v1.5.5. The in-app "What's New" dialog reads the **GitHub release
body** (not `CHANGELOG.md`), so these notes only reach shopkeepers once the
release exists.

The formatting below is deliberate: `formatChangelog` in
`lib/services/update_checker.dart` strips headings, bullets, bold and inline
code, and unwraps continuation lines, so the dialog renders it as plain text
rather than raw Markdown. Headings are uppercased on purpose — "Fixed" carries
meaning that a flat list would lose.

<!-- RELEASE BODY START -->

### Fixed

- **One bad sale record could hide your whole sales history.** Reading a sale
  choked on a record missing a field, and the app showed no sales, no revenue
  and no profit — on the billing screen, the dashboard, reports, exports and
  the khata ledger, all at once, with nothing on screen to say why. A malformed
  record now costs only itself, and it is logged so it can be found and fixed.

- **The sales screen looked empty until you typed.** On a first sale the area
  between the search box and the cart showed nothing, so it read as a broken
  screen. Your products are now listed straight away, and searching narrows
  them down. A search that matches nothing now says so instead of showing a
  blank box.

<!-- RELEASE BODY END -->

### Details for whoever maintains this

- `lib/models/sale.dart` — `fromMap` no longer hard-casts `id`, `date`,
  `customer_id` or `paid`, and the legacy flat-schema branch no longer divides
  `amount / qty_or_area` unguarded. A missing `paid` falls back to the bill the
  lines add up to, never to zero, which would have invented a phantom unpaid
  balance.
- `lib/providers/sale_provider.dart` — documents are parsed individually, so an
  unreadable row cannot propagate out of the provider. Skipped rows are logged
  with their id.
- `lib/screens/sales_entry_screen.dart` — browsing is the default, capped at 8
  rows with the cap disclosed, because the screen builds rows eagerly. The list
  gate takes the watched state rather than `ref.read`-ing the provider.
- The one legacy flat-schema record still in production
  (`wmejhdrF7cP21GLT9IRB`) was backfilled to the modern `line_items` schema, so
  the fallback path now has no live data behind it.
- 311 tests pass; `flutter analyze` and the `dart format` gate are clean.
