# Changelog

## v1.5.5 — 29 September 2026

One fix that could cost a shop its whole sales history, and one that made the
product picker look broken on a first run.

### Fixed
- **One malformed sale could hide a shop's entire sales history.** Reading a
  sale hard-cast `id`, `date`, `customer_id` and `paid`, and derived a legacy
  flat sale's unit price by dividing `amount` by `qty_or_area` with no guard.
  Any document missing one of those fields, or carrying a zero quantity, threw
  — and because the sales stream maps every document eagerly, the throw
  propagated straight out of the provider. That one provider feeds the billing
  list, the dashboard totals, Reports, CSV export and the Khata ledger, so a
  single unreadable archived row put every one of those screens into its error
  state: no sales, no revenue, no COGS, and nothing on screen to distinguish a
  corrupt row from an outage. This was reachable in production, which holds a
  live legacy flat-schema document with no `line_items` — the exact branch that
  divides. Every field now degrades instead of throwing, and the stream parses
  each document on its own so an unreadable row costs that row and nothing more,
  logged with its id so it can be found and repaired. A missing `paid` falls
  back to the bill the lines add up to rather than to zero, which would have
  invented a phantom unpaid balance. Covered by
  `test/sale_parse_resilience_test.dart` (19 tests), which pins the real
  production document as a fixture.
- **The sales screen showed no products until you typed.** The product list
  returned nothing for an empty query and the list itself was hidden until the
  search field had text in it, so on a first run the entire area between the
  search box and the cart rendered blank. A new cashier saw no product to tap and
  nothing saying to type; the screen read as broken rather than as waiting for
  input, and the only way out was a guess. Browsing the catalogue is the default
  now and search narrows it, so an empty query is the *widest* one. A query that
  matches nothing also says so, instead of rendering an empty bordered box that
  was indistinguishable from a still-loading list. The recent-products chips are
  unchanged and still take that space when they exist, so the two never fight
  for it. The query is trimmed before both filtering and highlighting, so a
  spaces-only query behaves like an empty one instead of blanking the list.
  Browsing is capped at 8 rows and says so, because the screen builds its rows
  eagerly and rendering a large catalogue on every keystroke would make the
  search field feel slow. Covered by
  `test/product_list_empty_state_test.dart` (11 tests).

## v1.5.4 — September 2026

Two accounting bugs that misstated a shop's money, plus the CI gate that keeps
source formatting from drifting.

### Fixed
- **Overpayment was banked as revenue and sat in the till.** When a customer hands
  over more than the total, the surplus was added to the amount received, so the
  change owed back was counted as cash the shop had kept *and* was added to
  revenue. On a Rs 39,000 sale paid with Rs 40,000, Cash in Hand read
  **Rs 62,500** instead of **Rs 61,500** Ã¢â‚¬â€ the till was overstated by exactly the
  Rs 1,000 in the shopkeeper's pocket as change, and daily revenue was inflated by
  the same amount. Every figure that reads the gross `paid` now reads
  `netCashReceived`, and overpayment is surfaced separately as `changeDue` in
  `Sale`. Change is deliberately **excluded** from Cash in Hand and from Revenue:
  it is the customer's money on its way out, not the shop's. The change figure
  now propagates to every surface that shows a sale Ã¢â‚¬â€ the receipt, the billing
  subtitles, the quick-payment chips, and the status badge, which reads
  **CHANGE** rather than Paid.
- **Voiding a sale failed on real Firestore and never restored stock.** The void
  transaction performed its product reads *after* its first write. Firestore
  rejects any read that follows a write inside a transaction, so the transaction
  aborted with `FAILED_PRECONDITION` every time Ã¢â‚¬â€ the dialog opened, the user
  confirmed, and nothing happened, leaving stock permanently deducted. All
  product reads now happen before any write. Voiding a cart containing the same
  product on two separate lines also had to aggregate them into a single stock
  adjustment, since Firestore cannot read a document twice in one transaction;
  without that, a duplicated line restored the wrong quantity.
