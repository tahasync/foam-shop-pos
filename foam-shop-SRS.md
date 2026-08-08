# Software Requirements Specification (SRS)
## Foam Shop — Digital Register Mobile App

**Version:** 2.0 (adds Google account login + cloud backup/multi-device sync)
**Platform:** Android & iOS (Flutter)
**Prepared for:** Foam/Mattress/Sponge Retail Shop Management

---

## 1. Introduction

### 1.1 Purpose
This document specifies the requirements for a mobile application that digitizes the day-to-day bookkeeping of a foam/mattress/sponge retail shop, replacing the shop's existing Excel-based "Digital Register Dashboard." The app manages sales, purchases, customer/supplier credit ledgers (khata), inventory (including custom-cut sizing), expenses, and profit tracking — with data backed up to the owner's Google account so it's never lost and is accessible from any device.

### 1.2 Scope
The app is a mobile application with:
- Google Sign-In as the login method (no separate username/password system)
- Cloud storage of all business data tied to the signed-in Google account
- Automatic restore of all data when logging into the same Google account on a new/different device
- Offline usability in-store, with sync happening automatically when internet is available
- Full sales/purchase/khata/inventory/expense/dashboard functionality as previously scoped

It will **not** in v1 include: multiple staff accounts with separate permissions, multi-shop/branch support, or online payment collection. These are noted as future enhancements (Section 8).

### 1.3 Intended Audience
Shop owner/staff (primary user), and the developer implementing the app (Claude Code / OpenCode agent).

### 1.4 Definitions
| Term | Meaning |
|---|---|
| Baqaya | Outstanding balance/credit owed |
| Khata | Ledger/account (customer or supplier) |
| Kharcha | Expense |
| Shuru ka Capital | Opening/starting capital balance |
| Aaj ki Sale | Today's sale |
| Recovery | Collecting a payment against outstanding baqaya |
| UID | Unique user ID assigned by Google/Firebase after sign-in, used to scope all data to that account |

---

## 2. Overall Description

### 2.1 Product Perspective
Mobile app replacing a Google Sheets–based register, now with cloud-backed storage instead of purely local storage — so the shop's data lives safely under the owner's own Google account and is portable across devices.

### 2.2 User Characteristics
Non-technical shop owner/staff, Roman Urdu + English mixed vocabulary in UI (labels like "Baqaya," "Khata," "Kharcha" kept as-is, not translated).

### 2.3 Operating Environment
Android/iOS phones, 5–6 inch screens, used in-store with intermittent internet (offline-capable, syncs when connection returns).

### 2.4 Assumptions & Dependencies
- Single currency: PKR
- Owner has (or will create) a Google account to sign into the app
- Shop sells a mix of piece-based items (e.g. ready-made pillows) and area-based custom-cut items (foam/mattress sheets sold by length × width)
- Internet connection is intermittent, not guaranteed — app must remain usable offline and sync later

---

## 3. Functional Requirements

