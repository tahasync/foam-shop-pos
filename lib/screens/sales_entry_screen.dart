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
import '../widgets/save_success_sheet.dart';
import '../utils/safe_error_handler.dart';
import 'package:flutter/services.dart';

class CartWidget extends ConsumerStatefulWidget {
  final CartItem item;
  const CartWidget({super.key, required this.item});

  @override
  ConsumerState<CartWidget> createState() => _CartWidgetState();
}

class _CartWidgetState extends ConsumerState<CartWidget> {
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.item.salePrice.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  String _buildDims(Product p) {
    final parts = <String>[];
    if (p.sizeLength > 0) parts.add('${p.sizeLength.toStringAsFixed(0)}in');
    if (p.sizeWidth > 0) parts.add('${p.sizeWidth.toStringAsFixed(0)}in');
    if (p.thickness > 0) parts.add('${p.thickness.toStringAsFixed(0)}in');
    return parts.join(' \u00d7 ');
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
    final grey300 = Colors.grey.shade300;
    final grey600 = Colors.grey.shade600;

    Color borderColor = grey300;
    String? flagText;
    Color? flagColor;

    if (isBelowCost) {
      borderColor = ac.expenseFg;
      flagText = 'Below cost price ($csym ${costPrice.toInt()}) \u2014 this line is a loss';
      flagColor = ac.expenseFg;
    } else if (hasValidPrice) {
      borderColor = AppTheme.teal;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isBelowCost || hasValidPrice ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(_buildDims(p),
                  style: TextStyle(fontSize: 13, color: grey600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => ref.read(salesProvider.notifier).removeFromCart(widget.item.product.id),
            child: Container(width: 24, height: 24, alignment: Alignment.center,
                child: Text('\u2715', style: TextStyle(fontSize: 12, color: ac.inkFaint))),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: hasValidPrice && !isBelowCost ? ac.saleTint : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: !hasValidPrice
                      ? cs.outlineVariant
                      : isBelowCost
                          ? ac.expenseFg
                          : ac.saleFg.withValues(alpha: 0.3),
                  width: hasValidPrice ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 9,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature('tnum')], color: isBelowCost ? ac.expenseFg : ac.saleFg),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Input Sale Price',
                  hintStyle: TextStyle(color: ac.inkFaint, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (val) {
                  final newPrice = double.tryParse(val) ?? 0;
                  setState(() {});
                  ref.read(salesProvider.notifier).updateItemPrice(widget.item.product.id, newPrice);
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('/unit', style: TextStyle(fontSize: 12, color: hasValidPrice ? ac.saleFg : cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => ref.read(salesProvider.notifier).changeQty(widget.item.product.id, -1),
                child: Container(width: 32, height: 32, alignment: Alignment.center,
                    child: Text('\u2212', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant))),
              ),
              Container(
                width: 28, alignment: Alignment.center,
                child: Text('$qty', textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: qty < p.currentStock
                    ? () => ref.read(salesProvider.notifier).changeQty(widget.item.product.id, 1)
                    : null,
                child: Container(width: 32, height: 32, alignment: Alignment.center,
                    child: Text('+', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant))),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ac.inkFaint, letterSpacing: 0.04)),
            const SizedBox(height: 1),
            Text('$csym ${total.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                    fontFeatures: [FontFeature('tnum')], color: hasValidPrice ? ac.saleFg : cs.onSurface)),
          ]),
        ]),
        if (hasValidPrice && qty > 1)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: ac.saleTint, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calculate_outlined, size: 12, color: ac.saleFg),
              const SizedBox(width: 5),
              Text('$csym ${salePrice.toInt()} \u00d7 $qty = $csym ${total.toInt()}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ac.saleFg)),
            ]),
          ),
        if (flagText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: flagColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(flagText,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: flagColor)),
              ),
            ]),
          ),
      ]),
    );
  }
}

