# Changelog

## v2.0.0 — September 2026

- Changed: **New visual identity.** The entire theme is now built on a deep blue / periwinkle / dusty mauve palette — Deep Ink `#0E0D15`, Deep Navy `#182346`, Slate Blue `#3D5387`, Muted Periwinkle `#7C83AD`, Dusty Mauve `#BFA9BA`. This replaces the previous teal/indigo/coral scheme. Color tokens only — no layout, typography, navigation, or business-logic changes.
- Changed: Primary, secondary, and accent colors across all Material components (buttons, inputs, chips, dialogs, sheets, navigation, snackbars, tooltips)
- Changed: Semantic domain colors (Sale, Purchase, Expense, Profit, Inventory, Khata, Cash) recolored into the new blue/mauve family while keeping their meaning distinguishable
- Improved: Light and dark themes are now both fully defined by the palette, with derived surface layers for clearer depth in dark mode
- Improved: Hero card, bottom sheets, glass surfaces, navigation indicator, and dialogs now use palette-derived colors instead of hardcoded values
- Improved: CI release APKs are now named `Foam Shop Pos v<version>.apk` for easier download from the Releases page

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
