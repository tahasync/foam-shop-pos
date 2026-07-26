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
- **UI:** `flutter_animate`, `shimmer`, `fl_chart`, `flutter_svg`
- **CI/CD:** GitHub Actions — deterministic APK builds on `v*` tags

## Features

- **Dashboard** — real-time revenue, COGS, gross/net profit, cash-in-hand, margin %, 30-day periodic reports, register slip counter, low-stock alert tap → filtered inventory
- **Inventory** — search, filter, restock with WAC costing, low-stock threshold, archive. Buy Price is required at product creation for accurate profit tracking.
- **Sales entry** — product search with highlights, multi-item cart, **per-sale negotiated pricing** (no fixed sell price on products), partial payments, balance tracking, quotes
- **Customer Khata** — per-customer item-level ledger sorted by most recent activity, payment collection, balance card
- **Supplier Khata** — purchase ledger with payment tracking
- **Expenses** — category-based expense tracking
- **Exports** — CSV, styled XLSX (teal header + frozen rows), branded PDF with receipt printing
- **Reports** — 30-day periodic profit/loss with consistent COGS calculations
- **Subscription gate** — 14-day trial, blocking expired screen, founding account exemption
- **Notifications** — on-device low-stock alerts and overdue baqaya reminders (local-only, no server cost)
- **Support / Feedback** — in-app contact form with WhatsApp and Email deep links
- **Theming** — light + dark mode with floating pill navigation
- **Update notifications** — in-app "What's New" dialog showing curated changelog from GitHub Releases

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

Every push to `main` runs analyze + tests + builds a debug APK. Every `v*` tag builds a signed release APK, generates a changelog from `CHANGELOG.md`, and creates a GitHub Release with the APK attached.

```bash
git tag v1.0.4
git push origin v1.0.4
```

The pipeline uses:
- Flutter 3.44.6 pinned (deterministic)
- `pubspec.lock` committed for reproducible dependency resolution
- Base64-encoded Firebase config for reliable secret injection
- `google-services.json` validated against `applicationId` before build
- Release keystore decoded from CI secrets (not checked into repo)

## Testing

```bash
flutter test
```

The test suite covers:
- Accounting calculations: Cash in Hand, Revenue, COGS, Gross/Net Profit, Baqaya aggregation
- Regression: costPriceAtSale isolation (not affected by later cost price edits)
- Regression: inventory changes never affect Cash in Hand, Revenue, or Expenses
- Edge cases: empty data, NaN/Infinity sanitization
- Notification detection logic
- Subscription trial label behavior
- Core model instantiation and COGS formula with per-sale negotiated pricing

## Status

**Production-ready Android app — actively maintained.** Used by foam/mattress shops with subscription-based commercial model. The founding account is free forever; new sign-ups get a 14-day free trial.

The automated test suite (3 test files, 19 tests) covers accounting calculations (Revenue, COGS, Gross/Net Profit, Baqaya, Cash in Hand), core model instantiation, COGS fallback chain, costPriceAtSale isolation, subscription trial label logic, and notification detection. Not a full UI coverage suite — focused on the highest-regression-risk areas given the app's bug history.
