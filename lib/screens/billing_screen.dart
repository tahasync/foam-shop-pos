import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/sale.dart';
import '../providers/sale_provider.dart';
import '../providers/product_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/firebase_providers.dart';
import '../services/receipt_pdf.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/currency.dart';
import '../utils/safe_error_handler.dart';
import '../widgets/design_system/design_system.dart';
import '../widgets/stitched_divider.dart';

const _filters = ['All', 'Paid', 'Due', 'Void'];

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});
  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final salesAsync = ref.watch(salesStreamProvider);
    final csym = ref.watch(currencySymbolProvider);
    final fmt = NumberFormat('#,##0');

    return FullScreenOverlay(
      title: 'Billing / Receipts',
      child: salesAsync.when(
        loading: () => const _LoadingBox(),
        error: (e, _) => _ErrorBox(message: sanitizeErrorMessage(e, fallback: 'Could not load billing data')),
        data: (sales) {
          if (sales.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No sales yet',
              subtitle: 'Completed sales will appear here as receipts',
            );
          }
          final filtered = _applyFilter(sales);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SegmentedControl(
              options: _filters,
              selectedIndex: _filterIndex,
              onChanged: (i) => setState(() => _filterIndex = i),
            ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: NoResults(title: 'No matching receipts', subtitle: 'Try a different status filter'),
              )
            else ...[
              const SizedBox(height: 14),
              FoamCard(
                foam: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(children: [
                  for (var i = 0; i < filtered.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: ac.outline),
                    _buildRow(context, ref, cs, ac, csym, fmt, filtered[i]),
                  ],
                ]),
              ),
            ],
          ]);
        },
      ),
    );
  }

  List<Sale> _applyFilter(List<Sale> sales) {
    switch (_filterIndex) {
      case 1:
        return sales.where((s) => !s.isVoided && s.balance <= 0).toList();
      case 2:
        return sales.where((s) => !s.isVoided && s.balance > 0).toList();
      case 3:
        return sales.where((s) => s.isVoided).toList();
      default:
        return sales;
    }
  }

  Widget _buildRow(
    BuildContext context,
    WidgetRef ref,
    ColorScheme cs,
    AppColors ac,
    String csym,
    NumberFormat fmt,
    Sale sale,
  ) {
    final dateStr = DateFormat('d MMM y').format(sale.date);
    final voided = sale.isVoided;
    final sub = voided
        ? '$dateStr \u00b7 Voided'
        : '$dateStr \u00b7 Paid ${fmt.format(sale.paid.toInt())} \u00b7 Bal ${fmt.format(sale.balance.toInt())}';

    Widget trailing;
    if (voided) {
      trailing = StatusBadge.voided('Void');
    } else if (sale.isQuote) {
      trailing = StatusBadge.quote('Quote');
    } else if (sale.balance <= 0) {
      trailing = StatusBadge.paid('Paid');
    } else {
      trailing = Text('Due', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ac.expenseFg));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: InkWell(
        onTap: () => _openReceiptOptions(context, ref, sale),
        child: Opacity(
          opacity: voided ? 0.55 : 1,
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.receipt_rounded, size: 17, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$csym ${fmt.format(sale.amount.toInt())}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 1),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
              ]),
            ),
            const SizedBox(width: 8),
            trailing,
          ]),
        ),
      ),
    );
  }

  Future<void> _openReceiptOptions(BuildContext context, WidgetRef ref, Sale sale) async {
    final csym = ref.read(currencySymbolProvider);
    final fmt = NumberFormat('#,##0');
    final action = await showAppSheet<_ReceiptAction>(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Receipt options',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text('$csym ${fmt.format(sale.amount.toInt())} \u00b7 ${DateFormat('d MMM y').format(sale.date)}',
              style: TextStyle(fontSize: 11, color: AppColors.of(context).inkFaint)),
          const SizedBox(height: 8),
          SheetOption(
              icon: Icons.print_rounded, title: 'Print receipt', onTap: () => Navigator.pop(ctx, _ReceiptAction.print)),
          SheetOption(
              icon: Icons.share_rounded, title: 'Share PDF', onTap: () => Navigator.pop(ctx, _ReceiptAction.share)),
          SheetOption(
              icon: Icons.visibility_rounded, title: 'Receipt preview', onTap: () => Navigator.pop(ctx, _ReceiptAction.preview)),
          if (!sale.isVoided)
            SheetOption(
                icon: Icons.close_rounded,
                title: 'Void sale',
                danger: true,
                onTap: () => Navigator.pop(ctx, _ReceiptAction.voidSale)),
        ]),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _ReceiptAction.print:
        final bytes = await _buildPdfBytes(context, ref, sale);
        if (bytes != null && context.mounted) await Printing.layoutPdf(onLayout: (_) => bytes);
        break;
      case _ReceiptAction.share:
        final bytes = await _buildPdfBytes(context, ref, sale);
        if (bytes != null && context.mounted) {
          await Printing.sharePdf(bytes: bytes, filename: 'receipt_${sale.id.substring(0, 8)}.pdf');
        }
        break;
      case _ReceiptAction.preview:
        Navigator.push(context, slideUpRoute(ReceiptPreviewScreen(sale: sale)));
        break;
      case _ReceiptAction.voidSale:
        await _confirmVoid(context, ref, sale);
        break;
    }
  }

  Future<void> _confirmVoid(BuildContext context, WidgetRef ref, Sale sale) async {
    final ac = AppColors.of(context);
    final proceed = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: ac.expenseTint, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.close_rounded, size: 20, color: ac.expenseFg),
          ),
          const SizedBox(height: 12),
          Text('Void this sale?', style: AppTheme.display(context, size: 19)),
          const SizedBox(height: 8),
          Text('This cannot be undone. Stock will be returned and the sale removed from your totals.',
              style: TextStyle(fontSize: 12, color: AppColors.of(context).inkSoft, height: 1.5)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: AppButton(
                  label: 'Cancel', variant: AppButtonVariant.ghost, onTap: () => Navigator.pop(ctx, false)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Void Sale',
                variant: AppButtonVariant.danger,
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(ctx, true),
              ),
            ),
          ]),
        ]),
      ),
    );
    if (proceed != true || !context.mounted) return;
    try {
      final s = ref.read(firestoreServiceProvider);
      await s.voidSale(sale.id, 'Voided from billing');
      ref.invalidate(accountingSummaryProvider);
      ref.invalidate(salesStreamProvider);
      ref.invalidate(productsStreamProvider);
      if (context.mounted) showAppToast(context, 'Sale voided');
    } catch (e, st) {
      logSecureError(e, st, tag: 'void_sale');
      if (context.mounted) {
        showAppToast(context, sanitizeErrorMessage(e, fallback: 'Could not void sale'));
      }
    }
  }
}