class SalesEntryScreen extends ConsumerStatefulWidget {
  const SalesEntryScreen({super.key});
  @override
  ConsumerState<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends ConsumerState<SalesEntryScreen> {
  final _paidCtrl = TextEditingController(text: '0');
  final _paidDebounce = Debouncer();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchFocused = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() => _searchFocused = _searchFocus.hasFocus));
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _paidDebounce.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<Customer?> _addNewCustomerFromDialog() async {
    final nc = TextEditingController();
    final pc = TextEditingController();
    final result = await showDialog<Customer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Customer'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nc, decoration: const InputDecoration(labelText: 'Name', filled: true)),
            const SizedBox(height: 8),
            TextField(controller: pc, decoration: const InputDecoration(labelText: 'Phone', filled: true),
                keyboardType: TextInputType.phone),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (nc.text.trim().isEmpty) return;
            final svc = ref.read(firestoreServiceProvider);
            final customer = Customer(
                id: svc.generateId(), name: nc.text.trim(), phone: pc.text.trim());
            Navigator.pop(ctx, customer);
            svc.addCustomer(customer).catchError((e, st) {
              logSecureError(e, st, tag: 'customer_add');
            });
          }, child: const Text('Save')),
        ],
      ),
    );
    nc.dispose();
    pc.dispose();
    return result;
  }

  void _changeCustomer() async {
    final result = await showDialog<Customer>(
      context: context,
      builder: (ctx) => _CustomerPickerDialog(
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

  Widget _buildSearchResult(Product p, BuildContext context, ColorScheme cs, AppColors ac, String csym) {
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
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5))),
        child: Row(children: [
          Container(width: 34, height: 34,
            decoration: BoxDecoration(color: ac.inventoryTint, borderRadius: BorderRadius.circular(9)),
            child: Icon(Icons.inventory_2_rounded, size: 15, color: ac.inventoryFg)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(text: TextSpan(
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface),
              children: [
                if (idx >= 0) ...[
                  TextSpan(text: p.name.substring(0, idx)),
                  TextSpan(text: p.name.substring(idx, idx + q.length),
                      style: TextStyle(background: Paint()..color = ac.saleTint, color: ac.saleFg, fontWeight: FontWeight.w800)),
                  TextSpan(text: p.name.substring(idx + q.length)),
                ] else
                  TextSpan(text: p.name),
              ],
            )),
            const SizedBox(height: 1),
            Text('${p.sizeLength.toStringAsFixed(0)}in \u00d7 ${p.sizeWidth.toStringAsFixed(0)}in \u00b7 ${p.thickness.toStringAsFixed(0)}in \u00b7 ${p.currentStock.toInt()} in stock',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ])),
          const SizedBox(width: 8),
          Text('$csym ${NumberFormat('#,##0').format(p.effectivePrice.toInt())}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: ac.saleFg,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 8),
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: outOfStock ? cs.onSurfaceVariant : AppTheme.teal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add_rounded, size: 14, color: Colors.white),
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
          content: const Text('Enter a sale price for all items before saving.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final svc = ref.read(firestoreServiceProvider);
    final cartProductIds = state.cart.map((c) => c.product.id).toSet();
    final products = await svc.getProductsByIds(cartProductIds);
    debugPrint('[Save] getProductsByIds: ${DateTime.now().difference(t0).inMilliseconds}ms');
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
      final proceed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
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
      final timeLabel = '${now.day}/${now.month}/${now.year} ${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')}${now.hour < 12 ? 'AM' : 'PM'}';
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
      await svc.saveSaleTransaction(sale, deductions, verifiedStocks: verifiedStocks);
    } else {
      await svc.addSale(sale);
    }
    debugPrint('[Save] Firestore write: ${DateTime.now().difference(t1).inMilliseconds}ms');
    debugPrint('[Save] Total save: ${DateTime.now().difference(t0).inMilliseconds}ms');
    if (!mounted) return;

    ref.invalidate(accountingSummaryProvider);
    final itemsCopy = List<CartItem>.from(state.cart);
    final custName = state.customerName;
    final totalItems = state.totalItems;
    ref.read(salesProvider.notifier).clearCart();
    _paidCtrl.text = '0';

    if (mounted) {
      final csym2 = ref.read(currencySymbolProvider);
      SaveSuccessSheet.show(
        context: context,
        title: '${isQuote ? 'Quote' : 'Sale'} Saved',
        subtitle: '$custName \u00b7 $totalItems items',
        items: itemsCopy.map((c) => SheetLineItem(
          label: '${c.product.name} \u00d7 ${c.quantity}',
          value: '$csym2 ${NumberFormat('#,##0').format(c.lineTotal.toInt())}',
        )).toList(),
        paid: paid,
        total: subtotal,
        onPrint: null,
        onNew: () {},
        newLabel: '+ New Sale',
        csym: csym2,
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

    return Scaffold(
      appBar: AppBar(title: const Text('New Sale')),
      body: Builder(builder: (context) => ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 100 + MediaQuery.of(context).padding.bottom),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: ac.saleTint, borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.person_rounded, size: 20, color: ac.saleFg),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(salesState.customerName,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cs.onSurface)),
                Text('Change customer', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ])),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _changeCustomer,
                child: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Select Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant, letterSpacing: 0.06)),
          const SizedBox(height: 8),
          productsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.onSurface))),
            data: (products) => Column(children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _searchFocused ? AppTheme.teal : cs.outlineVariant, width: _searchFocused ? 1.5 : 1),
                  boxShadow: _searchFocused
                      ? [BoxShadow(color: AppTheme.teal.withValues(alpha: 0.12), blurRadius: 8, spreadRadius: 2)]
                      : null,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  decoration: InputDecoration(
                    hintText: 'Search products\u2026',
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: _searchFocused ? AppTheme.teal : ac.inkFaint),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _searchCtrl.clear(); setState(() {}); },
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              width: 18, height: 18,
                              decoration: BoxDecoration(color: ac.saleTint, shape: BoxShape.circle),
                              child: Icon(Icons.close_rounded, size: 12, color: ac.saleFg)),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                    boxShadow: [BoxShadow(color: cs.shadow, blurRadius: 16, offset: const Offset(0, 8))],
                  ),
                  child: Column(children: [
                    for (final p in _filteredProducts(products))
                      _buildSearchResult(p, context, cs, ac, csym),
                  ]),
                ),
              if (_searchCtrl.text.isEmpty && salesState.recentProductIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 7, runSpacing: 7,
                    children: salesState.recentProductIds.map((id) {
                      final p = products.where((x) => x.id == id).firstOrNull;
                      if (p == null) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          if (p.currentStock <= 0) return;
                          ref.read(salesProvider.notifier).addToCart(p);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: ac.inventoryTint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.access_time_rounded, size: 10, color: ac.inventoryFg),
                            const SizedBox(width: 4),
                            Text(p.name, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.inventoryFg)),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ac.purchaseTint, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 14, color: ac.purchaseFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Step 1: Enter the sale price first. Step 2: Then increase quantity if selling more than one \u2014 the total updates automatically.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ac.purchaseFg, height: 1.4)),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Text('Cart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant, letterSpacing: 0.06)),
            if (salesState.totalItems > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: ac.expenseTint, borderRadius: BorderRadius.circular(999)),
                child: Text('${salesState.totalItems}',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ac.expenseFg)),
              ),
          ]),
          const SizedBox(height: 8),
          if (salesState.cart.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Column(children: [
                Icon(Icons.shopping_cart_outlined, size: 36, color: ac.inkFaint),
                const SizedBox(height: 8),
                Text('No items added yet.', style: TextStyle(color: ac.inkFaint, fontSize: 13)),
                Text('Tap a product above to add', style: TextStyle(fontSize: 12, color: ac.inkFaint)),
              ]),
            )
          else
            ...salesState.cart.map((c) => CartWidget(key: ValueKey(c.product.id), item: c)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Subtotal', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                Text('$csym ${salesState.subtotal.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature('tnum')], color: cs.onSurface)),
              ]),
              const Divider(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total Amount', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: cs.onSurface)),
                Text('$csym ${salesState.subtotal.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature('tnum')], color: ac.saleFg)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Paid ($csym)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                TextField(
                  controller: _paidCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _paidDebounce.call(() => setState(() {})),
                  decoration: InputDecoration(
                    hintText: '0',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    filled: true,
                    fillColor: cs.surfaceContainerLowest,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature('tnum')], color: cs.onSurface),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Balance', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: ac.saleTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Text('$csym ${balance.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                            fontFeatures: [FontFeature('tnum')], color: ac.saleFg)),
                  ]),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (salesState.cart.isEmpty || salesState.cart.any((c) => c.salePrice <= 0)) ? null : () => _save(isQuote: false),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: salesState.cart.isEmpty ? null : () => _save(isQuote: true),
            child: Text('Save as Quote',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          ),
        ],
      ),
      ),
    );
  }
}

