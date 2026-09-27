import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/cost_price_history.dart';
import '../providers/product_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/firebase_providers.dart';
import '../providers/dashboard_provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/accounting_service.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/debounce.dart';
import '../utils/animations.dart';
import '../widgets/scale_button.dart';
import '../utils/safe_error_handler.dart';
import '../widgets/design_system/design_system.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  final bool initialLowStockFilter;
  final String? highlightProductId;
  final double fabBottomClearance;
  const InventoryScreen({super.key, this.initialLowStockFilter = false, this.highlightProductId, this.fabBottomClearance = 96});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  bool _didHighlight = false;
  final _searchDebounce = Debouncer();
  String _typeFilter = 'All';
  String _csym = 'Rs';

  @override
  void initState() {
    super.initState();
    if (widget.initialLowStockFilter) _typeFilter = 'Low Stock';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didHighlight && widget.highlightProductId != null) {
      _didHighlight = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final products = ref.read(productsStreamProvider).asData?.value ?? [];
        final product = products.where((p) => p.id == widget.highlightProductId).firstOrNull;
        if (product != null) _showOptions(product);
      });
    }
  }

  @override
  void dispose() { _searchCtrl.dispose(); _searchDebounce.dispose(); super.dispose(); }

  String _dims(Product p) =>
      '${p.sizeLength.toStringAsFixed(0)}\u00d7${p.sizeWidth.toStringAsFixed(0)}\u00b7${p.thickness.toStringAsFixed(0)} in';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final productsAsync = ref.watch(productsStreamProvider);
    _csym = ref.watch(currencySymbolProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: widget.fabBottomClearance),
        child: AppFab(
          icon: Icons.add_rounded,
          semanticLabel: 'Add product',
          onTap: _addProduct,
        ),
      ),
      body: GlassBackground(
        child: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load inventory'),
                    style: TextStyle(color: cs.onSurface)),
              ),
            ),
        data: (products) {
          final query = _searchCtrl.text.toLowerCase();
          var filtered = products.where((p) {
            if (_typeFilter == 'Low Stock' && !p.isLowStock) return false;
            if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) return false;
            return true;
          }).toList();

          final lowStockCount = products.where((p) => p.isLowStock).length;
          final summary = ref.watch(accountingSummaryProvider).asData?.value;
          final double totalValue;
          if (summary != null) {
            totalValue = summary.inventoryValue;
          } else {
            totalValue = products.fold(0.0, (s, p) => s + (p.currentStock * p.costPrice));
          }

          return SafeArea(
            top: true,
            bottom: false,
            child: Column(children: [
              AppBarRow(
                showBrand: false,
                title: 'Inventory',
                trailing: [
                  AppIconButton(
                    icon: Icons.filter_list_rounded,
                      semanticLabel: 'Filter inventory',
                    onTap: () => setState(() =>
                        _typeFilter = _typeFilter == 'Low Stock' ? 'All' : 'Low Stock'),
                  ),
                ],
              ),
              Expanded(
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      radius: 16,
                      level: AppGlassLevel.raised,
                      gloss: false,
                      child: Row(children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: ac.profitTint, borderRadius: BorderRadius.circular(9)),
                          child: Icon(Icons.edit_rounded, size: 15, color: ac.profitFg),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Total Inventory Value',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ac.inkSoft)),
                        ),
                        Text('$_csym ${NumberFormat('#,##0').format(totalValue.toInt())}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: ac.profitFg)),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: AppSearchField(
                      controller: _searchCtrl,
                      hintText: 'Search products\u2026',
                      onChanged: (_) => _searchDebounce.call(() => setState(() {})),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: ChipRow(
                      values: ['All', 'Low stock ($lowStockCount)'],
                      selected: _typeFilter == 'All' ? 'All' : 'Low stock ($lowStockCount)',
                      onSelected: (v) => setState(() => _typeFilter = v == 'All' ? 'All' : 'Low Stock'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: filtered.isEmpty
                          ? NoResults(
                              key: ValueKey(_typeFilter),
                              title: 'No matching products',
                              subtitle: 'Try a different search term',
                            )
                          : ListView.builder(
                              key: ValueKey(_typeFilter),
                              padding: EdgeInsets.fromLTRB(18, 0, 18, widget.fabBottomClearance),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _ProdCard(
                                product: filtered[i],
                                onTap: () => _showOptions(filtered[i]),
                                csym: _csym,
                              ).animate().fadeIn(duration: 250.ms, delay: (i * 50).ms).slideY(begin: 0.15, duration: 250.ms, delay: (i * 50).ms),
                            ),
                    ),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
      ),
    );
  }

  void _showOptions(Product product) {
    showAppSheet(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${_dims(product)} \u00b7 ${product.stockLabel}',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          SheetOption(icon: Icons.edit_rounded, title: 'Edit product',
              onTap: () { Navigator.pop(ctx); _edit(product); }),
          SheetOption(icon: Icons.history_rounded, title: 'Cost price history',
              onTap: () { Navigator.pop(ctx); _showCostHistory(product); }),
          SheetOption(icon: Icons.currency_exchange_rounded, title: 'Edit cost price',
              onTap: () { Navigator.pop(ctx); _editCostPrice(product); }),
          SheetOption(icon: Icons.add_shopping_cart_rounded, title: 'Restock',
              onTap: () { Navigator.pop(ctx); _restock(product); }),
          SheetOption(icon: Icons.archive_rounded, title: 'Archive product', danger: true,
              onTap: () { Navigator.pop(ctx); _archive(product); }),
        ]),
      ),
    );
  }

  Future<void> _archive(Product product) async {
    await ref.read(firestoreServiceProvider).archiveProduct(product.id);
    if (!mounted) return;
    ref.invalidate(productsStreamProvider);
  }

  void _editCostPrice(Product product) {
    _EditCostPriceSheet.show(context, product, _csym, () {
      ref.invalidate(productsStreamProvider);
    });
  }

  void _showCostHistory(Product product) {
    Navigator.push(context, slideUpRoute(_CostHistoryScreen(product: product, csym: _csym)));
  }

  void _addProduct() {
    _AddProductDialog.show(context, _csym, (Product product) {
      final svc = ref.read(firestoreServiceProvider);
      svc.addProduct(product.copyWith(id: svc.generateId())).catchError((e, st) {
              logSecureError(e, st, tag: 'product_add');
            });
    });
  }

  void _edit(Product product) {
    _EditProductDialog.show(context, product, _csym, (Product updated) {
      ref.read(firestoreServiceProvider).updateProduct(updated).catchError((e, st) {
            logSecureError(e, st, tag: 'product_update');
          });
    });
  }

  void _restock(Product product) {
    RestockDialog.show(context, product);
  }
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  const _SheetField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.number,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(label.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ac.inkSoft, letterSpacing: 0.03)),
      ),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(fontSize: 13.5, color: ac.ink),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: ac.surface2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ac.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ac.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ac.primary, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