Future<Uint8List?> _buildPdfBytes(BuildContext context, WidgetRef ref, Sale sale) async {
  try {
    final products = ref.read(productsStreamProvider).asData?.value ?? [];
    final customers = ref.read(customersStreamProvider).asData?.value ?? [];
    final customer = customers.where((c) => c.id == sale.customerId).firstOrNull;
    final profile = ref.read(shopProfileProvider).asData?.value;
    final storeName = profile?.shopName ?? 'Digital Register';
    final location = profile?.location ?? '';
    final currencyCode = profile?.currency ?? 'PKR';
    return await generateReceiptPdfBytes(
      storeName: storeName,
      location: location,
      currencyCode: currencyCode,
      receiptId: 'INV-${sale.id.substring(0, 4).toUpperCase()}',
      date: '${sale.date.day}/${sale.date.month}/${sale.date.year}',
      customerName: customer?.name ?? sale.customerName ?? sale.customerId,
      items: sale.lineItems.map((li) {
        final prod = products.where((p) => p.id == li.productId).firstOrNull;
        return {
          'name': prod?.name ?? li.productId,
          'qty': li.qtyOrArea.toStringAsFixed(1),
          'price': li.salePrice,
          'total': li.lineTotal,
        };
      }).toList(),
      totalAmount: sale.amount,
      paidAmount: sale.paid,
      remainingBalance: sale.balance,
    );
  } catch (e, st) {
    logSecureError(e, st, tag: 'receipt_pdf');
    if (context.mounted) {
      showAppToast(context, sanitizeErrorMessage(e, fallback: 'Could not generate PDF. Please try again.'));
    }
    return null;
  }
}

enum _ReceiptAction { print, share, preview, voidSale }

class ReceiptPreviewScreen extends ConsumerWidget {
  final Sale sale;
  const ReceiptPreviewScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');
    final products = ref.watch(productsStreamProvider).asData?.value ?? [];
    final profile = ref.watch(shopProfileProvider).asData?.value;
    final storeName = profile?.shopName ?? 'Digital Register';
    final location = profile?.location ?? '';
    final phone = profile?.phone ?? '';
    final csym = profile != null ? currencySymbolFromCode(profile.currency) : ref.read(currencySymbolProvider);

    final paperItems = sale.lineItems.map((li) {
      final prod = products.where((p) => p.id == li.productId).firstOrNull;
      final name = prod?.name ?? li.name ?? li.productId;
      final qty = li.qtyOrArea == li.qtyOrArea.roundToDouble()
          ? li.qtyOrArea.toInt().toString()
          : li.qtyOrArea.toStringAsFixed(1);
      final unit = prod?.unitLabel ?? 'pcs';
      return _PaperItem(
        name: name,
        meta: '$qty $unit \u00d7 $csym ${fmt.format(li.salePrice.toInt())}',
        total: fmt.format(li.lineTotal.toInt()),
      );
    }).toList();

    final metaParts = [
      if (location.isNotEmpty) location,
      if (phone.isNotEmpty) phone,
    ];
    final meta = metaParts.isEmpty
        ? ''
        : '${metaParts.join(' \u00b7 ')}\n';
    final dateLine =
        '${DateFormat('d MMM y, h:mm a').format(sale.date)} \u00b7 Receipt #INV-${sale.id.substring(0, 4).toUpperCase()}';

