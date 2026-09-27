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
  /// focusable widget in the tree — the product search field.
  ///
  /// That is why the field accepted exactly one edit and then jumped: clear the
  /// "0", type "5", and the caret teleported out to "Search products…".
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
    final isBelowCost = hasValidPrice && salePrice < costPrice;
    final qty = widget.item.quantity;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: isBelowCost
          ? BoxDecoration(
              color: ac.expenseTint.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ac.expenseFg, width: 1.2),
            )
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: ac.inventoryTint,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.inventory_2_rounded,
                size: 18, color: ac.inventoryFg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
              const SizedBox(height: 4),
              // `crossAxisAlignment: center` so the label, the now 48-tall price
              // field and the qty caption share one optical centre line. The
              // field being taller than the text would otherwise sit low and
              // drag the row's balance off.
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text('Sale price $csym',
                    style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
                const SizedBox(width: 6),
                SizedBox(
                  // Was 68x30 — below the 48dp touch minimum, and too small to
                  // read a 5-6 digit price without pinching to zoom. The price
                  // is the single most-typed value on this screen, so it gets a
                  // full-size target and a bigger font.
                  width: 96,
                  height: 48,
                  child: TextField(
                    controller: _priceCtrl,
                    focusNode: _priceFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 9,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature('tnum')],
                        color: isBelowCost ? ac.expenseFg : ac.saleFg),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      filled: true,
                      fillColor: cs.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: hasValidPrice && !isBelowCost
                              ? ac.saleFg.withValues(alpha: 0.4)
                              : cs.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: hasValidPrice && !isBelowCost
                              ? ac.saleFg.withValues(alpha: 0.4)
                              : cs.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: isBelowCost ? ac.expenseFg : ac.saleFg),
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
                const SizedBox(width: 6),
                Text('\u00d7 $qty',
                    style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
              ]),
            ]),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => ref
                .read(salesProvider.notifier)
                .removeFromCart(widget.item.product.id),
            child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: Text('\u2715',
                    style: TextStyle(fontSize: 11, color: ac.inkFaint))),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
                color: ac.surfaceHigh, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _StepperButton(
                label: '\u2212',
                onTap: () => ref
                    .read(salesProvider.notifier)
                    .changeQty(widget.item.product.id, -1),
              ),
              Container(
                width: 24,
                alignment: Alignment.center,
                child: Text('$qty',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: cs.onSurface)),
              ),
              _StepperButton(
                label: '+',
                onTap: qty < p.currentStock
                    ? () => ref
                        .read(salesProvider.notifier)
                        .changeQty(widget.item.product.id, 1)
                    : null,
              ),
            ]),
          ),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('TOTAL',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: ac.inkFaint,
                    letterSpacing: 0.04)),
            Text('$csym ${total.toInt()}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    fontFeatures: const [FontFeature('tnum')],
                    color: hasValidPrice ? ac.saleFg : cs.onSurface)),
          ]),
        ]),
        if (isBelowCost)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: ac.expenseFg),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Below cost price ($csym ${costPrice.toInt()}) \u2014 this line is a loss',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: ac.expenseFg),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _StepperButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ac.glassFill,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: ac.glassBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: onTap == null ? ac.inkFaint : cs.onSurface)),
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

  @override
  void dispose() {
    _paidCtrl.dispose();
    _paidDebounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
                Text(
                    '${p.sizeLength.toStringAsFixed(0)}in \u00d7 ${p.sizeWidth.toStringAsFixed(0)}in \u00b7 ${p.thickness.toStringAsFixed(0)}in \u00b7 ${p.currentStock.toInt()} in stock',
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ])),
          const SizedBox(width: 8),
          Text(
              '$csym ${NumberFormat('#,##0').format(p.effectivePrice.toInt())}',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: ac.saleFg,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: outOfStock ? ac.surfaceHigh : ac.saleTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add_rounded,
                size: 14, color: outOfStock ? ac.inkFaint : ac.saleFg),
          ),
        ]),
      ),
    );
  }

  Future<void> _save({required bool isQuote}) async {
    if (_saving) return;
    _saving = true;
    try {
      final t0 = DateTime.now();
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
      debugPrint(
          '[Save] getProductsByIds: ${DateTime.now().difference(t0).inMilliseconds}ms');
      if (!mounted) return;
      final productMap = {for (final p in products) p.id: p};

      final belowCostItems = state.cart.where((c) {
        final prod = productMap[c.product.id];
        return prod != null && c.salePrice > 0 && c.salePrice < prod.costPrice;
      }).toList();
      if (belowCostItems.isNotEmpty && !isQuote) {
        _saving = false;
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
        _saving = true;
      }

      final subtotal = state.subtotal;
      final paid = double.tryParse(_paidCtrl.text) ?? 0;
      final balance = (subtotal - paid).clamp(0, double.infinity);

      String customerId = state.customerId;
      String customerName = state.customerName;
      if (balance > 0 && customerId.isEmpty) {
        final walkInId = svc.generateId();
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

      final saleId = svc.generateId();
      final sale = Sale(
        id: saleId,
        date: DateTime.now(),
        customerId: customerId,
        customerName: customerName,
        lineItems: lineItems,
        paid: paid,
        isQuote: isQuote,
      );

      final t1 = DateTime.now();
      if (!isQuote) {
        final deductions = <String, double>{};
        for (final c in state.cart) {
          deductions[c.product.id] = c.quantity.toDouble();
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
      debugPrint(
          '[Save] Firestore write: ${DateTime.now().difference(t1).inMilliseconds}ms');
      debugPrint(
          '[Save] Total save: ${DateTime.now().difference(t0).inMilliseconds}ms');
      if (!mounted) return;

      ref.invalidate(accountingSummaryProvider);
      final custName = state.customerName;
      ref.read(salesProvider.notifier).clearCart();
      _paidCtrl.text = '0';

      if (mounted) {
        final csym2 = ref.read(currencySymbolProvider);
        final savedSale = sale;
        SuccessSheet.show(
          context: context,
          title: isQuote ? 'Quote saved' : 'Sale saved',
          subtitle:
              '$csym2 ${NumberFormat('#,##0').format(subtotal.toInt())} \u00b7 $custName',
          primaryLabel: 'New Sale',
          secondaryLabel: 'View Receipt',
          onSecondary: () => Navigator.push(
              context, slideUpRoute(ReceiptPreviewScreen(sale: savedSale))),
        );
      }
    } finally {
      _saving = false;
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
                          // Was "Walk-in also available Â· Change customer", which
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
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ac.purchaseTint,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: ac.purchaseFg.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: ac.surface,
                              borderRadius: BorderRadius.circular(9)),
                          child: Icon(Icons.info_outline_rounded,
                              size: 14, color: ac.purchaseFg),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Step 1: Enter the sale price first. Step 2: Then increase quantity if selling more than one \u2014 the total updates automatically.',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ac.purchaseFg,
                                height: 1.4),
                          ),
                        ),
                      ]),
                ),
                const SizedBox(height: 14),
                SectionLabel(
                    title: 'Cart \u00b7 ${salesState.totalItems} items'),
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
                              '$csym ${NumberFormat('#,##0').format(salesState.subtotal.toInt())}'),
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
                                  '$csym ${NumberFormat('#,##0').format(salesState.subtotal.toInt())}',
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
                                    Text('Balance',
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
                                      child: Text('$csym ${balance.toInt()}',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              fontFeatures: const [
                                                FontFeature('tnum')
                                              ],
                                              color: balance > 0
                                                  ? ac.expenseFg
                                                  : ac.saleFg)),
                                    ),
                                  ]),
                            ),
                          ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          flex: 2,
                          child: AppButton(
                            label: _saving
                                ? 'Saving\u2026'
                                : 'Save Sale \u00b7 $csym ${salesState.subtotal.toInt()}',
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
                value: '$csym ${fmt.format(item.salePrice.toInt())} /pc',
                valueColor: ac.expenseFg,
              ),
              MiniRow(
                label: 'Cost price',
                value: '$csym ${fmt.format(cost.toInt())} /pc',
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
