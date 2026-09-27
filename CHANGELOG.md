# Changelog

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

## Unreleased

### Fixed
- **"Save PDF" now actually puts the receipt in the phone's storage.** The receipt was written with `dart:io`'s `File` directly into `/storage/emulated/0/Download`, which Android's scoped storage has sealed since Android 10 — the app showed a success toast and no file ever appeared. `WRITE_EXTERNAL_STORAGE` is also capped at `maxSdkVersion=28` in the manifest, so there was no permission that could have made it work. Saving on Android now goes through `MediaStore` via a new method channel, which needs no runtime permission and makes the PDF visible to Files, Downloads and gallery apps. The write is staged with `IS_PENDING` so a half-written receipt never shows up, and a failed insert is deleted rather than left as an orphan row. Devices below Android 10 keep the direct write, which is still correct there.
- A save that cannot be verified is no longer reported as a success. The native side returns the resolved `content://` location, an empty or null reply is treated as a failure, and the share sheet remains the fallback so a receipt is never lost.
- Receipt PDF page height now fits the content instead of reserving A4's 297mm long edge on an 80mm-wide thermal roll. A one-item receipt was ~125mm of content on a 297mm sheet, so the print preview showed a page that was two-thirds blank. Heights are computed from the actual block structure and calibrated so the receipt still lands on a single page from an empty cart up to a 12-item order.

### Changed
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