- **The "What's New" dialog showed raw Markdown.** The release notes were handed
  to a `Text` widget unprocessed, so a shop owner saw section headings still
  carrying their hash marks, list items still carrying their leading dash, and the
  delimiters around inline code and bold text. Only the bold markers were
  stripped, and only globally, so a bullet's own marker survived. The notes are
  also hard-wrapped at ~80 columns for CHANGELOG.md, and those newlines were
  preserved, so sentences broke mid-clause in the middle of a paragraph.
  `formatChangelog` now strips headings, list markers, emphasis, inline code and
  links, and unwraps continuation lines back onto the bullet they belong to,
  keeping section headings uppercased because "Fixed" and "Added" carry meaning a
  flat list would lose. The changelog box also grew from a fixed 200px to a
  flexible height, so a one-line release no longer reserves a large empty area.
  Covered by `test/update_dialog_format_test.dart` (18 tests), which formats the
  real CHANGELOG.md v1.5.4 section so the behaviour is pinned against the text
  that actually ships.
- **The format gate failed on 72 of 94 files on every single run.** The check
  itself was wrong, not the code. `dart format` selects the code style from the
  project's *language version*, which it reads from
  `.dart_tool/package_config.json` Ã¢â‚¬â€ **not** from `pubspec.yaml` Ã¢â‚¬â€ and with no
  such file it falls back to the SDK's default. CI ran the check before
  `flutter pub get`, so there was no `package_config.json`, so the formatter
  used the Dart 3.7 *tall* style while this project declares `sdk: ">=3.4.0"`
  and therefore uses the *short* style. The two styles disagree on most files,
  so the gate reported 72 files as misformatted when not one of them was Ã¢â‚¬â€ and
  because the failure is a clean exit 1 with no other signal, it reads as "your
  code is badly formatted" rather than "this step is misconfigured". A developer
  running `flutter pub get` (the normal first step) never saw it, which is why
  it passed locally and failed only in CI. `flutter pub get` is now an explicit
  step ahead of the check, and the workflow comment records why the order
  matters. Verified against a clean `git archive` of HEAD Ã¢â‚¬â€ the same check that
  reported 72 changed now reports 0.

### Changed
- **`lib/` and `test/` reformatted to the Dart tall style** (94 files), under
  the project's declared language version (`sdk: ">=3.4.0"`, i.e. the short
  style). Formatting-only Ã¢â‚¬â€ no behavioural change.

### Added
- **CI now fails the build on an unformatted file.** A formatting slip would
  otherwise land silently and reformat the whole tree in a later commit, burying
  real changes in noise. The gate is `dart format --output=none
  --set-exit-if-changed lib test`, and it runs only after an explicit
  `flutter pub get` step Ã¢â‚¬â€ that ordering is load-bearing, see *Fixed* above.
- **Four CI actions were running on a deprecated Node.js 20 runtime.** GitHub is
  force-running them on Node 24, and `actions/setup-java@v4` is additionally
  marked as no longer receiving updates. Bumped to `actions/checkout@v5`,
  `actions/setup-java@v5`, `actions/upload-artifact@v6` and
  `softprops/action-gh-release@v3`. All four moves were runtime-only migrations:
  no input this workflow passes was renamed or removed, and `upload-artifact`'s
  opt-in `archive` parameter is left unset so uploads stay zipped as before.
  `upload-artifact` had to go to **v6**, not v5: v5's release notes claim Node 24
  support but state it "by default" still runs on Node 20, so v5 kept the
  deprecation warning. Only v6 changed the default.
- **31 regression tests** pinning both bugs: `test/change_due_regression_test.dart`
  (25) covers overpayment across the dashboard, receipt, billing and badge paths,
  and `test/void_reversal_regression_test.dart` (6) covers the void reversal
  including the duplicate-product-line case, bringing the suite to 169 tests.

### Known upcoming
- **`ubuntu-latest` moves to Ubuntu 26 on 2026-10-19.** Nothing is wrong today,
  but the runner image will change under this workflow. If a build after that
  date fails to resolve the Android SDK or JDK, pin `runs-on: ubuntu-24.04`. A
  comment at the job level records this.

### Verified
Both fixes were confirmed end-to-end on a Pixel 4 AVD against live Firestore, not
only in unit tests: a Rs 39,000 sale paid with Rs 40,000 showed Cash in Hand at
Rs 61,500, and voiding it returned the till to Rs 22,500 and restored stock to 5
pieces.