class _AddProductDialog extends StatefulWidget {
  final String csym;
  final void Function(Product) onSave;
  const _AddProductDialog({required this.csym, required this.onSave});

  static void show(BuildContext context, String csym, void Function(Product) onSave) {
    showAppSheet(
      context: context,
      builder: (_) => _AddProductDialog(
        csym: csym,
        onSave: (Product p) {
          Navigator.of(context).pop();
          onSave(p);
        },
      ),
    );
  }

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _nc = TextEditingController();
  final _lc = TextEditingController();
  final _wc = TextEditingController();
  final _tc = TextEditingController();
  final _cc = TextEditingController();
  final _sc = TextEditingController();
  final _thc = TextEditingController();

  @override
  void dispose() {
    _nc.dispose();
    _lc.dispose();
    _wc.dispose();
    _tc.dispose();
    _cc.dispose();
    _sc.dispose();
    _thc.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nc.text.trim().isEmpty) return;
    final buyPrice = double.tryParse(_cc.text) ?? 0;
    if (buyPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buy Price is required and must be greater than 0')),
      );
      return;
    }
    widget.onSave(Product(
      id: '',
      name: _nc.text.trim(),
      type: '',
      sizeLength: double.tryParse(_lc.text) ?? 0,
      sizeWidth: double.tryParse(_wc.text) ?? 0,
      thickness: double.tryParse(_tc.text) ?? 0,
      density: 0,
      unitType: 'per_sqft',
      unitPrice: 0,
      costPrice: buyPrice,
      currentStock: double.tryParse(_sc.text) ?? 0,
      lowStockThreshold: double.tryParse(_thc.text) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final costPrice = double.tryParse(_cc.text) ?? 0;
    final stock = double.tryParse(_sc.text) ?? 0;
    final totalCost = costPrice * stock;

    return AppSheetContent(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add Product',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 12),
        _SheetField(label: 'Name', controller: _nc, keyboardType: TextInputType.text),
        _SheetField(label: 'Size Length (in)', controller: _lc),
        _SheetField(label: 'Size Width (in)', controller: _wc),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _SheetField(label: 'Thickness (in)', controller: _tc)),
          const SizedBox(width: 10),
          Expanded(child: _SheetField(label: 'Buy Price (${widget.csym})', controller: _cc,
              onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ac.purchaseTint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ac.purchaseFg.withValues(alpha: 0.22)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: ac.surface, borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.info_outline_rounded, size: 14, color: ac.purchaseFg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('No sale price here',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.ink)),
                const SizedBox(height: 1),
                Text("You'll set the sale price per transaction in the Sales screen",
                    style: TextStyle(fontSize: 10.5, color: ac.inkSoft)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _SheetField(label: 'Current Stock', controller: _sc,
              onChanged: (_) => setState(() {}))),
          const SizedBox(width: 10),
          Expanded(child: _SheetField(label: 'Low Stock Alert', controller: _thc)),
        ]),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ac.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ac.outline),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total Cost for this lot',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.inkSoft)),
            Text('${widget.csym} ${totalCost.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.outline,
              onTap: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Add Product',
              icon: Icons.check_rounded,
              onTap: _submit,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  final Product product;
  final String csym;
  final void Function(Product) onSave;
  const _EditProductDialog({required this.product, required this.csym, required this.onSave});

  static void show(BuildContext context, Product product, String csym, void Function(Product) onSave) {
    showAppSheet(
      context: context,
      builder: (_) => _EditProductDialog(
        product: product,
        csym: csym,
        onSave: (Product p) {
          Navigator.of(context).pop();
          onSave(p);
        },
      ),
    );
  }

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  late final TextEditingController _nc;
  late final TextEditingController _lc;
  late final TextEditingController _wc;
  late final TextEditingController _tc;
  late final TextEditingController _cc;
  late final TextEditingController _sc;
  late final TextEditingController _thc;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nc = TextEditingController(text: p.name);
    _lc = TextEditingController(text: p.sizeLength.toString());
    _wc = TextEditingController(text: p.sizeWidth.toString());
    _tc = TextEditingController(text: p.thickness.toString());
    _cc = TextEditingController(text: p.costPrice.toString());
    _sc = TextEditingController(text: p.currentStock.toString());
    _thc = TextEditingController(text: p.lowStockThreshold.toString());
  }

  @override
  void dispose() {
    _nc.dispose();
    _lc.dispose();
    _wc.dispose();
    _tc.dispose();
    _cc.dispose();
    _sc.dispose();
    _thc.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nc.text.trim().isEmpty) return;
    widget.onSave(widget.product.copyWith(
      name: _nc.text.trim(),
      sizeLength: double.tryParse(_lc.text) ?? widget.product.sizeLength,
      sizeWidth: double.tryParse(_wc.text) ?? widget.product.sizeWidth,
      thickness: double.tryParse(_tc.text) ?? widget.product.thickness,
      costPrice: double.tryParse(_cc.text) ?? widget.product.costPrice,
      currentStock: double.tryParse(_sc.text) ?? widget.product.currentStock,
      lowStockThreshold: double.tryParse(_thc.text) ?? widget.product.lowStockThreshold,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final costPrice = double.tryParse(_cc.text) ?? 0;
    final stock = double.tryParse(_sc.text) ?? 0;
    final totalCost = costPrice * stock;

    return AppSheetContent(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Edit Product',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 12),
        _SheetField(label: 'Name', controller: _nc, keyboardType: TextInputType.text),
        _SheetField(label: 'Size Length (in)', controller: _lc),
        _SheetField(label: 'Size Width (in)', controller: _wc),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _SheetField(label: 'Thickness (in)', controller: _tc)),
          const SizedBox(width: 10),
          Expanded(child: _SheetField(label: 'Buy Price (${widget.csym})', controller: _cc,
              onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ac.purchaseTint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ac.purchaseFg.withValues(alpha: 0.22)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: ac.surface, borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.info_outline_rounded, size: 14, color: ac.purchaseFg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('No sale price here',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.ink)),
                const SizedBox(height: 1),
                Text("You'll set the sale price per transaction in the Sales screen",
                    style: TextStyle(fontSize: 10.5, color: ac.inkSoft)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _SheetField(label: 'Current Stock', controller: _sc,
              onChanged: (_) => setState(() {}))),
          const SizedBox(width: 10),
          Expanded(child: _SheetField(label: 'Low Stock Alert', controller: _thc)),
        ]),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ac.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ac.outline),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total Cost for this lot',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.inkSoft)),
            Text('${widget.csym} ${totalCost.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.outline,
              onTap: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Save',
              icon: Icons.check_rounded,
              onTap: _submit,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _EditCostPriceSheet extends StatefulWidget {
  final Product product;
  final String csym;
  final VoidCallback onSaved;
  const _EditCostPriceSheet({required this.product, required this.csym, required this.onSaved});

  static void show(BuildContext context, Product product, String csym, VoidCallback onSaved) {
    showAppSheet(
      context: context,
      builder: (_) => _EditCostPriceSheet(
        product: product,
        csym: csym,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<_EditCostPriceSheet> createState() => _EditCostPriceSheetState();
}

class _EditCostPriceSheetState extends State<_EditCostPriceSheet> {
  late final TextEditingController _priceCtrl;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.product.costPrice.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _newPrice => double.tryParse(_priceCtrl.text) ?? 0;
  bool get _canSave =>
      _newPrice >= 0 && _newPrice != widget.product.costPrice && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final svc = FirestoreService();
      await svc.updateCostPrice(widget.product.id, _newPrice, note: _noteCtrl.text.trim());
      widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cost price updated'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final fmt = NumberFormat('#,##0');
    final oldVal = widget.product.costPrice.toInt();
    final newVal = _newPrice.toInt();

    return AppSheetContent(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Edit Cost Price',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
        const SizedBox(height: 2),
        Text('${widget.product.name} \u00b7 '
            '${widget.product.sizeLength.toStringAsFixed(0)}in \u00d7 ${widget.product.sizeWidth.toStringAsFixed(0)}in \u00b7 ${widget.product.thickness.toStringAsFixed(0)}in',
            style: TextStyle(fontSize: 11, color: ac.inkFaint)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ac.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ac.outline),
              ),
              child: Column(children: [
                Text('CURRENT',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: ac.inkFaint, letterSpacing: 0.03)),
                const SizedBox(height: 4),
                Text('${widget.csym} ${fmt.format(oldVal)}',
                    style: AppTheme.display(context, size: 17)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: ac.inkFaint),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ac.saleTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Text('NEW',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: ac.saleFg, letterSpacing: 0.03)),
                const SizedBox(height: 4),
                Text('${widget.csym} ${fmt.format(newVal)}',
                    style: AppTheme.display(context, size: 17, color: ac.saleFg)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _SheetField(label: 'New cost price (${widget.csym})', controller: _priceCtrl,
            onChanged: (_) => setState(() {})),
        _SheetField(label: 'Reason (optional)', controller: _noteCtrl, keyboardType: TextInputType.text),
        Row(children: [
          Expanded(
            child: AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.ghost,
              onTap: _saving ? null : () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: _saving ? 'Saving\u2026' : 'Save',
              onTap: _canSave ? _save : null,
            ),
          ),
        ]),
      ]),
    );
  }
}

