/// Canonical money rounding and formatting for the whole app.
library;

import 'package:intl/intl.dart';

import 'currency.dart';

///
/// ## Why this exists
///
/// Every monetary figure in this app is a `double`. Before this module, each
/// display site called `.toInt()` on it, and `double.toInt()` **truncates toward
/// zero** — it does not round. A cart of three lines at Rs 100.50 each has a
/// real total of Rs 301.50, and the printed receipt showed:
///
/// ```text
///   Foam A   1   @ 100     100
///   Foam B   1   @ 100     100
///   Foam C   1   @ 100     100
///   TOTAL                  301
/// ```
///
/// Three printed lines of 100 do not sum to 301. A receipt that does not add up
/// is not a cosmetic bug in a POS — it is the cashier being unable to reconcile
/// the bill in front of the customer. Truncation also silently biased every
/// total *downwards*, so a shop systematically under-reports revenue.
///
/// The same bug hits the other direction: `.toInt()` truncates negatives toward
/// zero as well, so a credit or refund of -0.5 printed as "0".
///
/// ## The policy
///
/// Money is rounded to **whole currency units, half away from zero**, and it is
/// rounded **once, at the point where a number becomes a displayed figure**.
/// It is never rounded mid-calculation.
///
/// Half-away-from-zero is Dart's `num.round()`. It is not banker's rounding
/// (HALF_EVEN), which would send 2.5 to 2 and 3.5 to 4; for a shopkeeper's
/// money, "5 paisa rounds up" is the least surprising rule and matches what
/// `[round()]` does on a calculator.
///
/// Whole units, not 2 decimal places, because that is what the app has always
/// displayed (`NumberFormat('#,##0')`) and what these shops price in. Changing
/// the display precision to two decimals would be a much larger change to the
/// product's look than the bug warrants.
///
/// ## Rounding is a display concern, not a storage one
///
/// Stored sales, payments and expenses keep their full `double` value. Nothing
/// here is written back to Firestore. The rounding that matters is the one the
/// customer reads, and for the overwhelmingly common case of whole-rupee prices
/// and whole-unit quantities, [roundMoney] is a no-op.

/// Rounds [value] to a whole currency unit, half away from zero.
///
/// Non-finite input (`NaN`, `Infinity`) and null collapse to `0` rather than
/// propagating: a corrupt document must render as a zero on a receipt, not as
/// the literal text "NaN" in front of a customer.
int roundMoney(num? value) {
  if (value == null) return 0;
  final v = value.toDouble();
  if (v.isNaN || v.isInfinite) return 0;
  // `+ 0.0` normalises -0.0 to 0.0, so a rounded credit never prints "-0".
  return v.round() + 0;
}

/// [roundMoney] kept as a `double`, for arithmetic on already-rounded figures
/// (for example, summing rounded line items to build a receipt subtotal).
double roundMoneyTo(num? value) => roundMoney(value).toDouble();

/// Formats [value] as a whole-currency amount with thousands separators, using
/// the rounding policy above. No currency symbol — callers that want one should
/// pair this with [currencySymbolFromCode] so the symbol is written exactly
/// once, as the existing receipts already do.
String formatMoney(num? value, {String? locale}) {
  final rounded = roundMoney(value);
  return NumberFormat('#,##0', locale).format(rounded);
}

/// [formatMoney] prefixed with the currency symbol for [currencyCode].
String formatMoneyWithSymbol(num? value,
    {required String currencyCode, String? locale}) {
  return '${currencySymbolFromCode(currencyCode)} ${formatMoney(value, locale: locale)}';
}
