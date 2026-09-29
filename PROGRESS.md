# PROGRESS

Last updated: 2026-09-28

## Production Readiness Audit — 2026-09-28

Full audit against the 76-section master prompt. Records what was actually
changed and what was actually verified. Anything not verified is listed as
blocked rather than assumed.

### Environment

| | |
|---|---|
| OS | Windows 11 |
| Emulator | Pixel_4 AVD, Android 16 (API 36), 1080x2280 @ 440dpi, x86_64 |
| GPU accel | `hw.gpu.enabled=yes`, `hw.gpu.mode=host` (RTX 4060) |
| App version | 1.5.4+7 |
| Build | release APK 66.9 MB, release AAB 66.1 MB |
| Signing | **debug-signed** — `KEYSTORE_PATH` not set |

## P0 fixed

### 0b. The paywall was held together by a hardcoded list of email addresses

`founder_exempt` and `subscription_status` are written by the app itself, and
the only client-side protection was `AppConstants.foundingAccountEmails` — three
personal addresses compiled into every APK. That was never a security control:
the person holding the phone chooses which account to sign in with, so a list of
addresses proves nothing, and it leaks personal data into a public binary.

**Fixed at the only layer that can enforce it — the Firestore rules.** The
`settings` block now makes both fields server-owned: a client that changes them
on update, or sets them to anything but a plain trial on create, is denied. Only
the Admin SDK bypasses rules, so entitlement is now written out of band.

- Removed the allowlist entirely (3 personal emails no longer ship).
- Onboarding now creates every shop — including a founder's — as an ordinary
  trial, because a client must not choose its own entitlement.
- `scripts/grant_entitlement.mjs` grants founder/paid/trial status via the Admin
  SDK. **Not executed here** (needs a Google credential); flagged in the file.
- `.get(key, default)` throughout, so existing shops that already hold
  `free_forever` keep it across ordinary renames.

Verified: **31/31** rules tests against the real emulator, including five new
ones covering self-grant on create, flipping to `free_forever` on update,
forging an expiry, and — importantly — that an already-entitled shop can still
rename itself and that sign-up is not bricked.

> **Behaviour change requiring the owner's action:** after these rules,
> founder and paying shops can no longer self-provision from the handset. Run
> `scripts/grant_entitlement.mjs free_forever` for each founder account, or
> deploy a Cloud Function that grants on verified payment.

### 0. `transaction_uuid` was not an idempotency key — a retry duplicated the sale

`Sale.toMap()` emitted `transactionUuid ?? id`, and the sales screen never
passed `transactionUuid`, so the field silently fell back to the document id —
which was a **fresh `generateId()` on every attempt**.

`saveSaleTransaction` de-duplicates on the document path:

```dart
final existing = await transaction.get(_sales.doc(sale.id));
if (existing.exists) return;
```

With a fresh id per attempt `existing.exists` was always false, so the guard
protected nothing. Scenario: the commit lands on the server but the response is
lost on flaky mobile data, the cashier reads "Could not save", taps Save again,
and a second full sale is written with a second stock decrement — customer
billed twice, inventory gone, duplicate undeletable. The field was named
`transaction_uuid` and the README claimed idempotency; nothing made it one.

Fixed by making the document id *be* the key: `_pendingSaleId ??= generateId()`
mints once per cart and is reused on every retry, so a retry reuses the same
path and the existing check becomes a genuine no-op. The key is released on
confirmed success and on explicit cart-clear, and deliberately **not** in the
`catch` — that is precisely the case that must keep it.

Also made stock `deductions` accumulate (`+=`) rather than assign, so repeated
product lines can no longer deduct one line's stock while selling two. Matches
what `voidSale` already did in the opposite direction.

Pinned by `test/sale_idempotency_test.dart` (9 tests). The source-level drift
assertion was **mutation-tested**: reverting `??=` to `=` makes it fail.

### 1. Money was truncated, not rounded — receipts did not add up

`double.toInt()` truncates toward zero. Every money display in the app used it
(55 call sites). Reproduced empirically:

```
3 lines @ Rs 100.50  ->  real total 301.50
printed per line: 100, 100, 100   printed total: 301
3 x 100 = 300  !=  301
```