class RestockDialog extends ConsumerStatefulWidget {
  final Product product;
  const RestockDialog({super.key, required this.product});

  static void show(BuildContext context, Product product) {
    showAppSheet(
      context: context,
      builder: (_) => RestockDialog(product: product),
    );
  }

  @override
  ConsumerState<RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends ConsumerState<RestockDialog> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _unitCostCtrl;
  String _supplierId = '';
  String _supplierName = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '1');
    _unitCostCtrl = TextEditingController(text: widget.product.costPrice.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _unitCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    final result = await showAppSheet<Supplier>(
      context: context,
      builder: (ctx) => Consumer(builder: (context, ref, _) {
        final suppliersAsync = ref.watch(suppliersStreamProvider);
        return AppSheetContent(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Select Supplier',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 6),
            if (_supplierId.isNotEmpty)
              SheetOption(
                icon: Icons.close_rounded,
                title: 'Unknown / In-house',
                onTap: () => Navigator.pop(ctx, Supplier(id: '', name: 'Unknown')),
              ),
            suppliersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (suppliers) => Column(children: [
                for (final s in suppliers)
                  SheetOption(
                    icon: Icons.business_rounded,
                    title: s.name,
                    onTap: () => Navigator.pop(ctx, s),
                  ),
              ]),
            ),
          ]),
        );
      }),
    );
    if (result != null) {
      setState(() { _supplierId = result.id; _supplierName = result.name; });
    }
  }

  Future<void> _confirm(double qty, double unitCost) async {
    setState(() => _saving = true);
    try {
      await FirestoreService().restockTransaction(
        widget.product.id,
        qty,
        unitCost,
        qty * unitCost,
        supplierId: _supplierId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAppToast(context, 'Restocked ${qty.toInt()} pcs');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final cs = Theme.of(context).colorScheme;
    final csym = ref.watch(currencySymbolProvider);
    final fmt = NumberFormat('#,##0');
    final product = widget.product;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final unitCost = double.tryParse(_unitCostCtrl.text) ?? 0;
    final newCost = AccountingService().calculateProductCostAfterRestock(product, qty, unitCost);
    final total = qty * unitCost;
    final valid = qty > 0 && unitCost > 0;

    return AppSheetContent(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Restock \u2014 ${product.name}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
        const SizedBox(height: 2),
        Text('Current stock: ${product.currentStock.toInt()} ${product.unitLabel}',
            style: TextStyle(fontSize: 11, color: ac.inkFaint)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickSupplier,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ac.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ac.outline),
            ),
            child: Row(children: [
              Icon(Icons.business_rounded, size: 16, color: ac.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_supplierId.isEmpty ? 'Supplier (optional) \u2014 choose' : _supplierName,
                    style: TextStyle(fontSize: 13, color: _supplierId.isEmpty ? ac.inkFaint : cs.onSurface)),
              ),
              Icon(Icons.arrow_drop_down_rounded, size: 18, color: ac.inkFaint),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _SheetField(label: 'Quantity', controller: _qtyCtrl,
              onChanged: (_) => setState(() {}))),
          const SizedBox(width: 10),
          Expanded(child: _SheetField(label: 'Unit cost ($csym)', controller: _unitCostCtrl,
              onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ac.purchaseTint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ac.purchaseFg.withValues(alpha: 0.22)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: ac.surface, borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.bar_chart_rounded, size: 14, color: ac.purchaseFg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('New weighted-average cost',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.ink)),
                const SizedBox(height: 2),
                Text(
                  qty <= 0
                      ? 'Enter a quantity to preview the new average cost'
                      : '(${product.currentStock.toInt()} \u00d7 ${fmt.format(product.costPrice.toInt())} '
                          '+ ${qty.toInt()} \u00d7 ${fmt.format(unitCost.toInt())}) \u00f7 '
                          '${(product.currentStock + qty).toInt()} = ${fmt.format(newCost.toInt())}',
                  style: TextStyle(fontSize: 10.5, color: ac.inkSoft, height: 1.4),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ac.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ac.outline),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Calculated total',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.inkSoft)),
            Text('$csym ${fmt.format(total.toInt())}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: _saving ? 'Restocking\u2026' : 'Confirm Restock',
          icon: Icons.add_shopping_cart_rounded,
          onTap: (valid && !_saving) ? () => _confirm(qty, unitCost) : null,
        ),
      ]),
    );
  }
}

