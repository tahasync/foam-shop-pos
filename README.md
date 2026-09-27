# Foam Shop POS — Digital Register

A Flutter POS and ledger app for foam/mattress shops with real-time Firestore sync, inventory costing, customer/supplier ledger (Khata), expense tracking, and PDF/XLSX/CSV exports. Now a commercial multi-tenant product with subscription management, local notifications, and a full profit/loss reporting suite.

## What it does

Multi-user (per Firebase Auth account) Flutter app managing a foam shop's daily operations: weighted average cost (WAC) inventory with low-stock alerts; sales entry with multi-item cart, partial payments, and per-sale negotiated pricing; customer ledger with per-item transaction history; supplier purchase tracking; expense recording; a real-time dashboard showing revenue, COGS, gross/net profit, margin, and cash-in-hand; export to styled XLSX, CSV, and branded PDF receipts.

Data is live-synced to Firestore — each user sees only their own data (partitioned by `uid`).

## Tech stack

- **Framework:** Flutter (Dart 3.4+) + Riverpod 3
- **Backend:** Firebase Auth (Google Sign-In), Cloud Firestore, Crashlytics, Performance
- **Exports:** `pdf` + `printing`, `excel`, `csv`
- **Notifications:** `flutter_local_notifications` (local-only, zero-cost, no server)
- **UI:** `flutter_animate`, `fl_chart`, `flutter_svg`, `google_fonts`
- **Design system:** hand-rolled glass layer — `app_tokens.dart` (radii, spacing, motion, 48dp hit targets) and `GlassContainer` on an explicit `AppGlassLevel`
- **CI/CD:** GitHub Actions — deterministic APK builds on `v*` tags

## Features