A receipt that does not add up cannot be reconciled by the cashier in front of
the customer, and truncation biased every total *downwards*, so a shop
systematically under-reports revenue. Credits were affected too: `-0.5`
printed as `0`.

- New `lib/utils/money.dart`: `roundMoney` (half away from zero), `roundMoneyTo`,
  `formatMoney`, `formatMoneyWithSymbol`. Non-finite input degrades to 0 rather
  than printing `NaN`; never yields `-0`.
- All 55 money sites now route through `roundMoney`. Applied by a script scoped
  to `format(x.toInt())` only, so quantities and input-parsing `.toInt()` were
  deliberately left alone.
- Receipts now reconcile: the grand total is the rounded exact total, and when
  per-line rounding disagrees with it by a rupee or two, an explicit signed
  **"Rounding adjustment"** row states the gap. Absorbing it silently would
  charge the customer a number that is not the sum of the items they can see.
- The totals row was labelled **"Subtotal"** while carrying the grand total
  (discount + charges already applied). Relabelled **"Total"**.

### 2. Firestore security rules were dead code — and not even deployable

`firestore.rules:43-44` opened with a blanket grant:

```js
match /users/{userId}/{document=**} {
  allow read, write: if isOwner(userId);
```

Firestore rules are a **union of allows with no deny-veto**, so this
neutralised every rule nested beneath it: all per-collection validation, the
append-only audit trail, and the `match /{unknown=**}` catch-all deny. Tenant
isolation was never broken (`isOwner` still required `request.auth.uid ==
userId`) — what was lost was integrity and auditability.

Worse, the file **could not compile at all**:
- `line_items.all(li => ...)` — Firestore rules have no lambda/iteration
  construct (`List` offers only `hasAll`/`hasAny`/`size`/`toSet`).
- `match /{unknown=**}` nested inside `{document=**}` — only one glob per match
  declaration is permitted.
- `firebase.json` had no `rules` key, so `firebase deploy` never shipped it.

So the file was aspirational text. Whatever enforces production is whatever was
pasted into the console by hand.

Fixed all of it, then **verified against the real Firestore emulator**
(`scripts/firestore_rules_test.mjs`, 26 tests, all passing):
- Removed the blanket grant; every collection now has explicit
  read/create/update/delete.
- Rewrote the `update` rules. They tested
  `request.resource.data.keys().hasAny([...])` as if `request.resource` were
  the patch, but on an update it is the **merged document** — always containing
  `id`/`is_archived`, so the clause collapsed to `is_archived == true` and would
  have rejected every product edit, sale, restock and void. Corrected to compare
  `resource.data` against `request.resource.data`.
- Frozen the full financial content of a recorded sale. The emulator caught that
  `paid` was still mutable, so a shopkeeper could rewrite what a customer paid
  and their khata balance to match.
- `cost_price`/`is_archived`/`id` immutability; no un-archiving, no un-voiding.
- Optional fields compared via `Map.get(key, default)` — `Sale.toMap()` writes
  them as null and the SDK omits nulls, so direct access threw and made it
  impossible to void an undiscounted sale.
- Zero-cost restock now permitted (was `> 0` while `Purchase` asserts `>= 0`);
  the old rule rejected a free item mid-transaction and rolled back its paired
  stock increment.
- Removed the two unreferenced helper functions (the compiler rejects the whole
  file for an unused function).
- `firebase.json` now names the rules file so `firebase deploy` ships it.

### 3. `setState()` after dispose in the account-deletion sheet

Three `catch` blocks called `setState` with no `mounted` guard, after nine
sequential awaits including an interactive Google re-auth. The sheet is
dismissible by scrim tap and drag, and cancelling the account picker is the
commonest way to reach those catches — so `dispose()` had already run and the
app threw a full-screen error card, immediately after the user asked to delete
their account. The success path already had the guard; the error paths did not.

## P1 fixed

### Supplier payment reported success before the write landed

`supplier_khata_screen.dart` popped the sheet, fired
`addSupplierPayment(...).catchError((_) {})` without awaiting, and showed
*"Payment recorded for X"* unconditionally. If the write failed the shopkeeper
was told money had been handed over while the ledger never recorded it — a
supplier paid in reality with the books disagreeing, and not even a log line,
because the exception was discarded rather than passed to `logSecureError`. Now
awaited, logged, and the toast is gated on success; the sheet stays open with
the amount intact so the entry can be retried.

