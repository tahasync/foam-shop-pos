# Release body for v1.5.6

Paste the block between the two marker comments into the GitHub release body
when publishing v1.5.6. The in-app "What's New" dialog reads the release body,
so the notes are written for shop owners and kept free of maintainer details.

<!-- RELEASE BODY START -->

### Improved

- **Foam Shop has a new, consistent brand.** The app icon, launch screen, sign-in mark, receipt preview, printed receipt, and shared report PDF now use the Foam Layers identity and the navy, slate, periwinkle, mauve, and foam palette.

- **Receipts are easier to scan.** The preview and printed copy share a clearer customer card, aligned item columns, legible balance labels, payment status, and a compact branded header.

- **Reports are easier to share and work with.** PDF reports have a branded summary and paginated sales table. XLSX reports contain styled Summary and Sales Detail sheets with numeric values that keep their precision. CSV reports open cleanly in spreadsheet apps and separate the summary from sale rows.

### Fixed

- **A sale can no longer be changed into a quote after it is saved.** Firestore rules keep the sale classification and financial details immutable, and validate the shape of sale line items at the server boundary. Sale writes continue to use Firestore transactions and remain compatible with the Firebase Spark plan.

<!-- RELEASE BODY END -->

### Maintainer details

- The brand kit is copied verbatim to `design/brand/` and is not bundled as app assets.
- Export colors share `BrandPalette`; CSV values retain decimals, and XLSX monetary cells remain numeric.
- Firestore deployment is rules-only. This release does not add or deploy Cloud Functions.
- `flutter analyze --no-pub`, `dart format --set-exit-if-changed .`, and the 329 host tests pass. No emulator checks were run.
