# Changelog

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