### Expense sheet wrote twice on a double-tap

The only save flow in the app with no in-flight guard. The button stayed live
across the `await`, so two taps inside the network window created two `Expense`
records with different ids, silently under-reporting net profit by the full
amount. Added a `saving` flag set before the first await, matching the five
sibling flows that already had one.

### Two screens could strand the user on an infinite spinner

- **Customer khata** nested three streams with `error: (_, __) => null` —
  identical to `loading`. A permission error, dropped connection or missing index
  left one of the four primary tabs spinning forever, with the exception
  discarded rather than even logged. Now distinguishes error from pending,
  logs the cause, and renders a retry that invalidates the streams.
- **Notification settings** set `_loaded` only on success and had no `try` at
  all, so any throw left a bare `CircularProgressIndicator` — with no AppBar and
  no way out. Now loads through a guarded path, and the loading state keeps the
  real overlay chrome so the back button always exists.

Root cause worth noting: the design system shipped `EmptyState`, `NoResults` and
`LoadingScreen` but **no error state**, so four screens each hand-rolled a
file-private `_ErrorBox` (none with a retry). Added a shared `ErrorState` to
`lib/widgets/design_system/states.dart` and used it for the new paths. The four
private copies are left in place — consolidating them is a separate cleanup.

### CSV formula injection

`_sanitizeCsvCell` existed but was applied to the **Items column only**. The
Customer column and the shop-name header are equally user-controlled and
reached the file raw. A customer named `=cmd|'/C calc'!A0` executes when the
shopkeeper opens the exported report in Excel. Now sanitised, with a regression
test asserting an ordinary name like `Ali Raza` is left byte-identical.

## Verified

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | **No issues found** |
| `flutter test` | **249/249 pass** (220 originally; +29) |
| Firestore rules vs emulator | **31/31 pass** (26 + 5 paywall) |
| `flutter test integration_test -d emulator-5554` | **7/7 pass on the real device** |
| `flutter build apk --release` (no key) | **now REFUSES** — verified it fails |
| `flutter build apk --release -PallowDebugSigning=true` | built, 66.9 MB — verified |
| `flutter build appbundle --release` | built, 66.1 MB |
| Install on Pixel 4 emulator | Success (re-verified after the idempotency + khata fixes) |
| Cold launch (release) | Renders dashboard with live Firestore data |
| logcat: FATAL / setState-after-dispose / E/flutter / overflow | **none** |
| Drift test mutation check | Reverting `??=` to `=` correctly **fails** the suite |

### UI verification — how the gap was actually closed

`adb input tap` does not register in this emulator session, so the tap-driven
walkthrough stayed blocked. Rather than leave it, the on-device
`integration_test/export_e2e_test.dart` was run through
`flutter test integration_test -d emulator-5554`, which drives the real app on
the real device through the Flutter driver. **7/7 passed**, covering the report
export round-trip end to end (each report file generated for real, reopened and
parsed) including the empty-filename rejection by the native side.

That is genuine on-device UI coverage, but it is not the same as a manual
screenshot walkthrough of every screen. That part remains unverified.

## Blocked — not verified, do not assume

| Item | Why | Manual action |
|---|---|---|
| Rules deployed to production | Needs `firebase login`; the emulator cannot deploy | Paste the `settings` block below, then `firebase deploy --only firestore:rules` |
| **Founder / paid entitlement** | The app can no longer grant it — that is the fix | `node scripts/grant_entitlement.mjs free_forever` per founder account, or a Cloud Function on verified payment |
| Production signing | Passwords are not in the repo by design; `RELEASE.md` states the identity cannot be recovered from a clone | Set `KEYSTORE_PATH`/`KEYSTORE_PASSWORD`/`KEY_ALIAS`/`KEY_PASSWORD`, then `flutter build apk --release` |
| FCM end-to-end | No Firebase Console access from this environment | Send a test notification from the console |
| Google Sign-In OAuth | Repo-root `google-services.json` has empty `oauth_client` arrays; `android/app/google-services.json` is healthy. The stray root copy is a decoy — copying it to `android/app/` silently breaks sign-in. | Delete root copy; confirm an Android **and** a Web OAuth client exist; add SHA-1 for every signing key |
| Manual screenshot walkthrough of every screen | On-device integration tests pass, but no tap-driven visual pass was possible | Re-run on a responsive emulator session, or a physical device |
| Upgrade test from a prior release | No older APK available locally | Install a previous version, then upgrade over it |