class _ProdCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final String csym;
  const _ProdCard({required this.product, required this.onTap, this.csym = 'Rs'});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final fmt = NumberFormat('#,##0');
    final stockInt = product.currentStock.toInt();
    final low = product.isLowStock;
    final dims = '${product.sizeLength.toStringAsFixed(0)}\u00d7${product.sizeWidth.toStringAsFixed(0)}\u00b7${product.thickness.toStringAsFixed(0)} in';

    return ScaleButton(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(13),
        margin: const EdgeInsets.only(bottom: 9),
        radius: 18,
        level: AppGlassLevel.raised,
        gloss: false,
        tint: low ? ac.expenseFg.withValues(alpha: 0.07) : null,
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: ac.inventoryTint, borderRadius: BorderRadius.circular(13)),
            child: Icon(Icons.inventory_2_rounded, size: 18, color: ac.inventoryFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: cs.onSurface)),
              const SizedBox(height: 2),
              Text(dims, style: TextStyle(fontSize: 11, color: ac.inkFaint)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: low ? ac.expenseTint : ac.saleTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(low ? '$stockInt left' : '$stockInt in stock',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: low ? ac.expenseFg : ac.saleFg)),
            ),
            const SizedBox(height: 3),
            Text(low ? 'Reorder soon' : 'Cost $csym ${fmt.format(product.costPrice.toInt())}',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ac.inkFaint)),
          ]),
        ]),
      ),
    );
  }
}