## v1.5.2 Ã¢â‚¬â€ September 2026

Two data-integrity bugs that both presented as "the app is broken", plus the
audit pass that surfaced them.

### Fixed
- **Every product announced its stock in the wrong unit.** A product the shop
  counted as 5 cut pieces read "5 sq.ft in stock" on a real device. `unitType`
  was a hardcoded `'per_sqft'` written when a product was created, with no
  control anywhere in the UI to change it and `Product.fromMap` defaulting to it
  when the field was absent Ã¢â‚¬â€ so `unitLabel` had nothing correct to read and
  labelled all stock in square feet. A stock count in the wrong unit is a
  misstatement of inventory, not a cosmetic slip. Add and Edit Product now have
  a **Pieces / Per sq.ft** toggle (defaulting to Pieces), Edit seeds it from the
  stored value so it never silently resets, and the unit is now carried on every
  stock figure the user reads Ã¢â‚¬â€ the inventory pill, the sale-entry search row
  (which was printing a bare "4 in stock" with no unit at all), the low-stock
  notification and the restock sheet Ã¢â‚¬â€ so the list, the cart and the restock
  sheet can no longer disagree with one another.
- **The product search row rendered `78in ? 72in ? 6in ? 15 in stock` on device.**
  The `Ãƒâ€”` (U+00D7) and `Ã‚Â·` (U+00B7) separators in the search result had been
  written into the source as literal `?` bytes, so Flutter drew four
  replacement characters in the row a user taps most often while building a
  sale. The Inventory screen showed the same dimensions correctly, which is why
  it survived review. Restored using the `\u00d7` / `\u00b7` escapes already
  used in `inventory_screen.dart`, and added `test/source_integrity_test.dart`
  to fail the build if a " ? " separator reappears in `lib/`.
- **Receipt prices were silently truncated.** A `120,000` total printed as
  `120,00` and a `60,000` unit price as `60,00` on the 80mm receipt. The
  itemised table gave the money columns a fixed slice of the roll width
  (`FlexColumnWidth(1.4)` and `(1.6)` of 7.6) that was sized when totals were
  four digits, and the cells render with `maxLines: 1` +
  `TextOverflow.clip` Ã¢â‚¬â€ so the overflow was dropped rather than wrapped or
  flagged. A customer's receipt showed a *wrong number*. The columns are now
  measured from the actual figures in each receipt, using the same font and the
  same measure path the painter uses, and the product name (which already
  elides over two lines) absorbs the difference.
- **CSV, XLSX and PDF report export failed whenever the period contained an
  older sale.** Every export path labelled a sale's customer with
  `customerName ?? customerId.substring(0, 6)`, which throws `RangeError` for
  any id shorter than six characters. Sales written before the
  `customer_name` field existed have exactly that shape, so a single legacy
  record aborted all three exports. Replaced with a fallback that cannot throw,
  and a report with no name and no id is now labelled "Walk-in Customer"
  instead of being dropped.
- **A failed sale save was silent.** The save path had a `finally` but no
  `catch`, so a Firestore failure Ã¢â‚¬â€ a stock race, a permissions denial, an
  offline write Ã¢â‚¬â€ escaped as an unhandled async error. The cart survived and
  the user was told nothing, then tapped Save again. It now logs and shows a
  sanitised message.
- **A cart line whose product no longer exists could save with a cost price of
  0**, understating COGS and overstating profit permanently. It is now rejected
  with a clear message instead.
- **Carts with more than 10 distinct products saved with wrong data.** The
  product fetch took `ids.take(10)` (the Firestore `whereIn` cap), silently
  dropping the rest, so those lines skipped the stock check and were written
  with `costPriceAtSale: 0`. The fetch is now batched.
- **Stock counts lost their fractional part and their unit.** `stockLabel`
  hardcoded `pcs` and truncated with `.toInt()`, so `2.5` sq.ft read as "2 pcs"
  in the inventory list while the restock sheet said "2 sq.ft" for the same
  product.
- **The Expenses screen had two filter buttons**, one with no accessible label.
- **"Saved to Downloads/Ã¢â‚¬Â¦" was shown on every platform**, including iOS, where
  the file goes to the app's documents directory.