## Known limitations left in place (documented, not hidden)

- **A user can still void a sale and then delete it.** This is narrower than the
  previous state, not gone. The `sales` rule now refuses to delete a **live**
  sale (`allow delete: if isOwner(userId) && resource.data.is_voided == true`),
  so a stray client call, a bad retry, or a stolen token cannot make a real
  day's revenue disappear in one unaudited step — removal has to pass through
  the void, which is the same transaction a cancellation already uses.
  `delete_account_sheet.dart` was updated to void every sale before deleting, so
  shopkeepers can still erase their own data (previously this flow would have
  stranded the account half-deleted on the first live sale).
  What remains open: a user who voids and *then* deletes leaves no record, so
  this is not an audit trail. Genuinely append-only needs a callable
  `deleteAccount` Cloud Function using the Admin SDK, which bypasses rules
  entirely.
- **The rules test suite was order-dependent and only passed on a clean
  emulator.** Tests reuse document ids (`p1`, `s1`, `c1`), and because `set()`
  on an existing document is an *update* rather than a create, leftover state
  silently changed which rule was under test — two tests ('sale create',
  'cost price history create') failed against a warm emulator while passing in
  isolation. A `test.beforeEach` now calls `env.clearFirestore()`. Separately,
  `scripts/rules_test_package.json` was never a conventional `package.json`, so
  `npm install` had nothing to read; a real `scripts/package.json` now exists.
- **Line items are not validated server-side.** No iteration construct exists in
  the rules language. `SaleLineItem.fromMap` throws on a bad line, so the guard
  is client-side only. Pinned by a test asserting the current behaviour, so it
  cannot drift unnoticed.
- **Subscription paywall is client-side** (`foundingAccountEmails` in
  `lib/utils/constants.dart`) and self-editable. Needs a server-side entitlement
  decision.
- **`READ_EXTERNAL_STORAGE` is declared but never used.** Not removed, to avoid
  touching a shipped permission set without a device test of the save path.
- **No App Check**, so a leaked API key is the only barrier to direct REST calls.

## Local housekeeping — owner decision required (not actioned)

Found during the audit, deliberately **not** actioned because both remedies are
destructive and unrecoverable, and neither is a code defect:

1. **`run.txt` / `run3.txt` in the repo root contain a real Firebase UID**
   (a `Notifying id token listeners about user ( K7zGP2DC… )` line). They are
   untracked and correctly ignored by `.gitignore:78` (`run*.txt`), and are
   **not in git history** — verified. The exposure is latent, not active: a UID
   is a low-value identifier on its own, but it becomes directly usable if
   paired with a leaked ID token. They are local dev logs and may still be
   useful for debugging, so they were not deleted.

2. **~130 stale `refs/cline/checkpoints/*` refs** from earlier sessions. None
   are ancestors of `origin/main` and none are in a tag, so nothing was ever
   published. They would be published by a `git push --all` or a `--mirror`
   backup.

   ```powershell
   # Review first:
   git for-each-ref --format='%(refname) %(committerdate:short)' refs/cline/
   # Only if you are sure you need no session rollback:
   git for-each-ref --format='%(refname)' refs/cline/ |
     ForEach-Object { git update-ref -d $_ }
   ```

   Left in place because these refs are the only rollback points for those
   sessions. Removing them is the owner's call, not the agent's.

---

## Previous work

## Goal
Harden the Flutter Foam Shop POS (`com.asif.foamshop`, v1.5.4+7) for production while
preserving POS behaviour, fix the Android notification icon, and resolve the
emulator startup hang.

## Completed

### Notification icon (visually verified)
- The launcher icon was being used for notifications, which Android renders as a
  solid blob in the status bar.
