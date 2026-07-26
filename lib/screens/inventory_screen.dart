import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/cost_price_history.dart';
import '../providers/product_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/firebase_providers.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../providers/shop_provider.dart';
import '../theme/app_theme.dart';
import '../utils/debounce.dart';
import '../widgets/scale_button.dart';
import '../widgets/app_search_bar.dart';
import '../utils/safe_error_handler.dart';

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final productsAsync = ref.watch(productsStreamProvider);
    _csym = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: widget.fabBottomClearance),
        child: FloatingActionButton(
          key: const ValueKey('add_product_fab'),
          backgroundColor: AppTheme.amber,
          foregroundColor: const Color(0xFF2A1A00),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onPressed: _addProduct,
          child: const Icon(Icons.add_rounded, size: 22),
        ),
      ),
      body: productsAsync.when(
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

          final totalValue = products.fold(0.0, (s, p) => s + (p.currentStock * p.costPrice));

          return Column(children: [
            AppSearchBar(
              controller: _searchCtrl,
              hintText: 'Search products\u2026',
              onChanged: (_) => _searchDebounce.call(() => setState(() {})),
            ),
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ac.profitTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.account_balance_rounded, size: 16, color: ac.profitFg),
                const SizedBox(width: 8),
                Text('Total Inventory Value: ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ac.profitFg)),
                Text('$_csym ${NumberFormat('#,##0').format(totalValue.toInt())}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()], color: ac.profitFg)),
              ]),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['All', 'Low Stock'].map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _typeFilter = t),
                    child: Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _typeFilter == t ? AppTheme.teal : cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _typeFilter == t ? AppTheme.teal : cs.outlineVariant),
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: _typeFilter == t ? Colors.white : cs.onSurfaceVariant,
                          ),
                          child: Text(t),
                        ),
                      ),
                    ]),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: filtered.isEmpty
                    ? Center(child: Text('No matching products', style: TextStyle(color: cs.onSurfaceVariant)))
                    : ListView.builder(
                        key: ValueKey(_typeFilter),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _ProdCard(
                          product: filtered[i],
                          onTap: () => _showOptions(filtered[i]),
                          csym: _csym,
                          onEditCostPrice: () => _editCostPrice(filtered[i]),
                        ).animate().fadeIn(duration: 250.ms, delay: (i * 50).ms).slideY(begin: 0.15, duration: 250.ms, delay: (i * 50).ms),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  void _showOptions(Product product) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('Edit'), onTap: () { Navigator.pop(ctx); _edit(product); }),
      ListTile(leading: const Icon(Icons.history_rounded), title: const Text('Cost Price History'), onTap: () { Navigator.pop(ctx); _showCostHistory(product); }),
      ListTile(leading: const Icon(Icons.add_shopping_cart_rounded), title: const Text('Restock'), onTap: () { Navigator.pop(ctx); _restock(product); }),
      ListTile(leading: const Icon(Icons.archive_rounded), title: const Text('Archive'), onTap: () async {
        Navigator.pop(ctx);
        await ref.read(firestoreServiceProvider).archiveProduct(product.id);
        if (!mounted) return;
      }),
    ])));
  }

  void _editCostPrice(Product product) {
    _EditCostPriceSheet.show(context, product, _csym, () {
      ref.invalidate(productsStreamProvider);
    });
  }

  void _showCostHistory(Product product) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CostHistoryScreen(product: product, csym: _csym),
    ));
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

class _AddProductDialog extends StatefulWidget {
  final String csym;
  final void Function(Product) onSave;
  const _AddProductDialog({required this.csym, required this.onSave});