- Removed two analyzer suppressions (`uri_does_not_exist`,
  `undefined_identifier`) that were hiding real defect classes. Analysis is clean
  without them.

### Changed
- The accounting hot path no longer logs once per sale line on every stream
  tick; the same checks are counted and reported once, behind an opt-in flag.
  Figures are unchanged.
- Receipts are laid out from measured column widths rather than hardcoded flex
  ratios, so a wider number costs product-name width instead of correctness.
- Dead code removed: 12 unused `FirestoreService` methods, an unused success
  dialog, two unused providers, 11 unused theme colour aliases, two placeholder
  tests that asserted nothing, and stray files at the repo root.

### Added
- **On-device end-to-end tests for report export**
  (`integration_test/export_e2e_test.dart`). The host-side suite could not prove
  that a report is actually *written*: `path_provider` is stubbed on the host
  and returns a path that does not exist, so a broken export passed CI and only
  failed in a shop's hands. These run on physical hardware, generate each format
  through the same public API the Export screen calls, then reopen the file and
  parse it back Ã¢â‚¬â€ CSV re-parsed into rows, XLSX unzipped and its cells read back
  as numbers, PDF checked for its structural markers, page count, and (for the
  report, which uses the built-in Helvetica) its money figures read from the
  content stream. Run with
  `flutter test integration_test/export_e2e_test.dart -d <device-id>`; excluded
  from the plain `flutter test` run because it needs a device attached.
  Verified passing on a Pixel 9 running Android 17.
- **The receipt's money figures are now verified on-device, not just on layout
  maths.** The receipt embeds a subsetted Inter, so its content stream stores
  glyph ids rather than ASCII Ã¢â‚¬â€ but the `pdf` package writes a `/ToUnicode` CMap
  beside each subset. The on-device test decodes that and asserts `60,000` and
  `120,000` are printed whole, and that a clipped `120,00` appears nowhere. This
  corrects an earlier claim in this changelog's working notes that the receipt's
  text "cannot be read back from the file" Ã¢â‚¬â€ it can, and now is.
- **The receipt-save-to-Downloads path is now verified end to end on hardware.**
  The real `MethodChannel` runs against the real `MainActivity`, and the
  returned location must be a `content://media/external/downloads/...` URI Ã¢â‚¬â€
  proving the file is registered with MediaStore rather than written to a
  scoped-storage path that silently goes nowhere. A blank file name must be
  rejected natively. Confirmed independently out-of-band with
  `adb shell content query`, which lists the saved receipt in Downloads.
- **Documented the release signing-identity gap.** The release keystore is
  correctly gitignored, which means the signing identity cannot be recovered
  from a clone and a local `release.keystore` is not necessarily the key that
  signed the published APKs. `RELEASE.md` now spells out the two identities, how
  to compare their fingerprints, and what happens if they differ.
- **Documented why the CI Flutter version is pinned**, and when it is safe to
  bump. The local toolchain being one patch ahead is expected and harmless.

### Update dialog ("What's New")

The in-app update prompt is **unchanged in v1.5.2** Ã¢â‚¬â€ it is documented here so
the release notes describe what a user actually sees. The dialog itself has
been in the app since the initial commit; nothing about it was touched in the
last 24 hours, and no part of it is new in this release.

- On launch, `HomeScreen` compares the installed version from
  `package_info_plus` against the latest GitHub Release tag. If the remote tag
  is newer, a centre modal opens showing `v<installed>` Ã¢â€ â€™ `v<remote>` and the
  release notes, with **Update Now** (opens the Releases page externally) and
  **Remind me later** (dismisses without blocking the app).
- The check is fire-and-forget: any network, parse, or platform error is
  swallowed, so a user with no connectivity simply never sees the dialog.
- **Known limitation, not fixed here:** "Remind me later" is not persisted. The
  check runs on every `HomeScreen` mount, so the dialog reappears on the next
  app start for as long as a newer release exists. Suppressing it for a period
  would need a `shared_preferences` key; the dependency is already present.

## v1.5.1 Ã¢â‚¬â€ September 2026

Sales-screen cart line rebuilt, and a text-encoding bug that the analyzer could not see.