- **Dashboard** — real-time revenue, COGS, gross/net profit, cash-in-hand, margin %, 30-day periodic reports, register slip counter, low-stock alert tap → filtered inventory
- **Inventory** — search, filter, restock with WAC costing, low-stock threshold, archive. Buy Price is required at product creation for accurate profit tracking.
- **Sales entry** — product search with highlights, multi-item cart, **per-sale negotiated pricing** (no fixed sell price on products), partial payments, balance tracking, quotes
- **Customer Khata** — per-customer item-level ledger sorted by most recent activity, payment collection, balance card
- **Supplier Khata** — purchase ledger with payment tracking
- **Expenses** — category-based expense tracking
- **Exports** — CSV, styled XLSX (brand-navy header + frozen rows), branded PDF receipt on 80mm thermal-roll paper
- **Reports** — 30-day periodic profit/loss with consistent COGS calculations
- **Subscription gate** — 14-day trial, blocking expired screen, founding account exemption
- **Notifications** — on-device low-stock alerts and overdue baqaya reminders (local-only, no server cost)
- **Support / Feedback** — in-app contact form with WhatsApp and Email deep links
- **Theming** — light + dark mode with floating pill navigation. Both themes are driven by a single deep blue / periwinkle / dusty mauve palette (see [Color palette](#color-palette))
- **Update notifications** — on launch the app compares the installed version against the latest GitHub Release and, if newer, shows a "What's New" dialog with the current → new version, the release notes, **Update Now** (opens Releases) and **Remind me later**. The check is fire-and-forget: with no network it silently shows nothing. See [Update dialog](#update-dialog-whats-new) for the known "Remind me later" limitation.

## Update dialog ("What's New")

`lib/services/update_checker.dart` implements the in-app update prompt; `HomeScreen._checkUpdate()` calls it once on mount.

- Reads the installed version from `package_info_plus` and `GET`s
  `api.github.com/repos/tahasync/foam-shop-pos/releases/latest`.
- `isNewerVersion` compares dotted numeric parts and tolerates the `v` prefix
  and unequal segment counts (`1.5` vs `1.5.0`).
- `formatChangelog` strips GitHub's `**Full Changelog**` link, any other
  `github.com` URL, and `**` markers before display.
- **Update Now** launches the Releases page with `externalApplication`, so the
  browser handles it rather than an in-app webview.
- Every failure path — non-200, malformed JSON, no network, platform-channel
  error — returns `null` and shows nothing. A user offline is never blocked or
  shown an error.

**Known limitation:** "Remind me later" is not persisted. The check runs on
every `HomeScreen` mount, so the dialog reappears on the next app start for as
long as a newer release exists. Suppressing it for a period is a small change
(`shared_preferences` is already a dependency) but is not implemented.

## Color palette

All UI color is defined in one place — the `AppColors` `ThemeExtension` in `lib/theme/app_theme.dart` — which supplies both the `ColorScheme` for standard Material widgets and semantic tokens for the design system. Structural concerns (radii, spacing, motion durations, minimum hit targets, icon and numeric type scales) live separately in `lib/theme/app_tokens.dart` and deliberately introduce **no new colours**. Five core colors drive both themes:

| Token | Hex | Role |
|---|---|---|
| Deep Ink | `#0E0D15` | Darkest background, primary text in light mode |
| Deep Navy | `#182346` | Primary brand color, light-mode buttons and text |
| Slate Blue | `#3D5387` | Secondary interactive elements, selected states |
| Muted Periwinkle | `#7C83AD` | Dark-mode primary, supporting surfaces |
| Dusty Mauve | `#BFA9BA` | Soft accent, highlights, expense/error tones |

**Light theme** — background `#F7F4F2`, surface `#FFFFFF`, primary `#182346`, secondary `#3D5387`, accent `#BFA9BA`.
**Dark theme** — background `#0E0D15`, with elevated surfaces stepping through `#141A2A` → `#202D4E` → `#2D3B61` for depth, and primary `#7C83AD` for contrast.

Semantic roles (sale, purchase, expense, profit, inventory, khata, cash) keep their meaning but are drawn from this blue/mauve family. `AppTheme` also keeps legacy aliases such as `teal`, `amber`, and `sage` for backward compatibility — the names remain, but the values now come from the current palette.

Theme mode (System / Light / Dark) is user-selectable in Settings and persisted via `SharedPreferences`. Changing a color should be done by editing a token in `app_theme.dart`, not by hardcoding a color in a widget.

## Profit calculations (important)

All profit figures (COGS, Gross Profit, Net Profit, Margin %) across the Dashboard, Reports, and Exports are computed from a single shared `AccountingService`. COGS uses **costPriceAtSale** — the product's Buy Price snapshotted at the moment of sale — so editing a product's cost price later never retroactively changes historical profit reports. A fallback to the product's current Buy Price exists only if the historical snapshot is unavailable.

No estimated COGS (e.g. `salePrice × 0.70`) is ever used — Buy Price is required when adding products to Inventory, ensuring every sale has a real cost basis.

## Security

This project underwent a comprehensive security audit covering:

- **Rate limiting** — dual-key (device + account) throttling on auth with env-driven config
- **Input validation** — model-level assertions + `FormatException` rejection on all 9 models (Product, Sale, Customer, Supplier, Purchase, Expense, Payment, SupplierPayment, OpeningBalance)
- **Secrets management** — all Firebase keys and OAuth client IDs externalized to `env/firebase_config.json` (gitignored). Git history BFG-purged. No secrets in any commit or tag.
- **Error handling** — safe sanitizer masks Firebase and `PlatformException` stack traces. Structured logging via `logSecureError`.
- **Firestore rules** — field-level type guards, date validation, line-item schema enforcement, `transaction_uuid` idempotency, unknown collection denial
- **Dependency audit** — all key dependencies updated to latest compatible versions
- **CSV injection** — formula prefix sanitization (`=`, `+`, `-`, `@` cells prefixed with apostrophe)

## Platform support

- **Android** — fully supported, CI builds release APKs (signed) on every `v*` tag. Distribution via GitHub Releases (direct APK download).
- **iOS** — Xcode project exists, CI does not build for iOS
- **Web / macOS / Windows / Linux** — scaffolding only

## Setup

```bash
git clone https://github.com/tahasync/foam-shop-pos.git
cd foam-shop-pos
flutter pub get

# 1. Create your own Firebase project
# 2. Download google-services.json → android/app/ (gitignored)
# 3. Create env/firebase_config.json with dart-define keys (see env/firebase_config.example.json)
# 4. Add FIREBASE_WEB_CLIENT_ID to the config for Google Sign-In

flutter run --dart-define-from-file=env/firebase_config.json
```

## Release process

**Current version: `1.5.4` (`pubspec.yaml` → `version: 1.5.4+7`).** See [CHANGELOG.md](CHANGELOG.md) for the full release history.

**See [RELEASE.md](RELEASE.md) for the full release workflow.** The supported way to produce a release APK locally is:

```bash
# PowerShell (Windows)
$env:KEYSTORE_PASSWORD = "your-password"
.\scripts\release_build.ps1

# Bash (Linux/macOS/WSL)
KEYSTORE_PASSWORD="your-password" ./scripts/release_build.sh
```

The script runs clean → deps → analyze → test → build in sequence. Any failure stops the process before the build step. Never run `flutter build apk --release` directly without these pre-flight checks.

## CI/CD

Every push to `main` runs analyze + tests + builds a debug APK. A `dart format` check runs alongside them, so an unformatted file fails CI rather than landing silently. It runs **after** `flutter pub get` on purpose: `dart format` picks the code style from the language version recorded in `.dart_tool/package_config.json`, so running it before dependencies are resolved makes it reformat the whole tree in a different style and fail spuriously. Every `v*` tag builds a signed release APK, generates a changelog from `CHANGELOG.md`, and creates a GitHub Release with the APK attached. The attached asset is named `Foam-Shop-Pos-v<version>.apk`, where the version comes from the tag (falls back to the `version:` in `pubspec.yaml` for non-tag builds).

```bash
git tag v1.5.0
git push origin v1.5.0
```

The pipeline uses:
- Flutter 3.44.8 pinned (deterministic)
- `pubspec.lock` committed for reproducible dependency resolution
- Base64-encoded Firebase config for reliable secret injection
- `google-services.json` validated against `applicationId` before build
- Release keystore decoded from CI secrets (not checked into repo)

## Testing

```bash
flutter test
```

The suite is 8 files / 151 tests. It covers:
- Accounting calculations: Cash in Hand, Revenue, COGS, Gross/Net Profit, Baqaya aggregation
- Regression: costPriceAtSale isolation (not affected by later cost price edits)
- Regression: inventory changes never affect Cash in Hand, Revenue, or Expenses
- Edge cases: empty data, NaN/Infinity sanitization
- Notification detection logic
- Subscription trial label behavior
- Core model instantiation and COGS formula with per-sale negotiated pricing
- Stock-unit correctness: Pieces vs Per sq.ft, the `2.5 sq.ft` fractional regression, and the Firestore round trip
- Source-integrity guards (`test/source_integrity_test.dart`) that fail the build if mojibake separators reappear in `lib/`
- **UI regression (`test/ui_regression_test.dart`, 43 tests)** — palette-drift guards, WCAG contrast in both themes, 48dp touch targets, the shared bottom inset that keeps content clear of the floating nav, the blur budget, and receipt PDF generation
- **Change-due regression (`test/change_due_regression_test.dart`, 25 tests)** — overpayment across the dashboard, receipt, billing and status-badge paths, locking in that change is excluded from Cash in Hand and Revenue
- **Void-reversal regression (`test/void_reversal_regression_test.dart`, 6 tests)** — voiding reverses revenue and restores stock, including a cart with the same product on two lines

The UI regression file exists because `flutter analyze` will happily pass a layout that *looks* wrong. Those tests assert on behaviour — no overflow, correct inset, real touch target, valid PDF bytes — rather than on pixel values.

### On-device end-to-end tests

The suite above runs on the host. It cannot cover one thing: whether a report
file is *actually written to a real device filesystem*. `path_provider` needs a
live platform channel, and on the host the plugin is stubbed out and returns a
path that does not exist — so a broken export looks fine in CI and only fails in
a shop's hands.

`integration_test/` covers that half. It runs on physical hardware, generates
each report through the same public API the Export screen calls, then reopens
the file from disk and parses it back:

```bash
flutter test integration_test/export_e2e_test.dart -d <device-id>
# e.g. -d 48270DLAQ00950   (Pixel 9, Android 17)
```

Per format it asserts: the file exists and is non-empty; CSV re-parses into rows
with the real figures; XLSX begins with the ZIP magic bytes and its cells read
back as numbers; PDF carries its `%PDF-`/`%%EOF` markers and a correct page
count.

**Receipts, in full.** The receipt embeds a subsetted Inter, so its content
stream stores glyph ids rather than ASCII. The `pdf` package writes a
`/ToUnicode` CMap beside each subset, so the test decodes those and reads the
*actual printed text* back out of the file — asserting `60,000` and `120,000`
appear whole, and that a clipped `120,00` does not appear anywhere. This closes
the loop on the original truncation bug at the level a customer would see it,
not just on the layout arithmetic.

**Receipt save, end to end.** The `Save receipt` path is exercised through the
real `MethodChannel` against the real `MainActivity` — no stubbing — and the
returned location must be a `content://media/external/downloads/...` URI, which
is what proves the file was registered with MediaStore rather than written to a
scoped-storage path that silently goes nowhere. A blank file name must be
rejected by the native side instead of producing a nameless row.

It is excluded from the plain `flutter test` run on purpose: it needs a device
attached, and the CI pipeline has none. It takes several minutes on first run
because it builds and installs a debug APK.

## Status

**Production-ready Android app — actively maintained.** Used by foam/mattress shops with subscription-based commercial model. The founding account is free forever; new sign-ups get a 14-day free trial.

The automated test suite (8 test files, 151 tests) covers accounting calculations (Revenue, COGS, Gross/Net Profit, Baqaya, Cash in Hand), core model instantiation, COGS fallback chain, costPriceAtSale isolation, subscription trial label logic, notification detection, stock-unit handling, change-due/overpayment accounting, sale-void reversal, and a UI regression suite that pins the committed colour palette, touch-target minimums, glass/blur budgets and receipt PDF output.