class _CostHistoryScreen extends ConsumerWidget {
  final Product product;
  final String csym;
  const _CostHistoryScreen({required this.product, required this.csym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final historyAsync = ref.watch(_costHistoryProvider(product.id));

    return FullScreenOverlay(
      title: '${product.name} \u2014 Cost History',
      child: historyAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 120),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.onSurface))),
        data: (history) {
          if (history.isEmpty) {
            return EmptyState(
              icon: Icons.history_rounded,
              title: 'No cost changes recorded',
              subtitle: 'Edit the cost price to create a history entry',
            );
          }
          return FoamCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < history.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _TimelineRow(h: history[i], csym: csym, primary: i == 0),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final CostPriceHistory h;
  final String csym;
  final bool primary;
  const _TimelineRow({required this.h, required this.csym, required this.primary});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final fmt = NumberFormat('#,##0');
    final dateFmt = DateFormat('d MMM yyyy');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary ? ac.primary : ac.outlineStrong,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(
                text: TextSpan(
                  style: AppTheme.display(context, size: 13, color: ac.ink),
                  children: [
                    TextSpan(
                      text: '$csym ${fmt.format(h.oldCostPrice.toInt())}',
                      style: TextStyle(color: ac.inkFaint, fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '  \u2192  '),
                    TextSpan(
                      text: '$csym ${fmt.format(h.newCostPrice.toInt())}',
                      style: TextStyle(color: ac.saleFg, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Text(dateFmt.format(h.date), style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
              if (h.note.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('"${h.note}"',
                    style: TextStyle(fontSize: 11, color: ac.inkSoft, fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

final _costHistoryProvider = StreamProvider.family<List<CostPriceHistory>, String>((ref, productId) {
  final service = ref.watch(firestoreServiceProvider);
  return service.costPriceHistoryStream(productId);
});
