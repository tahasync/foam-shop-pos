# Changelog

## v1.5.2 — September 2026

Two data-integrity bugs that both presented as "the app is broken", plus the
audit pass that surfaced them.

### Fixed
- **Every product announced its stock in the wrong unit.** A product the shop
  counted as 5 cut pieces read "5 sq.ft in stock" on a real device. `unitType`
  was a hardcoded `'per_sqft'` written when a product was created, with no
  control anywhere in the UI to change it and `Product.fromMap` defaulting to it
  when the field was absent — so `unitLabel` had nothing correct to read and
  labelled all stock in square feet. A stock count in the wrong unit is a
  misstatement of inventory, not a cosmetic slip. Add and Edit Product now have
  a **Pieces / Per sq.ft** toggle (defaulting to Pieces), Edit seeds it from the
  stored value so it never silently resets, and the unit is now carried on every
  stock figure the user reads — the inventory pill, the sale-entry search row
  (which was printing a bare "4 in stock" with no unit at all), the low-stock
  notification and the restock sheet — so the list, the cart and the restock
  sheet can no longer disagree with one another.
- **The product search row rendered `78in ? 72in ? 6in ? 15 in stock` on device.**
  The `×` (U+00D7) and `·` (U+00B7) separators in the search result had been
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
  `TextOverflow.clip` — so the overflow was dropped rather than wrapped or
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
  `catch`, so a Firestore failure — a stock race, a permissions denial, an
  offline write — escaped as an unhandled async error. The cart survived and
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
- **"Saved to Downloads/…" was shown on every platform**, including iOS, where
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
  parse it back — CSV re-parsed into rows, XLSX unzipped and its cells read back
  as numbers, PDF checked for its structural markers, page count, and (for the
  report, which uses the built-in Helvetica) its money figures read from the
  content stream. Run with
  `flutter test integration_test/export_e2e_test.dart -d <device-id>`; excluded
  from the plain `flutter test` run because it needs a device attached.
  Verified passing on a Pixel 9 running Android 17.
- **The receipt's money figures are now verified on-device, not just on layout
  maths.** The receipt embeds a subsetted Inter, so its content stream stores
  glyph ids rather than ASCII — but the `pdf` package writes a `/ToUnicode` CMap
  beside each subset. The on-device test decodes that and asserts `60,000` and
  `120,000` are printed whole, and that a clipped `120,00` appears nowhere. This
  corrects an earlier claim in this changelog's working notes that the receipt's
  text "cannot be read back from the file" — it can, and now is.
- **The receipt-save-to-Downloads path is now verified end to end on hardware.**
  The real `MethodChannel` runs against the real `MainActivity`, and the
  returned location must be a `content://media/external/downloads/...` URI —
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

The in-app update prompt is **unchanged in v1.5.2** — it is documented here so
the release notes describe what a user actually sees. The dialog itself has
been in the app since the initial commit; nothing about it was touched in the
last 24 hours, and no part of it is new in this release.

- On launch, `HomeScreen` compares the installed version from
  `package_info_plus` against the latest GitHub Release tag. If the remote tag
  is newer, a centre modal opens showing `v<installed>` → `v<remote>` and the
  release notes, with **Update Now** (opens the Releases page externally) and
  **Remind me later** (dismisses without blocking the app).
- The check is fire-and-forget: any network, parse, or platform error is
  swallowed, so a user with no connectivity simply never sees the dialog.
- **Known limitation, not fixed here:** "Remind me later" is not persisted. The
  check runs on every `HomeScreen` mount, so the dialog reappears on the next
  app start for as long as a newer release exists. Suppressing it for a period
  would need a `shared_preferences` key; the dependency is already present.

## v1.5.1 — September 2026

Sales-screen cart line rebuilt, and a text-encoding bug that the analyzer could not see.

### Fixed
- **The revenue trend callout rendered as `Peak Sep `·` Rs 172,000`.** A `·` (U+00B7) had been UTF-8 encoded, then decoded as Latin-1 and re-encoded, leaving the two-character sequence `U+00C2 U+00B7` in the source. It is valid Dart, so `flutter analyze` was silent and no widget test failed — the bad glyph only appeared on screen. The character is now written as a `\u00b7` escape, which is encoding-independent, and the same corruption was repaired in three comments in `app_button.dart` and two elsewhere.
- **The quantity steppers measured 46×46, not 48×48.** `Container` reserves a 1px layout padding for a border declared in `decoration`, which silently shrank both hit areas below the app's own `AppHit.min` — the exact minimum the track exists to honour, and the reason a miss on `+` could land on `−`. The hairline moved to `foregroundDecoration`, which paints the same line without affecting layout.
- The cart heading read `CART · 1 ITEMS` on every single-item sale, which is the most common sale there is. Correctly pluralised.