### Fixed
- **The revenue trend callout rendered as `Peak Sep `Ã‚Â·` Rs 172,000`.** A `Ã‚Â·` (U+00B7) had been UTF-8 encoded, then decoded as Latin-1 and re-encoded, leaving the two-character sequence `U+00C2 U+00B7` in the source. It is valid Dart, so `flutter analyze` was silent and no widget test failed Ã¢â‚¬â€ the bad glyph only appeared on screen. The character is now written as a `\u00b7` escape, which is encoding-independent, and the same corruption was repaired in three comments in `app_button.dart` and two elsewhere.
- **The quantity steppers measured 46Ãƒâ€”46, not 48Ãƒâ€”48.** `Container` reserves a 1px layout padding for a border declared in `decoration`, which silently shrank both hit areas below the app's own `AppHit.min` Ã¢â‚¬â€ the exact minimum the track exists to honour, and the reason a miss on `+` could land on `Ã¢Ë†â€™`. The hairline moved to `foregroundDecoration`, which paints the same line without affecting layout.
- The cart heading read `CART Ã‚Â· 1 ITEMS` on every single-item sale, which is the most common sale there is. Correctly pluralised.

### Changed
- The cart line no longer crams the product name, the price field, the running total and the remove button onto a single 40px row Ã¢â‚¬â€ four competing elements in a strip that cannot grow, so the `PER UNIT` label wrapped away from its field and the line total was pushed off the right edge on a narrow phone. It is now four bands: identity (name, plus cost and stock on a sub-line, so the cost that decides whether a price is safe is visible *before* a mistake is made), controls (price and quantity on one baseline, the field `Expanded` rather than a fixed 96dp so a 6-digit price cannot clip), summary (a status pill and the line total at display weight), and a below-cost notice.
- `MARGIN -832%` is replaced by a named state. The percentage was arithmetically correct and practically useless: a margin that far negative only means "well below cost", which the new notice states directly as a rupee shortfall, with a one-tap **Use cost** shortcut. A deliberate discount is still one tap away.
- A below-cost cart line no longer washes the entire card in 25% red. The wash drops to 5% and the loss state is carried by a hairline and the notice, so the thing that reads as the warning is the notice.
- Added a **Clear all** action to the cart heading; the only previous way to empty a cart was one remove tap per line.
- Google Sign-In falls back to the project's built-in web client id when `google-services.json` omits the `client_type: 3` entry. Without it, that resource is never generated and Sign-In fails with error 10 on every build. An explicit `--dart-define` still takes precedence.

### Fixed (receipt save and price entry)
- **"Save PDF" now actually puts the receipt in the phone's storage.** The receipt was written with `dart:io`'s `File` directly into `/storage/emulated/0/Download`, which Android's scoped storage has sealed since Android 10 Ã¢â‚¬â€ the app showed a success toast and no file ever appeared. `WRITE_EXTERNAL_STORAGE` is also capped at `maxSdkVersion=28` in the manifest, so there was no permission that could have made it work. Saving on Android now goes through `MediaStore` via a new method channel, which needs no runtime permission and makes the PDF visible to Files, Downloads and gallery apps. The write is staged with `IS_PENDING` so a half-written receipt never shows up, and a failed insert is deleted rather than left as an orphan row. Devices below Android 10 keep the direct write, which is still correct there.
- A save that cannot be verified is no longer reported as a success. The native side returns the resolved `content://` location, an empty or null reply is treated as a failure, and the share sheet remains the fallback so a receipt is never lost.
- Receipt PDF page height now fits the content instead of reserving A4's 297mm long edge on an 80mm-wide thermal roll. A one-item receipt was ~125mm of content on a 297mm sheet, so the print preview showed a page that was two-thirds blank. Heights are computed from the actual block structure and calibrated so the receipt still lands on a single page from an empty cart up to a 12-item order.

### Changed (receipt and price entry)
- Receipt rebuilt from scratch against the mockup: the PDF and the on-screen preview now share one typed `ReceiptData`/`ReceiptLine` model, so the two cannot drift. The page is sized with `pw.Widget.measure` instead of a hand-rolled height estimate, which removes the blank-page/second-page failure mode. Receipts that genuinely exceed the 80mm roll fall back to paginated A4.
- Sales price field is now a 96Ãƒâ€”48 target with a larger font, up from 68Ãƒâ€”30 Ã¢â‚¬â€ it was below the app's own 48dp touch minimum and cramped for a 5-6 digit figure.
- Sales price field no longer loses focus mid-edit. The cart republishes on every keystroke, which rebuilt the field and dropped the caret into the search box after a single character; it now holds a persistent `FocusNode` and reasserts focus after provider updates.

