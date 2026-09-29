import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/firebase_providers.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../providers/shop_provider.dart';
import '../utils/debounce.dart';
import '../widgets/initial_avatar.dart';
import '../utils/safe_error_handler.dart';
import '../widgets/design_system/design_system.dart';
import '../widgets/add_customer_sheet.dart';
import '../utils/animations.dart';
import 'billing_screen.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../utils/haptics.dart';
import '../utils/money.dart';

/// The note denominations a customer is likely to hand over.
///
/// Ordered smallest first. Deliberately not a free "any round number" control:
/// these are the values that actually come out of a pocket or a cash drawer, so
/// the offered set is short enough to hit blind, without aiming.
const List<double> kChangeSteps = [100, 500, 1000, 5000, 10000];

/// The amounts worth offering as "the customer handed me this" for a bill of
/// [subtotal].
///
/// Cash in this market is round. A Rs 69,000 bill is settled with a Rs 70,000
/// note essentially every time, and that Rs 70,000 used to be typed by hand,
/// digit by digit, with the customer standing there. The exact total comes
/// first so "paid in full, no change" is also one tap.
///
/// Round-ups are only offered when they are *plausible*: a step is skipped if it
/// lands on the bill exactly (nothing to give back), and one is skipped if the
/// change would exceed half the bill — a Rs 900 bill rounded to Rs 5,000 is not
/// a change of Rs 4,100, it is a different transaction.
///
/// Steps that reach the same figure are collapsed, so a bill that rounds up to
/// Rs 70,000 via both the 1,000 and the 5,000 step offers that amount once.
List<double> quickPaidOptions(double subtotal) {
  if (subtotal <= 0) return const [];
  final options = <double>{subtotal};
  for (final step in kChangeSteps) {
    // The epsilon absorbs the float error that would otherwise turn a bill of
    // exactly 69,000 into an offer of "70,000" via `69000 / 1000 = 69.000001`.
    final rounded = (subtotal / step).ceilToDouble() * step;
    if (rounded - subtotal <= 0.005) continue; // lands on the bill: no change
    if ((rounded - subtotal) > subtotal / 2) continue; // absurd as change
    options.add(rounded);
  }
  final sorted = options.toList()..sort();
  return sorted;
}

class CartWidget extends ConsumerStatefulWidget {
  final CartItem item;
  const CartWidget({super.key, required this.item});

  @override
  ConsumerState<CartWidget> createState() => _CartWidgetState();
}

class _CartWidgetState extends ConsumerState<CartWidget> {
  late final TextEditingController _priceCtrl;

  /// The price field's focus, owned here so it survives a rebuild.
  ///
  /// This field has no `FocusNode` of its own, and it sits inside a list that
  /// rebuilds on every keystroke: `onChanged` calls `setState` and then
  /// `updateItemPrice`, which republishes the cart and rebuilds the whole
  /// screen. Without a stable node the `TextField`'s element is discarded and
  /// rebuilt, focus is dropped, and the platform hands it to the next
  /// focusable widget in the tree ? the product search field.
  ///
  /// That is why the field accepted exactly one edit and then jumped: clear the
  /// "0", type "5", and the caret teleported out to "Search products?".
  late final FocusNode _priceFocus;