class _CustomerPickerDialog extends StatefulWidget {
  final String selectedId;
  final Future<Customer?> Function() onAddCustomer;
  const _CustomerPickerDialog({required this.selectedId, required this.onAddCustomer});

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
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
    return AlertDialog(
      key: const ValueKey('customer_picker_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Select Customer', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search customers\u2026',
              filled: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Consumer(builder: (context, ref, _) {
              final customersAsync = ref.watch(customersStreamProvider);
              return customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load products'),
                    style: TextStyle(color: cs.onSurface)),
              ),
            ),
                data: (customers) {
                  final filtered = customers.where((c) =>
                      _query.isEmpty || c.name.toLowerCase().contains(_query)).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('No customers found',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final selected = c.id == widget.selectedId;
                      return ListTile(
                        selected: selected,
                        selectedTileColor: cs.primaryContainer.withValues(alpha: 0.3),
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(c.name[0].toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                        title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: c.phone.isNotEmpty
                            ? Text(c.phone, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
                            : null,
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  );
                },
              );
            }),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final c = await widget.onAddCustomer();
            if (c != null && mounted) Navigator.pop(context, c);
          },
          child: const Text('+ Add Customer', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (widget.selectedId.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, Customer(id: '', name: 'Walk-in Customer')),
            child: const Text('Walk-in'),
          ),
      ],
    );
  }
}

class _BelowCostSheet extends StatelessWidget {
  final List<CartItem> items;
  final Map<String, Product> productMap;
  final String csym;
  const _BelowCostSheet({required this.items, required this.productMap, required this.csym});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final fmt = NumberFormat('#,##0');

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 22,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: ac.expenseTint, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.warning_amber_rounded, size: 20, color: ac.expenseFg),
        ),
        const SizedBox(height: 12),
        Text('Selling below cost price',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ...items.map((item) {
          final prod = productMap[item.product.id];
          final cost = prod?.costPrice ?? 0;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.product.name,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text('Sale price', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
                Text('$csym ${fmt.format(item.salePrice.toInt())}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ac.expenseFg)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: Text('Cost price', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
                Text('$csym ${fmt.format(cost.toInt())}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface)),
              ]),
            ]),
          );
        }),
        const SizedBox(height: 8),
        Text('This sale will show a loss on these items.',
            style: TextStyle(fontSize: 12, color: ac.inkFaint)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.teal,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Anyway', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Text('Fix Price', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
            ),
          ),
        ]),
      ]),
    );
  }
}