## v1.5.0 Ã¢â‚¬â€ September 2026

UI correctness and performance pass. **Colour tokens are unchanged from the withdrawn v2.0.0 line** Ã¢â‚¬â€ the deep blue / periwinkle / dusty mauve palette is identical, and v1.5.0 is the release that ships it. Every new glass token is an alpha derivation of an existing colour, so no hue shifted.

This release supersedes the `v2.0.0` and `v2.0.1` tags, both of which have been deleted locally and on GitHub along with their Releases. The v2.0.0 palette-migration entry is retained below for history, but v1.5.0 is the only tagged release on this line.

### Fixed
- Back button no longer bleeds a white glow across the first letters of a screen title (it was a 15px button carrying a 20px-blur shadow)
- Screen headers no longer collide with the status bar; one inset-aware `AppTopBar` now serves the whole app, replacing the two divergent headers
- Removed the opaque white rectangle that appeared inside every glass search field (the global input fill was ~91% opaque and at a different radius to the surrounding glass)
- Removed the "ghost rectangle" rendered behind dashboard cards (the shadow, border and clip radius were declared on two different boxes and could drift out of alignment)
- Dashboard and Khata KPI tiles now share one height instead of sizing independently
- Horizontal accounting strip no longer slices its last card in half at the page gutter
- Scrollable content no longer parks underneath the floating nav bar (the four tabs had disagreed on the bottom inset)
- Due / Void status badges are legible again Ã¢â‚¬â€ the ~80% opaque fills were being used as text colours
- Modal scrim no longer shifts the perceived hue of the palette
- Inventory FAB uses the brand gradient and carries an accessible label
- Receipt PDF no longer prints the currency symbol in every PRICE and TOTAL cell (it rendered as "Rs Rs 25,500" and overflowed the 80mm columns onto a second line)
- Receipt PDF embeds a Unicode-capable font, so the `Ã¢Å“â€œ` and `Ã‚Â·` glyphs render instead of printing as blank boxes
- Receipt PDF filename can no longer throw a `RangeError` on a short sale id and take down the whole share sheet

### Changed
- New `app_tokens.dart`: radius scale, 4/8dp spacing rhythm, shared motion vocabulary, 48dp hit-target minimum, icon and numeric type scales
- `GlassContainer` rebuilt around `AppGlassLevel` (base / raised / nested) so fill, border, shadow and blur are chosen deliberately instead of via a loose `strong:` flag
- One shared `HomeScreen.contentBottomInset` for every tab, instead of four hardcoded values
- Hero card, empty states, sheets, segmented control, status badges, menu rows and the revenue chart rebuilt as glass
- Revenue chart gained gridlines, a K/M value axis, a peak callout, visible zero-bars and a screen-reader summary
- Backdrop blur is rationed to the floating nav pill only; every other surface is opaque
- The animated background orbs (three permanently-ticking animators forcing a full-screen repaint every frame) are gone Ã¢â‚¬â€ the app background is a static themed surface
- Dark-mode primary buttons no longer wash out: brand fills were split into `brandFill` / `brandFillDeep` so the foreground-tuned colour is no longer reused as a background
- New `controlBorder` token, because `outline` was ~1.2:1 against a dark card and made outlined buttons look like loose text
- Inactive nav labels moved from `inkFaint` to `inkSoft` to clear 4.5:1 contrast over glass
- Nav pill slimmed from 70dp to 58dp, still clearing the 48dp touch minimum
- Segmented control selection is now signalled by bold weight as well as colour
- Icon-only controls now require a semantic label; all touch targets meet 48dp
- Reduced-motion support for ambient animation
- Google Sign-In failures now report actionable messages instead of a bare "Sign in failed"
- Release APK asset renamed `Foam-Shop-Pos-v<version>.apk` (the upload step rewrote spaces to dots)
- `path_provider_android` pinned to 2.2.12 to avoid the `jni` native CMake/NDK build failure