  static void show(BuildContext context, String csym, void Function(Product) onSave) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
    final cs2 = Theme.of(context).colorScheme;
    final costPrice = double.tryParse(_cc.text) ?? 0;
    final stock = double.tryParse(_sc.text) ?? 0;
    final totalCost = costPrice * stock;
    final labelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs2.onSurfaceVariant);

    Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: labelStyle, maxLines: 2, softWrap: true, overflow: TextOverflow.visible),
    );

    Widget _field(TextEditingController ctrl, {TextInputType? kt, void Function(String)? onChange}) => TextField(
      controller: ctrl,
      keyboardType: kt,
      onChanged: onChange,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        fillColor: cs2.surfaceContainerLowest,
      ),
    );

    return AlertDialog(
      key: const ValueKey('add_product_dialog_modal'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
      contentPadding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _label('Name'),
          _field(_nc),
          const SizedBox(height: 10),
          _label('Size Length (in)'),
          _field(_lc, kt: TextInputType.number),
          const SizedBox(height: 10),
          _label('Size Width (in)'),
          _field(_wc, kt: TextInputType.number),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Thickness (in)'),
              _field(_tc, kt: TextInputType.number),
            ])),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Buy Price (${widget.csym})'),
              _field(_cc, kt: TextInputType.number, onChange: (_) => setState(() {})),
            ])),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Current Stock'),
              _field(_sc, kt: TextInputType.number, onChange: (_) => setState(() {})),
            ])),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Low Stock Alert'),
              _field(_thc, kt: TextInputType.number),
            ])),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cs2.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
            child: Text('Total Cost for this lot: ${widget.csym} ${totalCost.toStringAsFixed(0)}',
                style: TextStyle(color: cs2.primary, fontWeight: FontWeight.bold, fontFeatures: [FontFeature('tnum')], fontSize: 13)),
          ),
        ]),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Add Product', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  final Product product;
  final String csym;
  final void Function(Product) onSave;
  const _EditProductDialog({required this.product, required this.csym, required this.onSave});

  static void show(BuildContext context, Product product, String csym, void Function(Product) onSave) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
    final cs2 = Theme.of(context).colorScheme;
    final costPrice = double.tryParse(_cc.text) ?? 0;
    final stock = double.tryParse(_sc.text) ?? 0;
    final totalCost = costPrice * stock;
    final labelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs2.onSurfaceVariant);

    Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: labelStyle, maxLines: 2, softWrap: true, overflow: TextOverflow.visible),
    );

    Widget _field(TextEditingController ctrl, {TextInputType? kt, void Function(String)? onChange}) => TextField(
      controller: ctrl,
      keyboardType: kt,
      onChanged: onChange,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        fillColor: cs2.surfaceContainerLowest,
      ),
    );

    return AlertDialog(
      key: const ValueKey('edit_product_dialog_modal'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.bold)),
      contentPadding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _label('Name'),
          _field(_nc),
          const SizedBox(height: 10),
          _label('Size Length (in)'),
          _field(_lc, kt: TextInputType.number),
          const SizedBox(height: 10),
          _label('Size Width (in)'),
          _field(_wc, kt: TextInputType.number),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Thickness (in)'),
              _field(_tc, kt: TextInputType.number),
            ])),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Buy Price (${widget.csym})'),
              _field(_cc, kt: TextInputType.number, onChange: (_) => setState(() {})),
            ])),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Current Stock'),
              _field(_sc, kt: TextInputType.number, onChange: (_) => setState(() {})),
            ])),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Low Stock Alert'),
              _field(_thc, kt: TextInputType.number),
            ])),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cs2.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
            child: Text('Total Cost for this lot: ${widget.csym} ${totalCost.toStringAsFixed(0)}',
                style: TextStyle(color: cs2.primary, fontWeight: FontWeight.bold, fontFeatures: [FontFeature('tnum')], fontSize: 13)),
          ),
        ]),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Save Product', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _EditCostPriceSheet extends StatefulWidget {
  final Product product;
  final String csym;
  final VoidCallback onSaved;
  const _EditCostPriceSheet({required this.product, required this.csym, required this.onSaved});

  static void show(BuildContext context, Product product, String csym, VoidCallback onSaved) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 22,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Edit Cost Price',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('${widget.product.name} \u00b7 ${widget.product.sizeLength.toStringAsFixed(0)}in \u00d7 ${widget.product.sizeWidth.toStringAsFixed(0)}in \u00b7 ${widget.product.thickness.toStringAsFixed(0)}in',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(children: [
                Text('CURRENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ac.inkFaint, letterSpacing: 0.04)),
                const SizedBox(height: 4),
                Text('${widget.csym} ${fmt.format(oldVal)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: cs.onSurface)),
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Text('NEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ac.saleFg, letterSpacing: 0.04)),
                const SizedBox(height: 4),
                Text('${widget.csym} ${fmt.format(newVal)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: ac.saleFg)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New Cost Price (${widget.csym})',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.teal),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.teal),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.teal, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              fillColor: cs.surfaceContainerLowest,
            ),
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: cs.onSurface),
            onChanged: (_) => setState(() {}),
          ),
        ]),
        const SizedBox(height: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reason (optional)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Supplier price increase',
              filled: true,
              fillColor: cs.surfaceContainerLowest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: TextStyle(fontSize: 13, color: cs.onSurface),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class RestockDialog extends StatefulWidget {
  final Product product;
  const RestockDialog({super.key, required this.product});

  static void show(BuildContext context, Product product) {
    final qtyCtrl = TextEditingController(text: '1');
    final unitCostCtrl = TextEditingController(text: product.costPrice.toStringAsFixed(0));
    final paidCtrl = TextEditingController();
    String supplierId = '';
    String supplierName = '';
    bool userEditedPaid = false;

    void recalc() {
      if (userEditedPaid) return;
      final q = double.tryParse(qtyCtrl.text) ?? 0;
      final uc = double.tryParse(unitCostCtrl.text) ?? 0;
      paidCtrl.text = (q * uc) > 0 ? (q * uc).toStringAsFixed(0) : '';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setInnerState) => AlertDialog(
          key: const ValueKey('restock_dialog_modal'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Restock: ${product.name}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Current stock: ${product.stockLabel}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Consumer(builder: (context, ref, _) {
                final suppliersAsync = ref.watch(suppliersStreamProvider);
                return suppliersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (suppliers) => InkWell(
                    onTap: () async {
                      final selected = await showDialog<Supplier>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('Select Supplier'),
                          children: [
                            if (supplierId.isNotEmpty)
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(ctx, Supplier(id: '', name: 'Unknown')),
                                child: const Text('Unknown / In-house'),
                              ),
                            ...suppliers.map((s) => SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, s),
                              child: Text(s.name),
                            )),
                          ],
                        ),
                      );
                      if (selected != null) {
                        setInnerState(() { supplierId = selected.id; supplierName = selected.name; });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Row(children: [
                        Icon(Icons.business_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(supplierId.isEmpty ? 'Select Supplier (optional)' : supplierName,
                              style: TextStyle(fontSize: 13, color: supplierId.isEmpty ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface)),
                        ),
                        Icon(Icons.arrow_drop_down_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ]),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity (pcs)', filled: true),
                keyboardType: TextInputType.number,
                onChanged: (_) { setInnerState(() { recalc(); }); },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCostCtrl,
                decoration: InputDecoration(labelText: 'Unit Cost / Buying Price', filled: true),
                keyboardType: TextInputType.number,
                onChanged: (_) { setInnerState(() { recalc(); }); },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: paidCtrl,
                decoration: const InputDecoration(labelText: 'Total Amount Paid', filled: true),
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  setInnerState(() { userEditedPaid = true; });
                },
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Calculated Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${((double.tryParse(qtyCtrl.text) ?? 0) * (double.tryParse(unitCostCtrl.text) ?? 0)).toStringAsFixed(0)} Rs',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 16,
                          fontFeatures: [FontFeature('tnum')])),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () {
                final q = double.tryParse(qtyCtrl.text) ?? 0;
                final uc = double.tryParse(unitCostCtrl.text) ?? product.costPrice;
                if (q <= 0 || uc <= 0) return;
                final paid = double.tryParse(paidCtrl.text) ?? 0;
                Navigator.of(ctx).pop();
                FirestoreService().restockTransaction(product.id, q, uc, paid, supplierId: supplierId)
                    .catchError((e, st) {
                      logSecureError(e, st, tag: 'restock');
                    });
              },
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Restock'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      qtyCtrl.dispose();
      unitCostCtrl.dispose();
      paidCtrl.dispose();
    });
  }

  @override
  State<RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<RestockDialog> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ProdCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final String csym;
  final VoidCallback? onEditCostPrice;
  const _ProdCard({required this.product, required this.onTap, this.csym = 'Rs', this.onEditCostPrice});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final fmt = NumberFormat('#,##0');
    final stockInt = product.currentStock.toInt();
    final unitPrice = fmt.format(product.costPrice.toInt());
    final totalValue = product.currentStock * product.costPrice;
    final totalFmt = fmt.format(totalValue.toInt());
    return ScaleButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(color: cs.shadow, blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -4),
          ],
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: ac.inventoryTint, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.inventory_2_rounded, size: 20, color: ac.inventoryFg),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: cs.onSurface)),
            const SizedBox(height: 2),
            Text('${product.sizeLength.toStringAsFixed(0)}in \u00d7 ${product.sizeWidth.toStringAsFixed(0)}in \u00b7 ${product.thickness.toStringAsFixed(0)}in',
                style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: product.isLowStock ? ac.expenseTint : ac.profitTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(product.isLowStock ? 'Low \u00b7 $stockInt left' : '$stockInt pcs in stock',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: product.isLowStock ? ac.expenseFg : ac.profitFg)),
              ),
              Text('$csym $unitPrice/pc',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5,
                      fontFeatures: const [FontFeature.tabularFigures()], color: cs.onSurface)),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total value', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ac.inkFaint)),
                Text('$csym $totalFmt',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.tealDark,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onEditCostPrice,
              child: Container(
                padding: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Cost Price', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ac.inkFaint)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('$csym ${fmt.format(product.costPrice.toInt())}',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                    const SizedBox(width: 6),
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(color: ac.purchaseTint, borderRadius: BorderRadius.circular(7)),
                      child: Icon(Icons.edit_rounded, size: 13, color: ac.purchaseFg),
                    ),
                  ]),
                ]),
              ),
            ),
          ])),
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
    final ac = AppColors.of(context);
    final fmt = NumberFormat('#,##0');
    final historyAsync = ref.watch(_costHistoryProvider(product.id));

    return Scaffold(
      appBar: AppBar(title: Text('${product.name} \u2014 Cost History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.onSurface))),
        data: (history) {
          if (history.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.history_rounded, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No cost changes recorded', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text('Edit the cost price to create a history entry',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (_, i) {
              final h = history[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 13, color: cs.onSurface),
                          children: [
                            TextSpan(
                              text: '$csym ${fmt.format(h.oldCostPrice.toInt())}',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: ac.inkFaint,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const TextSpan(text: '  \u2192  '),
                            TextSpan(
                              text: '$csym ${fmt.format(h.newCostPrice.toInt())}',
                              style: TextStyle(
                                color: ac.saleFg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text('${h.date.day}/${h.date.month}/${h.date.year}',
                        style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
                  ]),
                  if (h.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('"${h.note}"',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
                  ],
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

final _costHistoryProvider = StreamProvider.family<List<CostPriceHistory>, String>((ref, productId) {
  final service = ref.watch(firestoreServiceProvider);
  return service.costPriceHistoryStream(productId);
});