### Changed
- The cart line no longer crams the product name, the price field, the running total and the remove button onto a single 40px row — four competing elements in a strip that cannot grow, so the `PER UNIT` label wrapped away from its field and the line total was pushed off the right edge on a narrow phone. It is now four bands: identity (name, plus cost and stock on a sub-line, so the cost that decides whether a price is safe is visible *before* a mistake is made), controls (price and quantity on one baseline, the field `Expanded` rather than a fixed 96dp so a 6-digit price cannot clip), summary (a status pill and the line total at display weight), and a below-cost notice.
- `MARGIN -832%` is replaced by a named state. The percentage was arithmetically correct and practically useless: a margin that far negative only means "well below cost", which the new notice states directly as a rupee shortfall, with a one-tap **Use cost** shortcut. A deliberate discount is still one tap away.
- A below-cost cart line no longer washes the entire card in 25% red. The wash drops to 5% and the loss state is carried by a hairline and the notice, so the thing that reads as the warning is the notice.
- Added a **Clear all** action to the cart heading; the only previous way to empty a cart was one remove tap per line.
- Google Sign-In falls back to the project's built-in web client id when `google-services.json` omits the `client_type: 3` entry. Without it, that resource is never generated and Sign-In fails with error 10 on every build. An explicit `--dart-define` still takes precedence.

### Fixed (receipt save and price entry)
- **"Save PDF" now actually puts the receipt in the phone's storage.** The receipt was written with `dart:io`'s `File` directly into `/storage/emulated/0/Download`, which Android's scoped storage has sealed since Android 10 — the app showed a success toast and no file ever appeared. `WRITE_EXTERNAL_STORAGE` is also capped at `maxSdkVersion=28` in the manifest, so there was no permission that could have made it work. Saving on Android now goes through `MediaStore` via a new method channel, which needs no runtime permission and makes the PDF visible to Files, Downloads and gallery apps. The write is staged with `IS_PENDING` so a half-written receipt never shows up, and a failed insert is deleted rather than left as an orphan row. Devices below Android 10 keep the direct write, which is still correct there.
- A save that cannot be verified is no longer reported as a success. The native side returns the resolved `content://` location, an empty or null reply is treated as a failure, and the share sheet remains the fallback so a receipt is never lost.
- Receipt PDF page height now fits the content instead of reserving A4's 297mm long edge on an 80mm-wide thermal roll. A one-item receipt was ~125mm of content on a 297mm sheet, so the print preview showed a page that was two-thirds blank. Heights are computed from the actual block structure and calibrated so the receipt still lands on a single page from an empty cart up to a 12-item order.

### Changed (receipt and price entry)
- Receipt rebuilt from scratch against the mockup: the PDF and the on-screen preview now share one typed `ReceiptData`/`ReceiptLine` model, so the two cannot drift. The page is sized with `pw.Widget.measure` instead of a hand-rolled height estimate, which removes the blank-page/second-page failure mode. Receipts that genuinely exceed the 80mm roll fall back to paginated A4.
- Sales price field is now a 96×48 target with a larger font, up from 68×30 — it was below the app's own 48dp touch minimum and cramped for a 5-6 digit figure.
- Sales price field no longer loses focus mid-edit. The cart republishes on every keystroke, which rebuilt the field and dropped the caret into the search box after a single character; it now holds a persistent `FocusNode` and reasserts focus after provider updates.

## v1.5.0 — September 2026

UI correctness and performance pass. **Colour tokens are unchanged from the withdrawn v2.0.0 line** — the deep blue / periwinkle / dusty mauve palette is identical, and v1.5.0 is the release that ships it. Every new glass token is an alpha derivation of an existing colour, so no hue shifted.

This release supersedes the `v2.0.0` and `v2.0.1` tags, both of which have been deleted locally and on GitHub along with their Releases. The v2.0.0 palette-migration entry is retained below for history, but v1.5.0 is the only tagged release on this line.

### Fixed
- Back button no longer bleeds a white glow across the first letters of a screen title (it was a 15px button carrying a 20px-blur shadow)
- Screen headers no longer collide with the status bar; one inset-aware `AppTopBar` now serves the whole app, replacing the two divergent headers
- Removed the opaque white rectangle that appeared inside every glass search field (the global input fill was ~91% opaque and at a different radius to the surrounding glass)
- Removed the "ghost rectangle" rendered behind dashboard cards (the shadow, border and clip radius were declared on two different boxes and could drift out of alignment)
- Dashboard and Khata KPI tiles now share one height instead of sizing independently
- Horizontal accounting strip no longer slices its last card in half at the page gutter
- Scrollable content no longer parks underneath the floating nav bar (the four tabs had disagreed on the bottom inset)
- Due / Void status badges are legible again — the ~80% opaque fills were being used as text colours
- Modal scrim no longer shifts the perceived hue of the palette
- Inventory FAB uses the brand gradient and carries an accessible label
- Receipt PDF no longer prints the currency symbol in every PRICE and TOTAL cell (it rendered as "Rs Rs 25,500" and overflowed the 80mm columns onto a second line)
- Receipt PDF embeds a Unicode-capable font, so the `✓` and `·` glyphs render instead of printing as blank boxes
- Receipt PDF filename can no longer throw a `RangeError` on a short sale id and take down the whole share sheet