- Added a dedicated monochrome `android/app/src/main/res/drawable/ic_stat_foam_shop.xml`
  (white foreground, transparent background, 24dp) so the system can tint it.
- Added `android/app/src/main/res/values/colors.xml` with the accent colour.
- Manifest now advertises the three FCM `meta-data` entries
  (`default_notification_icon`, `default_notification_color`,
  `default_notification_channel_id` = `foam_shop_general`).
- **Verified against the shipped release APK**, not just the source tree:
  `aapt2 dump xmltree app-release.apk` shows the metadata resolving to
  `ic_stat_foam_shop` (`0x7f080078`) and `notification_color` (`0x7f060053`).
- **Verified visually on device.** The notification shade renders a white receipt
  silhouette in a blue accent circle, and the collapsed status bar shows the same
  glyph next to the app name. It is clearly distinct from the launcher logo.
- Guarded by `test/notification_icon_config_test.dart` and
  `integration_test/notification_icon_device_test.dart`.

### Startup hang
- `AuthService.initialize()` was awaited unbounded *before* `runApp`, so a stalled
  Firebase call left the user on a blank splash forever.
- `lib/main.dart` now caps startup at 8 seconds and `AuthService` surfaces a
  retryable failure instead of hanging. Confirmed: the release build goes
  straight to the sign-in screen.

### Other hardening
- Android notification permission handling moved to the notification settings
  screen, with recovery UI when the permission is permanently blocked.
- Non-blocking haptics for cart actions, sale success/failure, and destructive
  actions (`lib/utils/haptics.dart`).
- Confirmation dialog before clearing the cart.
- Audit found no committed secrets, no WebView/HTML injection surface, and
  tenant-scoped Firestore rules with idempotency protection.

### Launcher icon (visually verified on device)

The home screen and app drawer were still showing Flutter's stock launcher mark
while the sign-in screen already showed the new Foam Shop `BrandMark` — the
product read as two different apps. The launcher icon is now derived from that
same `BrandMark`.

- Adaptive icon for API 26+ (`mipmap-anydpi-v26/ic_launcher.xml` and
  `ic_launcher_round.xml`) with three layers: a full-bleed brand gradient
  background, the mark in the foreground, and a monochrome layer for Android
  13+ themed icons.
- The artwork is placed inside the central **72dp**, not mapped across the full
  108dp canvas. The launcher owns the mask; a naive 0.68 × 108 mapping put the
  inner rule's corners outside it and they were clipped. At 72dp the rule is
  48.96dp wide and its corners sit 34.6dp from centre — inside the 36dp
  inscribed circle — so it survives both a squircle and a circular mask.
- The background is deliberately **not** pre-rounded. Legacy launchers that show
  the bitmap as-is need the BrandMark's own 0.32 radius, but an adaptive
  background that bakes in a radius gets cut twice by the launcher's mask.
- Colours are the app's existing `brandFillDeep` / `brandFill` tokens, declared
  in `res/values/colors.xml` rather than hard-coded a second time in XML.
- Legacy pre-API-26 PNGs regenerated at all five densities (plus round
  variants), because adaptive icons do not exist below API 26 and those devices
  would otherwise have kept the stock mark.
- `android:roundIcon` wired up in the manifest.
- 19 regression tests in `test/launcher_icon_config_test.dart`. The
  load-bearing one re-derives the foam glyph from `_FoamGlyphPainter` in
  `brand_mark.dart` by parsing its real coefficients and compares them to the
  vector path, so the two copies of the mark cannot silently drift. Verified by
  mutation: perturbing one coordinate in the XML failed both the drift guard and
  the monochrome-consistency guard.

### Release builds were broken: `integration_test` in the release classpath

`flutter build apk --release` **and** `flutter build appbundle --release` both
failed outright:

```
GeneratedPluginRegistrant.java:54: error: package
  dev.flutter.plugins.integration_test does not exist
```

The two halves are each individually correct, which is why nothing looked wrong:

- The Java registrant is generated by the Dart tool and referenced
  `integration_test`.
- The Flutter **Gradle** plugin deliberately omits dev-dependency plugin modules
  from the release classpath. `PluginHandler.configurePluginProject` only adds
  `${buildType}Api` when `dev_dependency` is false **or** the buildType is not
  `release`, so `integration_test` is on the classpath for debug and absent for
  release — by design.