  @override
  void initState() {
    super.initState();
    _priceCtrl =
        TextEditingController(text: widget.item.salePrice.toStringAsFixed(0));
    _priceFocus = FocusNode();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final p = widget.item.product;
    final total = widget.item.lineTotal;
    final csym = ref.watch(currencySymbolProvider);
    final costPrice = p.costPrice;
    final salePrice = double.tryParse(_priceCtrl.text) ?? 0;
    final hasValidPrice = salePrice > 0;
    final hasCost = costPrice > 0;
    final isBelowCost = hasValidPrice && hasCost && salePrice < costPrice;
    final qty = widget.item.quantity;
    final fmt = NumberFormat('#,##0');

    // How far under cost this line is, per unit and across the whole line. The
    // rupee figure is the one a person can act on while a customer waits; the
    // old "-832%" margin was arithmetically correct and practically useless.
    final unitShort = isBelowCost ? costPrice - salePrice : 0.0;
    final lineShort = unitShort * qty;
    final marginPct = hasValidPrice && hasCost
        ? (((salePrice - costPrice) / salePrice) * 100).round()
        : null;

    // One word of state per line. Kept as plain values here so the chip below
    // and the loss notice cannot disagree about what this line is doing.
    final statusFg = !hasValidPrice
        ? ac.inkSoft
        : isBelowCost
            ? ac.expenseFg
            : hasCost
                ? ac.saleFg
                : ac.inkSoft;
    final statusBg = isBelowCost
        ? ac.expenseTint
        : hasValidPrice && hasCost
            ? ac.saleTint
            : ac.surfaceHigh;
    final statusIcon = !hasValidPrice
        ? Icons.edit_outlined
        : isBelowCost
            ? Icons.trending_down_rounded
            : Icons.trending_up_rounded;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      // The decoration must NEVER be `null` when this is not below cost.
      //
      // `Container` only emits a `DecoratedBox` when `decoration != null`, so
      // toggling between `null` and a `BoxDecoration` inserted a new widget
      // between this `Container` and its `Padding` child. Flutter could not
      // match `Padding` against `DecoratedBox`, so it deactivated the entire
      // subtree and built a fresh one ? taking the focused price `TextField`
      // with it. The replacement inherited an already-focused `FocusNode`, so
      // focus was never re-acquired, no new `TextInputConnection` was opened,
      // and the field silently swallowed every keystroke after the first one.
      // On a Pixel 9 that meant "20500" was impossible to type: the field kept
      // its focused border but only ever received one digit.
      //
      // A `BoxDecoration` with no colour and no border paints nothing, so
      // keeping it non-null is visually identical while holding the tree shape
      // ? and therefore the text field and its IME connection ? steady.
      decoration: BoxDecoration(
        // A 5% wash, not 25%. The old block of colour turned the whole row into
        // a red slab that shouted at the same volume as the margin number beside
        // it, so nothing on the line had a clear priority. The loss state is
        // carried by a hairline plus the notice at the bottom, which is where the
        // eye actually goes.
        color: isBelowCost ? ac.expenseTint.withValues(alpha: 0.05) : null,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: isBelowCost
            ? Border.all(
                color: ac.expenseFg.withValues(alpha: 0.45), width: 1.2)
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ---- identity row -------------------------------------------------
        // Name and stock on the left, remove on the right, and nothing else.
        // The old build put the name, the price field, the running total and
        // the close button all on one 40-tall row ? four competing things in a
        // strip that cannot grow, so "PER UNIT" wrapped away from its field and
        // the total was pushed off the right edge on any narrow phone.
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: ac.inventoryTint,
                borderRadius: BorderRadius.circular(AppRadii.sm)),
            child: Icon(Icons.inventory_2_rounded,
                size: 18, color: ac.inventoryFg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: ac.ink)),
              const SizedBox(height: 2),
              // Cost and stock on one quiet sub-line. This is the context that
              // decides whether a price is safe, and it used to be invisible:
              // the only cost signal on the card appeared *after* a mistake had
              // already been made.
              Text(
                hasCost
                    ? '$csym ${fmt.format(roundMoney(costPrice))} cost \u00b7 ${p.stockLabel} in stock'
                    : 'No cost price set \u00b7 ${p.stockLabel} in stock',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: hasCost ? ac.inkFaint : ac.expenseFg),
              ),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          // The old control was a bare 24x24 InkWell around a "\u2715" glyph, so
          // the entire tappable area was a fifth of the 48dp minimum the rest of
          // the app holds itself to. It is the one control a user reaches for
          // when a line is wrong, and it is the easiest to miss.
          //
          // The `InkWell` itself is the full 48x48 and the chip is centred
          // inside it. Padding a SizedBox *around* the InkWell would have been
          // the easy mistake here ? the extra space would then sit outside the
          // tappable widget and the target would still measure 28x28.
          Semantics(
            button: true,
            label: 'Remove $qty \u00d7 ${p.name} from cart',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                onTap: () {
                  ref
                      .read(salesProvider.notifier)
                      .removeFromCart(widget.item.product.id);
                  unawaited(AppHaptics.tap());
                },
                child: SizedBox(
                  width: AppHit.min,
                  height: AppHit.min,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: ac.surface2,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: ac.outline),
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 15, color: ac.inkFaint),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),

        // ---- control row --------------------------------------------------
        // Price and quantity side by side, both full height, sharing one
        // baseline. The field takes whatever width the stepper does not need,
        // so it is no longer capped at 96dp and a 6-digit price cannot clip.
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // "PRICE PER UNIT", not a derived "PRICE PER SQ.FT".
              //
              // The label used to read `unitLabel`, which resolves to "sq.ft" for
              // every product — `unitType` is hardcoded to 'per_sqft' when a
              // product is created and `Product.fromMap` defaults to it when the
              // field is absent, and nothing in the UI ever sets it to 'pcs'.
              // So the caption asserted a square-foot basis the shop does not
              // sell on, directly above a stock count reading "15 pcs". A
              // caption that contradicts the line beneath it is worse than no
              // caption: it states the unit basis, and states it wrongly.
              //
              // "Unit" is what the shop actually sells by, and it stays correct
              // if `unitType` ever becomes user-selectable.
              Text('PRICE PER UNIT',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: ac.inkFaint)),
              const SizedBox(height: AppSpacing.xs),
              // Was 68x30 \u2014 below the 48dp touch minimum, and too small to read
              // a 5-6 digit price without pinching to zoom. The price is the
              // single most-typed value on this screen, so it gets a full-size
              // target and a bigger font.
              SizedBox(
                height: AppHit.min,
                child: TextField(
                  controller: _priceCtrl,
                  focusNode: _priceFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 9,
                  textAlign: TextAlign.left,
                  // Select-all on focus. Without it, tapping the field to correct
                  // a price put the caret between two digits of the old value, so
                  // typing appended to a stale number instead of replacing it ?
                  // the single most common way a price ends up wrong.
                  onTap: () => _priceCtrl.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _priceCtrl.text.length,
                  ),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature('tnum')],
                      color: isBelowCost ? ac.expenseFg : ac.saleFg),
                  decoration: InputDecoration(
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    filled: true,
                    // Tinted when the line is under cost, so the field itself
                    // carries the warning rather than only the card behind it.
                    fillColor: isBelowCost
                        ? ac.expenseTint.withValues(alpha: 0.10)
                        : cs.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      borderSide: BorderSide(
                        color: hasValidPrice && !isBelowCost
                            ? ac.saleFg.withValues(alpha: 0.4)
                            : cs.outlineVariant,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      borderSide: BorderSide(
                        color: hasValidPrice && !isBelowCost
                            ? ac.saleFg.withValues(alpha: 0.4)
                            : cs.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      borderSide: BorderSide(
                          color: isBelowCost ? ac.expenseFg : ac.saleFg,
                          width: 1.6),
                    ),
                  ),
                  onChanged: (val) {
                    final newPrice = double.tryParse(val) ?? 0;
                    setState(() {});
                    ref
                        .read(salesProvider.notifier)
                        .updateItemPrice(widget.item.product.id, newPrice);
                    // `updateItemPrice` republishes the cart and rebuilds this
                    // row, so re-assert focus afterwards instead of letting it
                    // fall through to the next focusable in the tree.
                    if (!_priceFocus.hasFocus) _priceFocus.requestFocus();
                  },
                ),
              ),
            ]),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('QUANTITY',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: ac.inkFaint)),
            const SizedBox(height: AppSpacing.xs),
            // 48 tall so the stepper clears the touch minimum on its own,
            // instead of relying on two 24x24 buttons wedged inside a 32-tall
            // track. It shares the field's baseline, so the two controls read
            // as one row rather than two stacked bands.
            Container(
              height: AppHit.min,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                  color: ac.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppRadii.sm)),
              // The hairline goes in `foregroundDecoration`, not `decoration`.
              //
              // A border in `decoration` is painted *inset* and `Container`
              // reserves a matching 1px `padding` for it, which silently
              // shrank the stepper's 48x48 hit areas to 46x46 ? under the
              // touch minimum this track exists to honour. A foreground
              // decoration paints the same line without touching layout.
              foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: ac.outline)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _StepperButton(
                  label: '\u2212',
                  semanticLabel: 'Decrease quantity of ${p.name}',
                  onTap: () => ref
                      .read(salesProvider.notifier)
                      .changeQty(widget.item.product.id, -1),
                ),
                // Wide enough that a two- or three-digit quantity cannot clip
                // against the steppers. At 24 it became unreadable exactly when
                // the order was large enough to matter.
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text('$qty',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          fontFeatures: const [FontFeature('tnum')],
                          color: ac.ink)),
                ),
                _StepperButton(
                  label: '+',
                  semanticLabel: 'Increase quantity of ${p.name}',
                  onTap: qty < p.currentStock
                      ? () => ref
                          .read(salesProvider.notifier)
                          .changeQty(widget.item.product.id, 1)
                      : null,
                ),
              ]),
            ),
          ]),
        ]),
        const SizedBox(height: AppSpacing.md),
        Container(height: 1, color: ac.outline),
        const SizedBox(height: AppSpacing.md),
        // ---- summary row --------------------------------------------------
        // The money this line actually contributes, at display weight on the
        // right, with the state of the line on the left. This used to read
        // "= Rs 2,200" crammed against the price field, restating an
        // arithmetic the user had to do from two numbers in two rows.
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // A status pill rather than a bare "MARGIN" heading over a number.
          // "MARGIN -832%" was loud, arithmetically correct, and useless: a
          // margin that far negative just means "well below cost", which the
          // rupee shortfall below says directly and actionably.
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 5),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusIcon, size: 12, color: statusFg),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    !hasValidPrice
                        ? 'Price not set'
                        : isBelowCost
                            ? 'Below cost'
                            : !hasCost
                                ? 'No cost set'
                                : '${marginPct! >= 0 ? '+' : ''}$marginPct% margin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: statusFg),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            hasValidPrice ? '$csym ${fmt.format(roundMoney(total))}' : '\u2014',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature('tnum')],
              color: hasValidPrice ? ac.ink : ac.inkFaint,
            ),
          ),
        ]),
        if (isBelowCost) ...[
          const SizedBox(height: AppSpacing.md),
          // The shortfall in rupees, plus a one-tap way to correct it. A warning
          // with no action leaves the user to remember the cost price and retype
          // it; "Use cost" is one tap and it makes the decision explicit, so a
          // deliberate discount is still one tap away.
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: ac.expenseTint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: ac.expenseFg),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        qty > 1
                            ? 'Losing $csym ${fmt.format(roundMoney(lineShort))} on this line'
                            : 'Losing $csym ${fmt.format(roundMoney(unitShort))} on this line',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ac.expenseFg),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        // "per unit" for the same reason as the field caption above.
                        'Cost is $csym ${fmt.format(roundMoney(costPrice))} per unit.',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: ac.expenseFg.withValues(alpha: 0.85)),
                      ),
                    ]),
              ),
              const SizedBox(width: AppSpacing.sm),
              // A compact text target rather than a filled button: this is a
              // shortcut, not the primary action, and a solid button here would
              // out-shout the total it is correcting.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                  onTap: () {
                    _priceCtrl.text = costPrice.toStringAsFixed(0);
                    ref
                        .read(salesProvider.notifier)
                        .updateItemPrice(widget.item.product.id, costPrice);
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    child: Text('Use cost',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ac.expenseFg,
                            decoration: TextDecoration.underline,
                            decorationColor: ac.expenseFg)),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.label,
    required this.semanticLabel,
    this.onTap,
  });

  /// `'\u2212'` or `'+'`. Kept as a string so the two call sites read
  /// identically; the glyph itself is drawn as an icon (see below).
  final String label;

  /// Announced by screen readers. A bare "\u2212" / "+" is announced as
  /// "minus" / "plus" with no indication of *what* it steps, so a
  /// non-sighted user hears two identical, contextless buttons per line.
  final String semanticLabel;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final enabled = onTap != null;
    // The glyph is drawn directly, but the tappable region is padded out to the
    // 48dp minimum. Adjacent steppers stay 48 apart at the edges, so a thumb
    // aiming for "+" cannot land on "\u2212" and silently decrement a sale.
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          onTap: onTap,
          child: SizedBox(
            width: AppHit.min,
            height: AppHit.min,
            child: Center(
              // Icons rather than "-" and "+" text: the font's hyphen sits
              // optically high and the plus reads thin and small, so the pair
              // looked like two different, mismatched buttons. `Icons.remove` and
              // `Icons.add` are drawn on the same optical baseline at any scale.
              child: Icon(
                label == '\u2212' ? Icons.remove_rounded : Icons.add_rounded,
                size: 19,
                color: enabled ? ac.ink : ac.inkFaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A one-off coaching hint the user can dismiss for the session.
///
/// Kept deliberately quiet ? a tinted card with a dismiss control ? because it
/// is an instruction, not content. The point is to unblock a first-time user and
/// then get out of the way, so the close affordance is a full 48dp target rather
/// than a small ? that nobody finds.
class DismissibleHint extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const DismissibleHint({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: ac.purchaseTint,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: ac.purchaseFg.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: ac.surface, borderRadius: BorderRadius.circular(9)),
            child: Icon(Icons.info_outline_rounded,
                size: 14, color: ac.purchaseFg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              // Nudged down so the body copy is optically centred against the
              // 28px icon instead of hanging off its top edge.
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                message,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ac.purchaseFg,
                    height: 1.4),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: onDismiss,
              child: SizedBox(
                width: AppHit.min,
                height: AppHit.min,
                child: Icon(Icons.close_rounded,
                    size: 16, color: ac.purchaseFg.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SalesEntryScreen extends ConsumerStatefulWidget {
  /// Bottom space reserved for the floating nav pill. Supplied by
  /// `HomeScreen.contentBottomInset` so every tab agrees.
  final double bottomInset;

  const SalesEntryScreen({super.key, this.bottomInset = 120});
  @override
  ConsumerState<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends ConsumerState<SalesEntryScreen> {
  final _paidCtrl = TextEditingController(text: '0');
  final _paidDebounce = Debouncer();
  final _searchCtrl = TextEditingController();
  bool _saving = false;

  /// Session-stable id for the walk-in customer created by a credit sale.
  ///
  /// Held across save attempts so a retry overwrites the same document instead
  /// of creating a second orphan customer. Reset whenever the cart is cleared,
  /// so the next sale gets its own walk-in.
  String? _pendingWalkInId;

  /// Idempotency key for the sale currently being entered.
  ///
  /// Minted on the first save attempt and REUSED on every retry, so a retry
  /// after a lost response re-uses the same document id and the server-side
  /// existence check turns it into a no-op instead of a duplicate sale.
  ///
  /// Cleared in exactly two places, both of which mean "this is no longer the
  /// same sale": after a confirmed success, and when the cart is explicitly
  /// cleared. It is deliberately NOT cleared in the `catch` block - a failed
  /// attempt is precisely the case that must keep the key.
  String? _pendingSaleId;

  /// Whether the user has dismissed the "Step 1 / Step 2" explainer.
  ///
  /// Session-scoped rather than persisted: a returning user who already knows the
  /// flow should never see it again, and writing a preference to storage to
  /// remember a dismissal is not worth the I/O for a purely cosmetic hint.
  bool _hintDismissed = false;

  @override
  void dispose() {
    _paidCtrl.dispose();
    _paidDebounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Fills the Paid field from a quick-change chip.
  ///
  /// Writing through the controller's `text` does NOT fire the field's
  /// `onChanged`, so the surrounding `setState` has to be explicit or the Change
  /// box and the balance would keep showing the previous figure. The debouncer
  /// is cancelled for the same reason: its pending timer would land *after* this
  /// setState and rebuild with a stale value.
  void _applyQuickPaid(double amount) {
    _paidDebounce.cancel();
    _paidCtrl.text = amount.toStringAsFixed(0);
    setState(() {});
  }

  Future<Customer?> _addNewCustomerFromDialog() async {
    return showAddCustomerSheet(context, ref);
  }

  void _changeCustomer() async {
    final result = await showAppSheet<Customer>(
      context: context,
      builder: (ctx) => _CustomerPickerSheet(
        selectedId: ref.read(salesProvider).customerId,
        onAddCustomer: _addNewCustomerFromDialog,
      ),
    );
    if (result != null && mounted) {
      ref.read(salesProvider.notifier).setCustomer(result.id, result.name);
    }
  }

  List<Product> _filteredProducts(List<Product> products) {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return [];
    return products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  Widget _buildSearchResult(Product p, BuildContext context, ColorScheme cs,
      AppColors ac, String csym) {
    final q = _searchCtrl.text.toLowerCase();
    final idx = p.name.toLowerCase().indexOf(q);
    final outOfStock = p.currentStock <= 0;
    return InkWell(
      onTap: () {
        if (outOfStock) return;
        _searchCtrl.clear();
        setState(() {});
        ref.read(salesProvider.notifier).addToCart(p);
      },
      child: Container(
        // minHeight, not a fixed height: this is the row a user taps most often
        // on the screen, and it was only ~54 tall only by accident of its
        // contents. Pinning the floor to the touch minimum makes the target
        // predictable and stops a short product name producing a cramped row.
        constraints: const BoxConstraints(minHeight: AppHit.min),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 0.5))),
        child: Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: ac.inventoryTint,
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.inventory_2_rounded,
                  size: 15, color: ac.inventoryFg)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                RichText(
                    text: TextSpan(
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface),
                  children: [
                    if (idx >= 0) ...[
                      TextSpan(text: p.name.substring(0, idx)),
                      TextSpan(
                          text: p.name.substring(idx, idx + q.length),
                          style: TextStyle(
                              background: Paint()..color = ac.saleTint,
                              color: ac.saleFg,
                              fontWeight: FontWeight.w800)),
                      TextSpan(text: p.name.substring(idx + q.length)),
                    ] else
                      TextSpan(text: p.name),
                  ],
                )),
                const SizedBox(height: 1),
                // An out-of-stock row used to read exactly like an available one and
                // then silently refuse the tap, so the user learned nothing and
                // tapped again. Saying "OUT OF STOCK" in the expense colour makes the
                // reason visible before the tap, which is the only point at which it
                // is useful.
                // The unit was dropped here, so a piece-counted product read
                // "4 in stock" while the restock sheet and the inventory list,
                // one tap away, said "4 pcs". A bare number with no unit is
                // exactly the ambiguity this shop keeps tripping over.
                Text(
                  outOfStock
                      ? '${p.sizeLength.toStringAsFixed(0)}in \u00d7 ${p.sizeWidth.toStringAsFixed(0)}in \u00b7 ${p.thickness.toStringAsFixed(0)}in \u00b7 Out of stock'
                      : '${p.sizeLength.toStringAsFixed(0)}in \u00d7 ${p.sizeWidth.toStringAsFixed(0)}in \u00b7 ${p.thickness.toStringAsFixed(0)}in \u00b7 ${p.stockLabel} in stock',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        outOfStock ? FontWeight.w700 : FontWeight.normal,
                    color: outOfStock ? ac.expenseFg : cs.onSurfaceVariant,
                  ),
                ),
              ])),
          const SizedBox(width: 8),
          Text(
              '$csym ${NumberFormat('#,##0').format(roundMoney(p.effectivePrice))}',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  // Greys the price on an unavailable row so the whole row reads as
                  // disabled rather than just the trailing "+".
                  color: outOfStock ? ac.inkFaint : ac.saleFg,
                  decoration: outOfStock ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: ac.inkFaint,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 8),
          // Was a 24x24 container holding a 14px "+". Below the 48dp minimum, and
          // on the row the user taps most often. The `InkWell` is the full 48 tall
          // with the visible pill centred inside it ? padding outside the InkWell
          // would leave the real target at 28.
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: outOfStock
                  ? null
                  : () {
                      _searchCtrl.clear();
                      setState(() {});
                      ref.read(salesProvider.notifier).addToCart(p);
                      // Light tap: adding a line changes the bill, which is the
                      // thing the cashier is watching while they type. Paired
                      // with the line appearing in the cart.
                      unawaited(AppHaptics.tap());
                    },
              child: SizedBox(
                width: AppHit.min,
                height: AppHit.min,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: outOfStock ? ac.surfaceHigh : ac.saleTint,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Icon(Icons.add_rounded,
                        size: 16, color: outOfStock ? ac.inkFaint : ac.saleFg),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// "Clear all" emptied the cart with a single tap and no confirmation.
  ///
  /// On a multi-line sale a mis-tap next to the cart heading wiped a bill the
  /// cashier had already keyed in item by item, and the only way back was to
  /// re-enter it. It is now a deliberate two-step action, and the destructive
  /// confirm carries an error haptic so the finger feels the difference between
  /// "discard this work" and "tap a chip".
  Future<void> _confirmClearCart() async {
    final state = ref.read(salesProvider);
    if (state.cart.isEmpty) return;

    final count = state.totalItems;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear the whole cart?'),
        content: Text(
          'This removes all $count item${count == 1 ? '' : 's'} from this '
          'sale. Nothing has been saved yet, so the amounts will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep cart'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear cart'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    unawaited(AppHaptics.error());
    ref.read(salesProvider.notifier).clearCart();
    _paidCtrl.clear();
    // The cart is gone, so the next save is a different sale and must not
    // inherit this cart's idempotency key.
    _pendingSaleId = null;
    _pendingWalkInId = null;
  }

  Future<void> _save({required bool isQuote}) async {
    if (_saving) return;
    _saving = true;
    // Rebuild immediately so the button shows "Saving…" and disables itself.
    // The guard alone stops a double tap, but without this the cashier gets no
    // feedback at all during the write and taps again out of uncertainty.
    if (mounted) setState(() {});
    try {
      final state = ref.read(salesProvider);
      if (state.cart.isEmpty) return;
      if (!isQuote && state.cart.any((c) => c.salePrice <= 0)) {
        _saving = false;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Enter a sale price for all items before saving.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final svc = ref.read(firestoreServiceProvider);
      final cartProductIds = state.cart.map((c) => c.product.id).toSet();
      final products = await svc.getProductsByIds(cartProductIds);
      if (!mounted) return;
      final productMap = {for (final p in products) p.id: p};

      // Every cart line must resolve to a live product. A line that does not is
      // one whose stock the transaction could not be checked against, and whose
      // cost price would be written as 0 — silently overstating profit forever.
      // Failing here is the honest outcome: nothing is written.
      final missingProducts = state.cart
          .where((c) => !productMap.containsKey(c.product.id))
          .map((c) => c.product.name)
          .toList();
      if (missingProducts.isNotEmpty && !isQuote) {
        logSecureError(
          'Sale blocked: cart products not found in inventory: '
          '$missingProducts',
          StackTrace.current,
          tag: 'save_sale',
        );
        _saving = false;
        if (!mounted) return;
        showAppToast(
          context,
          missingProducts.length == 1
              ? '${missingProducts.first} is no longer in your inventory.'
              : 'Some cart items are no longer in your inventory. Review the cart.',
        );
        return;
      }

      final belowCostItems = state.cart.where((c) {
        final prod = productMap[c.product.id];
        return prod != null && c.salePrice > 0 && c.salePrice < prod.costPrice;
      }).toList();
      if (belowCostItems.isNotEmpty && !isQuote) {
        // The in-flight guard is deliberately NOT released here.
        //
        // It used to be set false before the sheet and re-armed after, which
        // re-enabled the Save button for the whole time the sheet was open. A
        // second tap then re-entered _save with the cart still populated (the
        // cart is only cleared after a successful write), minted a second sale
        // id, and committed a second sale - charging the customer twice and
        // deducting the stock twice. A modal dialog must never be a window in
        // which the same action can start again.
        if (!mounted) return;
        final csym = ref.read(currencySymbolProvider);
        final proceed = await showAppSheet<bool>(
          context: context,
          builder: (ctx) => _BelowCostSheet(
            items: belowCostItems,
            productMap: productMap,
            csym: csym,
          ),
        );
        if (proceed != true) return;
        if (!mounted) return;
      }

      final subtotal = state.subtotal;
      final paid = double.tryParse(_paidCtrl.text) ?? 0;
      final balance = (subtotal - paid).clamp(0, double.infinity);

      String customerId = state.customerId;
      String customerName = state.customerName;
      if (balance > 0 && customerId.isEmpty) {
        // A stable id for the whole cart session.
        //
        // This used to mint a fresh random id on every attempt, and the customer
        // was created with a separate, non-transactional `set` BEFORE the sale
        // transaction. So any failure - flaky network, stock race, permission -
        // left an orphan "Walk-in" customer behind, and because the failure
        // invites a retry, a cashier who tapped Save three times left three
        // such customers with no sales against them. They are undeletable, they
        // pollute the customer list, and they inflate the receivables report.
        //
        // Reusing one id across retries makes the write an overwrite of the same
        // document, so a retry is idempotent and a failure is harmless.
        final walkInId = _pendingWalkInId ??= svc.generateId();
        final now = DateTime.now();
        final timeLabel =
            '${now.day}/${now.month}/${now.year} ${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')}${now.hour < 12 ? 'AM' : 'PM'}';
        final walkInName = 'Walk-in \u00b7 $timeLabel';
        final walkIn = Customer(id: walkInId, name: walkInName, phone: '');
        await svc.addCustomer(walkIn);
        customerId = walkIn.id;
        customerName = walkIn.name;
      }

      final lineItems = state.cart.map((c) {
        final prod = productMap[c.product.id];
        return SaleLineItem(
          productId: c.product.id,
          name: c.product.name,
          qtyOrArea: c.quantity.toDouble(),
          salePrice: c.salePrice,
          costPriceAtSale: prod?.costPrice ?? 0,
        );
      }).toList();

      // The idempotency key for this cart, minted ONCE and reused on every
      // retry.
      //
      // It has to be stable across attempts or the whole scheme is decorative.
      // A retry after a lost response re-enters this method, finds the key
      // already set, and reuses it - so `saveSaleTransaction` writes the SAME
      // document path, its `existing.exists` check fires, and the transaction
      // returns without a second write or a second stock decrement.
      //
      // Previously this was a fresh `generateId()` on every attempt, so the key
      // differed each time, the existence check never matched, and a cashier who
      // retried after a dropped connection wrote a SECOND sale and deducted the
      // stock twice. A real loss: money billed twice, inventory gone, and the
      // duplicate could not be deleted. The field was named `transaction_uuid`
      // and the README called it idempotency, but nothing made it one.
      final saleId = _pendingSaleId ??= svc.generateId();
      final sale = Sale(
        id: saleId,
        date: DateTime.now(),
        customerId: customerId,
        customerName: customerName,
        lineItems: lineItems,
        paid: paid,
        isQuote: isQuote,
        // The document ID IS the idempotency key, so the two can never drift
        // apart and the rules' immutability check on it is meaningful.
        transactionUuid: saleId,
      );

      if (!isQuote) {
        // Accumulate with `+=` rather than assign. A map assignment silently
        // keeps only the LAST line for a repeated product id, which would deduct
        // one line's worth of stock while selling two. The UI currently merges
        // duplicate products into one cart line, so this is not reachable today -
        // but it is a silent-wrong-answer failure mode in financial code, and it
        // is exactly the shape a future "same item, different cut size" feature
        // would take. `voidSale` already aggregates with `+=` for the same
        // reason; this makes the two directions agree.
        final deductions = <String, double>{};
        for (final c in state.cart) {
          deductions[c.product.id] =
              (deductions[c.product.id] ?? 0) + c.quantity.toDouble();
        }
        final verifiedStocks = <String, double>{};
        for (final c in state.cart) {
          final prod = productMap[c.product.id];
          if (prod != null) verifiedStocks[c.product.id] = prod.currentStock;
        }
        await svc.saveSaleTransaction(sale, deductions,
            verifiedStocks: verifiedStocks);
      } else {
        await svc.addSale(sale);
      }

      // Confirmed durable on the server, so the keys have done their job.
      // Releasing them here means the NEXT cart mints fresh ones; holding them
      // would make the next, unrelated sale collide with this one and be
      // silently swallowed as a duplicate. This must stay AFTER the awaits
      // above - releasing them in the `catch` block would undo the whole
      // retry-safety property.
      _pendingSaleId = null;
      _pendingWalkInId = null;

      // Clear the cart BEFORE the mounted check.
      //
      // Returning early on an unmounted widget used to leave the cart intact
      // even though the sale was committed. The cashier comes back to a cart
      // representing an already-saved sale and can save it a second time.
      // Clearing cart state is not a context operation, so it is safe to do
      // regardless of whether this widget is still in the tree.
      ref.read(salesProvider.notifier).clearCart();
      _paidCtrl.text = '0';

      if (!mounted) return;

      ref.invalidate(accountingSummaryProvider);
      final custName = state.customerName;

      if (mounted) {
        final csym2 = ref.read(currencySymbolProvider);
        final savedSale = sale;
        // Money the shop has to hand back, stated on the confirmation so the
        // cashier reads it out before the customer leaves. Previously the
        // success sheet only ever confirmed the sale was saved, so an
        // overpayment was discovered later — or not at all.
        final changeGiven = (paid - subtotal).clamp(0, double.infinity);
        final changeNote = changeGiven > 0
            ? ' \u00b7 Change $csym2 ${NumberFormat('#,##0').format(roundMoney(changeGiven))}'
            : '';
        // Medium impact: a sale is the one action in the app that commits money,
        // so it earns the heavier confirmation rather than the light tap used
        // for button presses. Fired alongside the success sheet, never awaited
        // before it, so the UI is not held up by the vibrator.
        unawaited(AppHaptics.success());
        SuccessSheet.show(
          context: context,
          title: isQuote
              ? 'Quote saved'
              : (changeGiven > 0
                  ? 'Sale saved \u00b7 give change'
                  : 'Sale saved'),
          subtitle:
              '$csym2 ${NumberFormat('#,##0').format(roundMoney(subtotal))} \u00b7 $custName$changeNote',
          primaryLabel: 'New Sale',
          secondaryLabel: 'View Receipt',
          onSecondary: () => Navigator.push(
              context, slideUpRoute(ReceiptPreviewScreen(sale: savedSale))),
        );
      }
    } catch (e, st) {
      // This method only had a `finally`, so any Firestore failure — a stock
      // race, a permissions denial, an offline write — escaped as an unhandled
      // async error. The cart survived (nothing was cleared) but the screen gave
      // the user no indication that the sale had not been recorded, and they
      // would reasonably tap Save again. Surface the failure.
      logSecureError(e, st, tag: 'save_sale');
      if (!mounted) return;
      // The sale did NOT persist, so this is a failure, not a tap: give the
      // heavier error feedback so a cashier who taps again immediately knows
      // the first attempt failed rather than having saved a duplicate.
      unawaited(AppHaptics.error());
      showAppToast(
        context,
        sanitizeErrorMessage(e,
            fallback: 'Could not save the sale. Please try again.'),
      );
    } finally {
      // setState so the button actually flips back to "Save Sale". The flag is
      // what blocks a double tap, but without a rebuild the label stayed on
      // "Saving…" forever, which read as a hang on the app's most important
      // action. Guarded because the sheet is dismissible and the widget can be
      // gone by the time an error unwinds here.
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final salesState = ref.watch(salesProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final paid = double.tryParse(_paidCtrl.text) ?? 0;
    final balance = (salesState.subtotal - paid).clamp(0, double.infinity);
    // What the customer handed over beyond the bill, and so what comes back out
    // of the till. Clamped at 0 so an underpayment (or an untouched field) is
    // never shown as a negative "change".
    final change = (paid - salesState.subtotal).clamp(0, double.infinity);
    // The round figures worth one-tapping for this bill. Empty while the cart is
    // empty, so the row does not sit there offering to pay Rs 0.
    final quickPaid = quickPaidOptions(salesState.subtotal);
    final csym = ref.watch(currencySymbolProvider);
    final bottom = widget.bottomInset;

    return GlassScaffold(
      safeBottom: false,
      child: Column(children: [
        AppBarRow(
          showBrand: false,
          title: 'New Sale',
          trailing: [
            AppIconButton(
              icon: Icons.person_outline_rounded,
              foreground: ac.primary,
              onTap: _changeCustomer,
            ),
          ],
        ),
        Expanded(
          child: Builder(
            builder: (context) => ListView(
              padding: EdgeInsets.fromLTRB(18, 0, 18, bottom),
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(12),
                  radius: 18,
                  level: AppGlassLevel.raised,
                  gloss: false,
                  child: Row(children: [
                    InitialAvatar(
                      name: salesState.customerName,
                      size: 40,
                      borderRadius: 13,
                      fontSize: 14,
                      backgroundColor: ac.primaryContainer,
                      foregroundColor: ac.onPrimaryContainer,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(salesState.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: cs.onSurface)),
                          // Was "Walk-in also available \u00b7 Change customer", which
                          // sat directly beside a "Change" button and read as a
                          // duplicated, half-cut label.
                          Text('Tap to select a customer',
                              style: TextStyle(
                                  fontSize: 10.5, color: ac.inkFaint)),
                        ])),
                    const SizedBox(width: 12),
                    AppButton(
                      label: 'Change',
                      variant: AppButtonVariant.outline,
                      fullWidth: false,
                      // Sized as a first-class control, not a caption.
                      //
                      // This was 38 tall with a 12.5px label in 16px of padding:
                      // under the 48dp minimum touch target, and tight enough
                      // that "Change" touched the rounded edge, so it read as a
                      // stray word rather than a button.
                      //
                      // 52 rather than 48 on purpose. The chip sits beside a
                      // 40px avatar and the whole card is also a tap target, so
                      // at exactly 48 the two controls read as the same size
                      // and the row lost its hierarchy. 52 makes the action
                      // unambiguously the larger, primary-ish element.
                      height: 52,
                      fontSize: 14.5,
                      horizontalPadding: 24,
                      onTap: _changeCustomer,
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                SectionLabel(title: 'Select product'),
                productsAsync.when(
                  loading: () => const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator())),
                  error: (e, _) => Center(
                      child: Text('Error: $e',
                          style: TextStyle(color: cs.onSurface))),
                  data: (products) => Column(children: [
                    // The clear button is now part of AppSearchField. The old
                    // hand-rolled Positioned overlay was painted on top of the
                    // glass pill and was missing from the field semantics.
                    AppSearchField(
                      controller: _searchCtrl,
                      hintText: 'Search products\u2026',
                      onChanged: (_) => setState(() {}),
                      onClear: () => setState(() {}),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: ac.glassFill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ac.glassBorder),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(children: [
                          for (final p in _filteredProducts(products))
                            _buildSearchResult(p, context, cs, ac, csym),
                        ]),
                      ),
                    if (_searchCtrl.text.isEmpty &&
                        salesState.recentProductIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: salesState.recentProductIds.map((id) {
                            final p =
                                products.where((x) => x.id == id).firstOrNull;
                            if (p == null) return const SizedBox.shrink();
                            return GestureDetector(
                              onTap: () {
                                if (p.currentStock <= 0) return;
                                ref.read(salesProvider.notifier).addToCart(p);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 5),
                                decoration: BoxDecoration(
                                  color: ac.inventoryTint,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time_rounded,
                                          size: 10, color: ac.inventoryFg),
                                      const SizedBox(width: 4),
                                      Text(p.name,
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: ac.inventoryFg)),
                                    ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ]),
                ),
                if (!_hintDismissed)
                  Column(children: [
                    const SizedBox(height: 10),
                    // The "Step 1 / Step 2" explainer was permanent chrome sitting
                    // between the product picker and the cart, so it pushed the
                    // actual cart ? the thing being edited ? below the fold on a
                    // short screen, and it repeated itself on every single sale to
                    // a user who had long since internalised the two steps.
                    //
                    // It is still the first-run explanation, so it is kept, but it
                    // is now dismissible and the dismissal lasts for the session.
                    DismissibleHint(
                      message:
                          'Step 1: Enter the sale price first. Step 2: Then increase quantity if selling more than one \u2014 the total updates automatically.',
                      onDismiss: () => setState(() => _hintDismissed = true),
                    ),
                  ]),
                const SizedBox(height: 14),
                SectionLabel(
                  // "1 items" was the literal heading on every single-item
                  // sale, which is the most common sale there is. Also worth
                  // a "Clear" escape hatch: previously the only way to empty a
                  // cart was to tap the ? on every line, one mistake at a
                  // time.
                  title:
                      'Cart \u00b7 ${salesState.totalItems} ${salesState.totalItems == 1 ? 'item' : 'items'}',
                  actionLabel: salesState.cart.isEmpty ? null : 'Clear all',
                  onAction: salesState.cart.isEmpty ? null : _confirmClearCart,
                ),
                if (salesState.cart.isEmpty)
                  FoamCard(
                    foam: true,
                    child: EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'No items added yet.',
                      subtitle: 'Tap a product above to add',
                      compact: true,
                    ),
                  )
                else
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    radius: 22,
                    level: AppGlassLevel.raised,
                    gloss: false,
                    child: Column(children: [
                      for (var i = 0; i < salesState.cart.length; i++) ...[
                        if (i > 0)
                          Container(height: 1, color: ac.outlineStrong),
                        CartWidget(
                            key: ValueKey(salesState.cart[i].product.id),
                            item: salesState.cart[i]),
                      ],
                      Container(
                          height: 1,
                          color: ac.outline,
                          margin: const EdgeInsets.symmetric(vertical: 12)),
                      MiniRow(
                          label: 'Subtotal',
                          value:
                              '$csym ${NumberFormat('#,##0').format(roundMoney(salesState.subtotal))}'),
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(color: ac.outline, width: 1.5)),
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total amount',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: ac.inkSoft,
                                      letterSpacing: 0.04)),
                              Text(
                                  '$csym ${NumberFormat('#,##0').format(roundMoney(salesState.subtotal))}',
                                  style: AppTheme.display(context, size: 22)),
                            ]),
                      ),
                      const SizedBox(height: 14),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Paid ($csym)',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurfaceVariant)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _paidCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => _paidDebounce
                                          .call(() => setState(() {})),
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: const [
                                            FontFeature('tnum')
                                          ],
                                          color: cs.onSurface),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                        filled: true,
                                        fillColor: ac.surface2,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide:
                                              BorderSide(color: ac.outline),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide:
                                              BorderSide(color: ac.outline),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide:
                                              BorderSide(color: ac.primary),
                                        ),
                                      ),
                                    ),
                                  ]),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(change > 0 ? 'Change' : 'Balance',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurfaceVariant)),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: ac.surface2,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: balance > 0
                                                ? ac.expenseFg
                                                : ac.outline),
                                      ),
                                      // This box used to always read "Balance 0"
                                      // once the customer overpaid, so the cashier
                                      // was told nothing about the Rs 1,000 they
                                      // had to hand back while the customer waited.
                                      // It now states the change explicitly, in the
                                      // purchase accent, because that money is
                                      // leaving the till rather than being kept.
                                      child: Text(
                                          change > 0
                                              ? '$csym ${change.toInt()}'
                                              : '$csym ${balance.toInt()}',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              fontFeatures: const [
                                                FontFeature('tnum')
                                              ],
                                              color: change > 0
                                                  ? ac.purchaseFg
                                                  : (balance > 0
                                                      ? ac.expenseFg
                                                      : ac.saleFg))),
                                    ),
                                  ]),
                            ),
                          ]),
                      const SizedBox(height: 14),
                      if (quickPaid.isNotEmpty) ...[
                        _QuickPaidRow(
                          options: quickPaid,
                          currentPaid: paid,
                          csym: csym,
                          onSelected: _applyQuickPaid,
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(children: [
                        // Both buttons are `flex: 1`.
                        //
                        // The primary was `flex: 2` and carried a variable-width
                        // label — "Save Sale · Rs 0" grew to "Save Sale · Rs
                        // 118,500" as the total rose. So the secondary's share
                        // shrank *as the sale got bigger*, and "Save as Quote"
                        // ellipsised to "Save as Qu…" on exactly the large sales
                        // where the amount matters most. A layout that degrades
                        // with the data is a layout bug, not a tight fit.
                        //
                        // The amount is dropped from the label: it is already
                        // printed as "Total amount · Rs N" directly above this
                        // row, so repeating it in the button was redundant *and*
                        // was the source of the instability.
                        Expanded(
                          child: AppButton(
                            label: _saving ? 'Saving\u2026' : 'Save Sale',
                            icon: Icons.check_rounded,
                            onTap: (_saving ||
                                    salesState.cart.isEmpty ||
                                    salesState.cart
                                        .any((c) => c.salePrice <= 0))
                                ? null
                                : () => _save(isQuote: false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            label: 'Save as Quote',
                            variant: AppButtonVariant.outline,
                            onTap: (_saving || salesState.cart.isEmpty)
                                ? null
                                : () => _save(isQuote: true),
                          ),
                        ),
                      ]),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/// One-tap amounts for the Paid field, drawn from [quickPaidOptions].
///
/// Tapping "70,000" on a Rs 69,000 bill sets Paid to 70,000 and the Change box
/// immediately reads Rs 1,000 — which is the whole point. Before this, that
/// figure had to be keyed in by hand while the customer waited, and nothing on
/// screen distinguished "the customer owes me" from "I owe the customer".
///
/// The row is scrollable rather than wrapped because the option count varies
/// with the bill, and a wrapping row would change height between sales and
/// shove the Save buttons around while the cashier is reading them.
class _QuickPaidRow extends StatelessWidget {
  /// Ascending, from [quickPaidOptions].
  final List<double> options;

  /// The amount currently in the Paid field, so the matching chip reads as
  /// selected instead of leaving the row looking un-tapped after a manual entry.
  final double currentPaid;
  final String csym;
  final ValueChanged<double> onSelected;

  const _QuickPaidRow({
    required this.options,
    required this.currentPaid,
    required this.csym,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final fmt = NumberFormat('#,##0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Customer hands over',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: ac.inkSoft)),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final amount = options[i];
              // The bill itself is offered first, so "paid in full, no change"
              // is one tap. Only that one is labelled in words; the round-ups
              // read as plain figures, because that is what they are.
              final isExact = i == 0;
              final selected = (currentPaid - amount).abs() < 0.005;
              return _QuickPaidChip(
                label: isExact
                    ? 'Exact $csym ${fmt.format(roundMoney(amount))}'
                    : '$csym ${fmt.format(roundMoney(amount))}',
                selected: selected,
                onTap: () => onSelected(amount),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single quick-amount target.
class _QuickPaidChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickPaidChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? ac.purchaseTint : ac.surface2,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? ac.purchaseFg : ac.outline,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? ac.purchaseFg : ac.inkSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final String selectedId;
  final Future<Customer?> Function() onAddCustomer;
  const _CustomerPickerSheet(
      {required this.selectedId, required this.onAddCustomer});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    return AppSheetContent(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Select Customer',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: cs.onSurface)),
        const SizedBox(height: 12),
        AppSearchField(
          controller: _searchCtrl,
          hintText: 'Search customers\u2026',
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
          onClear: () => setState(() => _query = ''),
        ),
        const SizedBox(height: 4),
        Consumer(builder: (context, ref, _) {
          final customersAsync = ref.watch(customersStreamProvider);
          return customersAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator())),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                  sanitizeErrorMessage(e, fallback: 'Could not load customers'),
                  style: TextStyle(color: cs.onSurface)),
            ),
            data: (customers) {
              final filtered = customers
                  .where((c) =>
                      _query.isEmpty || c.name.toLowerCase().contains(_query))
                  .toList();
              if (filtered.isEmpty) {
                return NoResults(
                  title: 'No customers match',
                  subtitle: 'Try a different search term',
                );
              }
              return Column(children: [
                for (final c in filtered)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context, c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        InitialAvatar(
                          name: c.name,
                          size: 34,
                          borderRadius: 10,
                          fontSize: 12,
                          backgroundColor: c.id == widget.selectedId
                              ? ac.saleTint
                              : ac.primaryContainer,
                          foregroundColor: c.id == widget.selectedId
                              ? ac.saleFg
                              : ac.onPrimaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(c.name,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                        ),
                        if (c.id == widget.selectedId)
                          Icon(Icons.check_rounded, size: 18, color: ac.saleFg),
                      ]),
                    ),
                  ),
              ]);
            },
          );
        }),
        const Divider(height: 18),
        AppButton(
          label: '+ Add Customer',
          variant: AppButtonVariant.outline,
          icon: Icons.person_add_alt_1_rounded,
          onTap: () async {
            final c = await widget.onAddCustomer();
            if (c != null && mounted) Navigator.pop(context, c);
          },
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: AppButton(
              label: 'Walk-in',
              variant: AppButtonVariant.ghost,
              onTap: () => Navigator.pop(
                  context, Customer(id: '', name: 'Walk-in Customer')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Done',
              onTap: () => Navigator.pop(context),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _BelowCostSheet extends StatelessWidget {
  final List<CartItem> items;
  final Map<String, Product> productMap;
  final String csym;
  const _BelowCostSheet(
      {required this.items, required this.productMap, required this.csym});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final fmt = NumberFormat('#,##0');

    return AppSheetContent(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: ac.expenseTint, borderRadius: BorderRadius.circular(12)),
          child:
              Icon(Icons.warning_amber_rounded, size: 20, color: ac.expenseFg),
        ),
        const SizedBox(height: 12),
        Text('Selling below cost price',
            style: AppTheme.display(context, size: 19)),
        const SizedBox(height: 8),
        ...items.map((item) {
          final prod = productMap[item.product.id];
          final cost = prod?.costPrice ?? 0;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.product.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: cs.onSurface)),
              const SizedBox(height: 4),
              MiniRow(
                label: 'Sale price',
                value: '$csym ${fmt.format(roundMoney(item.salePrice))} /pc',
                valueColor: ac.expenseFg,
              ),
              MiniRow(
                label: 'Cost price',
                value: '$csym ${fmt.format(roundMoney(cost))} /pc',
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        Text('This sale will show a loss on these items.',
            style: TextStyle(fontSize: 11, color: ac.inkFaint)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: AppButton(
              label: 'Save Anyway',
              icon: Icons.check_rounded,
              onTap: () => Navigator.pop(context, true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Fix Price',
              variant: AppButtonVariant.outline,
              onTap: () => Navigator.pop(context, false),
            ),
          ),
        ]),
      ]),
    );
  }
}