### FR-0: Authentication & Cloud Backup (NEW in v2)
- FR-0.1: On first launch, user is prompted to **Sign in with Google**.
- FR-0.2: All business data (products, customers, suppliers, sales, purchases, expenses, payments, opening balance) is stored in the cloud, scoped to the signed-in Google account's UID.
- FR-0.3: If the user signs into the app on a **different device** using the **same Google account**, all previously entered data automatically appears — no manual export/import needed.
- FR-0.4: App works fully offline for day-to-day use (adding sales, checking inventory, etc.); any changes made offline sync to the cloud automatically once internet is available.
- FR-0.5: User can sign out; on sign-out, locally cached data is cleared from the device (cloud copy remains safe under their Google account).
- FR-0.6: If two devices are used before syncing (e.g. owner's phone + a staff phone), the most recent recognized write wins per record — no manual conflict merge UI in v1 (documented as a known limitation, see Section 8).

### FR-1: Product & Inventory Management
- FR-1.1: User can add a product with: name, type (Foam/Mattress/Sponge/Pillow/Custom Cut), size (length × width), thickness, density, unit type (per piece or per sq.ft), unit price, current stock, low-stock threshold.
- FR-1.2: User can edit/delete a product.
- FR-1.3: User can restock a product (add quantity or area to current stock), logged as a Purchase record tied to a supplier.
- FR-1.4: System automatically deducts sold quantity/area from stock on each sale.
- FR-1.5: System flags products where remaining stock ≤ low-stock threshold, shown on Dashboard and Inventory screen.
- FR-1.6: User can search/filter inventory by name, type, or low-stock status.

### FR-2: Sales Entry
- FR-2.1: User selects a customer (autocomplete from existing, or add new) and a product.
- FR-2.2: If product is "per sq.ft," user enters custom length and width; system calculates area = length × width.
- FR-2.3: If product is "per piece," user enters quantity directly.
- FR-2.4: System auto-calculates amount = area (or qty) × unit price.
- FR-2.5: User enters amount paid; system auto-calculates balance = amount − paid.
- FR-2.6: On save, system deducts stock and updates customer's running balance if balance > 0.
- FR-2.7: Date defaults to today but is editable (for back-dated entries).

### FR-3: Customer Khata (Ledger)
- FR-3.1: Each customer has a running ledger showing all sales, all recovery payments, and current outstanding balance.
- FR-3.2: User can view a filtered history by customer, date range.

### FR-4: Customer Recovery
- FR-4.1: User can select a customer with outstanding baqaya and record a payment collected.
- FR-4.2: System updates the customer's running balance and the day's "Cash Received" total.

### FR-5: Supplier Khata & Purchases
- FR-5.1: Each supplier has a running ledger of purchases (restocks) and payments made, with current outstanding balance (amount the shop owes the supplier).
- FR-5.2: User can record a supplier payment, reducing the outstanding balance.

### FR-6: Expense Tracking
- FR-6.1: User can log an expense with date, category (e.g. cutting labor, transport, electricity, packaging), description, and amount.
- FR-6.2: System aggregates expenses by day/month/year for dashboard reporting.

### FR-7: Billing / Receipts
- FR-7.1: User can generate a printable/shareable PDF receipt for any sale, showing product name, cut dimensions (if applicable), qty/area, price, amount paid, and balance.
- FR-7.2: Receipt includes shop name and date.

### FR-8: Dashboard
- FR-8.1: Dashboard displays, for a selected date (default today):
  - Sales: Total Sales, Aaj ki Sale, Is Month ki Sale, Cash Received, Customer Baqaya
  - Purchases: Total Purchases, Supplier Paid, Supplier Baqaya
  - Expenses: Total Kharcha (daily/monthly/yearly)
  - Net Profit: Total Profit, Cash in Hand
  - Inventory Alert: Low Stock Items count, Total Items, Total Stock Value, Categories count
  - Opening Balance (Shuru ka Capital)
- FR-8.2: All figures are computed live from underlying records — no duplicate/stored totals that can go stale.

### FR-9: Opening Balance
- FR-9.1: User can set/edit the shop's opening capital, used as the baseline for Cash in Hand calculation.

---

## 4. Data Requirements

Entities: Product, Customer, Supplier, Sale, Purchase, Expense, Payment (customer recovery), SupplierPayment, OpeningBalance — every record additionally scoped by the signed-in user's UID.

**Storage architecture:**
- **Cloud store:** Cloud Firestore (or Firebase Realtime Database), one document tree per user UID.
- **Local cache:** Firestore's built-in offline persistence handles the local cache automatically — no separate SQLite layer needed, since Firestore is designed for exactly this offline-then-sync pattern.
- **Auth:** Firebase Authentication with Google Sign-In provider.

(Full field-level schema is provided in the companion OpenCode prompt document.)

---

## 5. Core Business Rules / Formulas

| Rule | Formula |
|---|---|
| Area (for cut-to-order items) | `Length × Width` |
| Sale Amount | `Area × Price-per-sq.ft` OR `Qty × Unit Price` |
| Balance | `Amount − Paid` |
| Remaining Stock | `Previous Stock − Qty/Area Sold` (+ restocked amounts) |
| Cash in Hand | `Opening Capital + Total Cash Received − Total Kharcha − Total Supplier Paid` |
| Total Profit | `Total Sales − Total Purchase Cost − Total Kharcha` |
| Low Stock Flag | `Remaining Stock ≤ Low Stock Threshold` |

---

## 6. Non-Functional Requirements

- **NFR-1 (Performance):** Dashboard and list screens must load in under 1 second for up to ~5,000 records (typical for a small shop over several years), using cached data first and syncing in the background.
- **NFR-2 (Offline-first):** App must be fully functional with no internet connection; unsynced changes queue and sync automatically once connectivity returns.
- **NFR-3 (Data durability):** All data is durably stored in the cloud under the user's Google account — device loss/reset does not lose business data.
- **NFR-4 (Usability):** UI must be usable by a non-technical shop owner; large touch targets, minimal steps to log a sale (the most frequent action). Sign-in should be a single tap ("Sign in with Google").
- **NFR-5 (Localization):** Roman Urdu business terms (Baqaya, Khata, Kharcha, Shuru ka Capital) retained in UI, not translated to English.
- **NFR-6 (Data integrity):** Deleting a product/customer/supplier that has existing transaction history should be prevented or require confirmation (soft-delete/archive recommended over hard delete).
- **NFR-7 (Security):** Firestore security rules must restrict each user's data so it is only readable/writable by that authenticated UID — no user can access another user's shop data.
- **NFR-8 (Account portability):** Signing into the app with the same Google account on any device must restore the full data set with no manual steps beyond signing in.

---

## 7. Screens Summary

0. **Sign In** (Google Sign-In) — shown on first launch / after sign-out
1. Dashboard
2. Sales Entry
3. Customer Khata
4. Customer Recovery
5. Billing (Receipt generation)
6. Supplier Khata
7. Inventory (with Restock action)
8. Expense Sheet
9. Account/Settings (shows signed-in Google account, sign-out option, opening balance edit)

---

## 8. Future Enhancements (Out of Scope for v1)
- Proper multi-user roles (owner vs staff) with permission levels, rather than one shared Google account
- Conflict-resolution UI for simultaneous edits across devices (v1 uses last-write-wins)
- Multi-shop / branch management
- WhatsApp/SMS notifications for low stock or due baqaya (could integrate with existing n8n automation setup)
- Barcode scanning for products
- Manual "export to Excel/CSV" for accountant sharing

---

## 9. Acceptance Criteria (v1 "done" definition)
- User can sign in with Google on first launch
- All 9 screens functional with full CRUD where applicable
- Data entered on Device A appears automatically on Device B after signing into the same Google account
- Dashboard figures always match manually-recalculated totals from raw records
- A sale for a "per sq.ft" product correctly deducts area-based stock
- App usable fully offline; changes sync automatically once online again
- A receipt can be generated and shared as PDF for any sale
- Firestore security rules verified to block cross-account data access