Source references a class the release compile cannot see. Fixed by deleting the
generated file so the release build rewrote it correctly; both artefacts then
built.

**The file is gitignored, so this is an ordering hazard, not a bad commit.**
It is rewritten by nearly every `flutter` invocation, and `flutter test` runs in
a non-release context and puts `integration_test` straight back in. Verified:
running the full suite rewrote the file from 4368 to 4642 bytes and re-added the
entry, so the very next release build could consume the poisoned copy.

Pinned by `test/android_release_config_test.dart`, which guards where
`integration_test` is *declared* in `pubspec.yaml` rather than the generated
artefact — the artefact churns on every command and would fail for reasons
unrelated to the source. **Mutation-tested**: moving `integration_test` into
runtime `dependencies` fails the guard; the test also asserts it is *not* in the
runtime block, since that would silently compile a test-only plugin into every
shipped APK.

> If a release build ever fails this way, the remedy is:
> `rm android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`

## Verification status
- `flutter analyze --no-pub` — no issues.
- `dart format --set-exit-if-changed .` — clean (99 files, 0 changed).
- `flutter test` — 192/192 passed.
- Debug and release APKs build; release runs under R8 without crashing.
- Emulator: `Pixel_4`, Android 16 / API 36, 1080x2280, density 440, x86_64,
  launched with host GPU acceleration.

## Known issues

### P1 — `firebase_messaging` is not installed
There is no FCM client in the app, so the manifest metadata added above is
correct and will be honoured, but **no real FCM delivery has been tested** and
none is possible without a Firebase Console project and a device token. Decide
whether push is actually required before adding the dependency. If it is, the
matrix still to cover is: foreground, background, terminated, data-only,
notification+data, tap navigation, duplicate suppression, channel resolution, and
icon rendering.

### P1 — Release signing is not configured
`android/key.properties` is absent, so the release build falls back to debug
signing and must not be uploaded to a store. Create an upload keystore, point
`key.properties` at it, then rebuild and verify the signature before shipping.

### P2 — Google sign-in works; verified on device with a real account
`com.asif.foamshop` was cold-installed and signed in with a real Google account
on the `Pixel_4` AVD. Play Services is present, the account chooser lists the
account, and Firebase issued a user (`d8deYuPe58ZW8SNzVRVQEgPLmf32`). The
dashboard then loaded live Firestore data (Taha Foam Center — Rs 22,500 cash,
1 sale, COGS Rs 19,500, gross profit Rs 3,000).

The "sign-in not working" report was **not** an auth failure. Auth succeeded in
roughly two seconds. What the user actually hit was the ~20 second Firestore
shop-profile fetch that follows, which rendered as a blank white page with a
small unlabelled spinner. That reads as a crash, so a shopkeeper taps again —
and repeat taps trip the 5-per-minute limiter in `AuthService`, turning a slow
but successful load into a hard "too many attempts" failure.

Fixed by adding a branded, labelled `LoadingScreen` to the design system and
using it for both `AuthGate` loading branches. Verified on device: offline the
loader reads "Setting up your shop"; restoring the network completes to the
dashboard with no user action. Covered by `test/loading_state_test.dart`
(9 tests). The full product -> sale -> payment -> receipt -> history -> restart
flow still needs a walkthrough.

### P3 — Notification permission is not granted on a fresh install
`flutter test` installs a fresh APK, which resets `POST_NOTIFICATIONS`, so the
integration test's post is silently dropped and the run still passes green.
This is documented in the test itself. It also means **on a real first install
the shop sees no notifications until the permission is granted from the settings
screen** — worth confirming that path reads clearly to a shopkeeper.

### Outstanding validation
- ~~Release AAB build.~~ **Done** — `app-release.aab` 65.2 MB, exit 0. Release APK
  also rebuilt, 65.9 MB, exit 0. Both debug-signed via
  `-PallowDebugSigning=true`; see the P1 signing issue below.
- Upgrade testing across versions.
- Offline / retry testing.
- Complete PDF visual regression.
- Sound, vibration, and light/dark status-bar appearance on a physical device.