### Added
- Receipt PDF "Save PDF" action, writing to the device Downloads folder with a share-sheet fallback
- Receipt PDF now prints on 80mm thermal-roll width instead of A4
- Receipt PDF includes the shop phone number and a short `INV-####` receipt number
- `test/ui_regression_test.dart` Ã¢â‚¬â€ 43 tests locking in each fix above, plus assertions pinning the palette so colour cannot silently drift

### Removed
- Dead code with no remaining call sites: `validation.dart`, `app_search_bar.dart`, `section_label.dart`, `stitched_divider.dart`, `sync_status_indicator.dart`, `torn_receipt_card.dart`, the background orb animation, and the unused `subscriptionWarningDays` constant
- Unused `shimmer` dependency

## v2.0.0 Ã¢â‚¬â€ September 2026 (withdrawn Ã¢â‚¬â€ never released under this tag)

> Tag and Release deleted. This work shipped in **v1.5.0**; the entry is kept for history only.

- Changed: **New visual identity.** The entire theme is now built on a deep blue / periwinkle / dusty mauve palette Ã¢â‚¬â€ Deep Ink `#0E0D15`, Deep Navy `#182346`, Slate Blue `#3D5387`, Muted Periwinkle `#7C83AD`, Dusty Mauve `#BFA9BA`. This replaces the previous teal/indigo/coral scheme. Color tokens only Ã¢â‚¬â€ no layout, typography, navigation, or business-logic changes.
- Changed: Primary, secondary, and accent colors across all Material components (buttons, inputs, chips, dialogs, sheets, navigation, snackbars, tooltips)
- Changed: Semantic domain colors (Sale, Purchase, Expense, Profit, Inventory, Khata, Cash) recolored into the new blue/mauve family while keeping their meaning distinguishable
- Improved: Light and dark themes are now both fully defined by the palette, with derived surface layers for clearer depth in dark mode
- Improved: Hero card, bottom sheets, glass surfaces, navigation indicator, and dialogs now use palette-derived colors instead of hardcoded values
- Improved: CI release APKs are now named `Foam-Shop-Pos-v<version>.apk` for easier download from the Releases page

## v1.0.6 Ã¢â‚¬â€ July 2026

- Added: Animation system Ã¢â‚¬â€ TapScale micro-interactions on press, smooth slide-up page transitions app-wide
- Fixed: Update Available dialog now shows full changelog text without truncation, scrollable inside bounded container
- Fixed: CI workflow updated to Flutter 3.44.8 for build compatibility
- Improved: Navigation transitions across all screens for a polished, professional feel

## v1.0.5 Ã¢â‚¬â€ July 2026

- Fixed: Contact Support Ã¢â‚¬â€ Email option now correctly opens installed mail apps (Gmail, Outlook)
- Fixed: Update Available dialog now scrollable for long changelog content
- Removed: Redundant "No server, no cost" hint text from Notification Settings
- Improved: Customer name overflow handling in Khata list

## v1.0.4 Ã¢â‚¬â€ July 2026

- Fixed: Trial period indicator now shows correctly for new accounts
- Fixed: Dark mode readability improved on New Sale screen
- Fixed: Delete Account confirmation now works correctly regardless of letter case
- Fixed: Low stock notifications now fire reliably on app open
- Fixed: Contact Support Ã¢â‚¬â€ Email option now works correctly (no longer silently fails)
- Fixed: All profit calculations (Revenue, Cost of Goods Sold, Gross/Net Profit) are now consistent and accurate across Dashboard and Reports
- Fixed: Reports page no longer shows incorrect profit figures when product cost prices have been edited since the sale
- Removed: Product Sell Price field Ã¢â‚¬â€ price is now entered per sale, matching real negotiated pricing
- Improved: Buy Price is now required when adding a product to Inventory, ensuring profit tracking is accurate from the start
- Improved: Consistent avatar/icon styling throughout the app for a more polished look
- Improved: In-app changelog now shows real release notes instead of placeholder text
- Improved: Email feedback option shows contact address as fallback if no mail app is available

## v1.0.3

- Fixed: Various UI and calculation fixes
- Improved: App stability and performance