    final isDue = sale.balance > 0;
    final dueValue = isDue ? sale.balance : (sale.paid - sale.amount).abs();
    final footer =
        '$storeName${location.isNotEmpty ? ' \u00b7 $location' : ''}';

    return FullScreenOverlay(
      title: 'Receipt Preview',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _TornPaper(
          paperBg: cs.surface,
          storeName: storeName,
          meta: '$meta$dateLine',
          items: paperItems,
          total: '$csym ${fmt.format(sale.amount.toInt())}',
          paid: '$csym ${fmt.format(sale.paid.toInt())}',
          isDue: isDue,
          dueLabel: isDue ? 'Balance Due' : 'Change',
          dueValue: '$csym ${fmt.format(dueValue.toInt())}',
          footer: footer,
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: AppButton(
              label: 'Print',
              icon: Icons.print_rounded,
              variant: AppButtonVariant.outline,
              onTap: () async {
                final bytes = await _buildPdfBytes(context, ref, sale);
                if (bytes != null && context.mounted) await Printing.layoutPdf(onLayout: (_) => bytes);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Share PDF',
              icon: Icons.share_rounded,
              onTap: () async {
                final bytes = await _buildPdfBytes(context, ref, sale);
                if (bytes != null && context.mounted) {
                  await Printing.sharePdf(bytes: bytes, filename: 'receipt_${sale.id.substring(0, 8)}.pdf');
                }
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

class _PaperItem {
  final String name;
  final String meta;
  final String total;
  const _PaperItem({required this.name, required this.meta, required this.total});
}

class _TornPaper extends StatelessWidget {
  final Color paperBg;
  final String storeName;
  final String meta;
  final List<_PaperItem> items;
  final String total;
  final String paid;
  final bool isDue;
  final String dueLabel;
  final String dueValue;
  final String footer;

  const _TornPaper({
    required this.paperBg,
    required this.storeName,
    required this.meta,
    required this.items,
    required this.total,
    required this.paid,
    required this.isDue,
    required this.dueLabel,
    required this.dueValue,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final paper = Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(storeName,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Fraunces',
                fontFamilyFallback: const ['serif'],
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface)),
        const SizedBox(height: 4),
        Text(meta, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, height: 1.4, color: ac.inkFaint)),
        const StitchedDivider(thickness: 1.5, margin: EdgeInsets.only(top: 14, bottom: 12)),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  Text(item.meta, style: TextStyle(fontSize: 9.5, color: ac.inkFaint)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(item.total,
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurface, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
        const StitchedDivider(thickness: 1.5, margin: EdgeInsets.symmetric(vertical: 12)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
          Text(total,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 8),
        MiniRow(label: 'Paid', value: paid),
        const StitchedDivider(thickness: 1.5, margin: EdgeInsets.symmetric(vertical: 12)),
        MiniRow(label: dueLabel, value: dueValue, valueColor: isDue ? ac.expenseFg : ac.saleFg),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDue ? ac.expenseTint : ac.saleTint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isDue ? 'BALANCE DUE' : 'FULLY PAID',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.03,
                color: isDue ? ac.expenseFg : ac.saleFg,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          width: double.infinity,
          child: CustomPaint(painter: _BarcodePainter(color: cs.onSurface.withValues(alpha: 0.75))),
        ),
        const SizedBox(height: 12),
        Text('Thank you for your business!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: ac.inkFaint)),
        if (footer.isNotEmpty)
          Text(footer,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
      ]),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 3,
          left: -4,
          right: -4,
          height: 11,
          child: CustomPaint(painter: _TornEdgePainter(paperBg: paperBg, flipped: false)),
        ),
        paper,
        Positioned(
          bottom: 3,
          left: -4,
          right: -4,
          height: 11,
          child: CustomPaint(painter: _TornEdgePainter(paperBg: paperBg, flipped: true)),
        ),
      ],
    );
  }
}

class _TornEdgePainter extends CustomPainter {
  final Color paperBg;
  final bool flipped;
  const _TornEdgePainter({required this.paperBg, required this.flipped});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = paperBg;
    final w = size.width;
    const step = 14.0;
    final half = step / 2;
    final path = Path();
    if (flipped) {
      path.moveTo(0, size.height);
      for (double x = 0; x <= w + step; x += step) {
        path.lineTo(x, 0);
        path.lineTo((x + half).clamp(0, w), size.height);
      }
    } else {
      path.moveTo(0, 0);
      for (double x = 0; x <= w + step; x += step) {
        path.lineTo(x, size.height);
        path.lineTo((x + half).clamp(0, w), 0);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TornEdgePainter old) => old.paperBg != paperBg || old.flipped != flipped;
}

class _BarcodePainter extends CustomPainter {
  final Color color;
  const _BarcodePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    var seed = 20260728;
    int next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    double x = 0;
    while (x < size.width) {
      final bw = 1 + (next() % 20) / 10.0;
      if (x + bw > size.width) break;
      canvas.drawRect(Rect.fromLTWH(x, 0, bw, size.height), paint);
      x += bw + 2 + (next() % 30) / 10.0;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.color != color;
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      ),
    );
  }
}