### Changed
- New `app_tokens.dart`: radius scale, 4/8dp spacing rhythm, shared motion vocabulary, 48dp hit-target minimum, icon and numeric type scales
- `GlassContainer` rebuilt around `AppGlassLevel` (base / raised / nested) so fill, border, shadow and blur are chosen deliberately instead of via a loose `strong:` flag
- One shared `HomeScreen.contentBottomInset` for every tab, instead of four hardcoded values
- Hero card, empty states, sheets, segmented control, status badges, menu rows and the revenue chart rebuilt as glass
- Revenue chart gained gridlines, a K/M value axis, a peak callout, visible zero-bars and a screen-reader summary
- Backdrop blur is rationed to the floating nav pill only; every other surface is opaque
- The animated background orbs (three permanently-ticking animators forcing a full-screen repaint every frame) are gone — the app background is a static themed surface
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
- `test/ui_regression_test.dart` — 43 tests locking in each fix above, plus assertions pinning the palette so colour cannot silently drift

### Removed
- Dead code with no remaining call sites: `validation.dart`, `app_search_bar.dart`, `section_label.dart`, `stitched_divider.dart`, `sync_status_indicator.dart`, `torn_receipt_card.dart`, the background orb animation, and the unused `subscriptionWarningDays` constant
- Unused `shimmer` dependency

## v2.0.0 — September 2026 (withdrawn — never released under this tag)

> Tag and Release deleted. This work shipped in **v1.5.0**; the entry is kept for history only.

- Changed: **New visual identity.** The entire theme is now built on a deep blue / periwinkle / dusty mauve palette — Deep Ink `#0E0D15`, Deep Navy `#182346`, Slate Blue `#3D5387`, Muted Periwinkle `#7C83AD`, Dusty Mauve `#BFA9BA`. This replaces the previous teal/indigo/coral scheme. Color tokens only — no layout, typography, navigation, or business-logic changes.
- Changed: Primary, secondary, and accent colors across all Material components (buttons, inputs, chips, dialogs, sheets, navigation, snackbars, tooltips)
- Changed: Semantic domain colors (Sale, Purchase, Expense, Profit, Inventory, Khata, Cash) recolored into the new blue/mauve family while keeping their meaning distinguishable
- Improved: Light and dark themes are now both fully defined by the palette, with derived surface layers for clearer depth in dark mode
- Improved: Hero card, bottom sheets, glass surfaces, navigation indicator, and dialogs now use palette-derived colors instead of hardcoded values
- Improved: CI release APKs are now named `Foam-Shop-Pos-v<version>.apk` for easier download from the Releases page

## v1.0.6 — July 2026

- Added: Animation system — TapScale micro-interactions on press, smooth slide-up page transitions app-wide
- Fixed: Update Available dialog now shows full changelog text without truncation, scrollable inside bounded container
- Fixed: CI workflow updated to Flutter 3.44.8 for build compatibility
- Improved: Navigation transitions across all screens for a polished, professional feel

## v1.0.5 — July 2026

- Fixed: Contact Support — Email option now correctly opens installed mail apps (Gmail, Outlook)
- Fixed: Update Available dialog now scrollable for long changelog content
- Removed: Redundant "No server, no cost" hint text from Notification Settings
- Improved: Customer name overflow handling in Khata list

## v1.0.4 — July 2026

- Fixed: Trial period indicator now shows correctly for new accounts
- Fixed: Dark mode readability improved on New Sale screen
- Fixed: Delete Account confirmation now works correctly regardless of letter case
- Fixed: Low stock notifications now fire reliably on app open
- Fixed: Contact Support — Email option now works correctly (no longer silently fails)
- Fixed: All profit calculations (Revenue, Cost of Goods Sold, Gross/Net Profit) are now consistent and accurate across Dashboard and Reports
- Fixed: Reports page no longer shows incorrect profit figures when product cost prices have been edited since the sale
- Removed: Product Sell Price field — price is now entered per sale, matching real negotiated pricing
- Improved: Buy Price is now required when adding a product to Inventory, ensuring profit tracking is accurate from the start
- Improved: Consistent avatar/icon styling throughout the app for a more polished look
- Improved: In-app changelog now shows real release notes instead of placeholder text
- Improved: Email feedback option shows contact address as fallback if no mail app is available

## v1.0.3

- Fixed: Various UI and calculation fixes
- Improved: App stability and performance
