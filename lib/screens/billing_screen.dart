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
import '../services/receipt_saver.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/safe_error_handler.dart';
import '../widgets/design_system/design_system.dart';

const _filters = ['All', 'Paid', 'Due', 'Void'];

/// A filesystem-safe, collision-free name for a receipt PDF.
///
/// This used to be inline `sale.id.substring(0, 8)` calls, which throw a
/// `RangeError` for any id shorter than the requested length and would take
/// down the whole share sheet rather than just that one option.
String _safeIdPrefix(String id, int length) {
  final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  if (clean.isEmpty) return 'sale';
  return clean.length <= length ? clean : clean.substring(0, length);
}

String _receiptFileName(Sale sale) =>
    'receipt_${_safeIdPrefix(sale.id, 8)}.pdf';

/// Short human-facing receipt number, e.g. `INV-0142`.
String _receiptNumber(Sale sale) =>
    'INV-${_safeIdPrefix(sale.id, 4).toUpperCase()}';

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
        error: (e, _) => _ErrorBox(
            message: sanitizeErrorMessage(e,
                fallback: 'Could not load billing data')),
        data: (sales) {
          if (sales.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No sales yet',
              subtitle: 'Completed sales will appear here as receipts',
            );
          }
          final filtered = _applyFilter(sales);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedControl(
                  options: _filters,
                  selectedIndex: _filterIndex,
                  onChanged: (i) => setState(() => _filterIndex = i),
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: NoResults(
                        title: 'No matching receipts',
                        subtitle: 'Try a different status filter'),
                  )
                else ...[
                  const SizedBox(height: 14),
                  FoamCard(
                    foam: true,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    // An overpaid sale has no balance and no debt. It has change to give back,
    // and that is what the cashier needs to see here — the row used to print
    // "Bal -1,000", a figure that reads as a negative debt rather than Rs 1,000
    // leaving the till.
    final settledNote = sale.hasChange
        ? 'Change ${fmt.format(sale.changeDue.toInt())}'
        : 'Bal ${fmt.format(sale.balance.toInt())}';
    final sub = voided
        ? '$dateStr \u00b7 Voided'
        : '$dateStr \u00b7 Paid ${fmt.format(sale.paid.toInt())} \u00b7 $settledNote';

    Widget trailing;
    if (voided) {
      trailing = StatusBadge.voided('Void');
    } else if (sale.isQuote) {
      trailing = StatusBadge.quote('Quote');
    } else if (sale.hasChange) {
      trailing = StatusBadge.change('Change');
    } else if (sale.balance <= 0) {
      trailing = StatusBadge.paid('Paid');
    } else {
      trailing = Text('Due',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: ac.expenseFg));
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
              decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.receipt_rounded,
                  size: 17, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$csym ${fmt.format(sale.amount.toInt())}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                    const SizedBox(height: 1),
                    // Two lines, not one: "28 Sep 2026 · Paid 26,000 · Change
                    // 3,500" is wider than a Pixel 4 at this font size, and a
                    // single ellipsised line cut the figure the cashier actually
                    // needs ("Change 3,500" -> "Change ..."). This affected due
                    // rows too ("Bal 12,500" was dropped the same way).
                    Text(sub,
                        maxLines: 2,
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

  Future<void> _openReceiptOptions(
      BuildContext context, WidgetRef ref, Sale sale) async {
    final csym = ref.read(currencySymbolProvider);
    final fmt = NumberFormat('#,##0');
    final action = await showAppSheet<_ReceiptAction>(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Receipt options',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text(
              '$csym ${fmt.format(sale.amount.toInt())} \u00b7 ${DateFormat('d MMM y').format(sale.date)}',
              style: TextStyle(
                  fontSize: 11, color: AppColors.of(context).inkFaint)),
          const SizedBox(height: 8),
          SheetOption(
              icon: Icons.print_rounded,
              title: 'Print receipt',
              onTap: () => Navigator.pop(ctx, _ReceiptAction.print)),
          SheetOption(
              icon: Icons.save_alt_rounded,
              title: 'Save PDF',
              onTap: () => Navigator.pop(ctx, _ReceiptAction.save)),
          SheetOption(
              icon: Icons.share_rounded,
              title: 'Share PDF',
              onTap: () => Navigator.pop(ctx, _ReceiptAction.share)),
          SheetOption(
              icon: Icons.visibility_rounded,
              title: 'Receipt preview',
              onTap: () => Navigator.pop(ctx, _ReceiptAction.preview)),
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
        if (bytes != null && context.mounted)
          await Printing.layoutPdf(onLayout: (_) => bytes);
        break;
      case _ReceiptAction.save:
        final bytes = await _buildPdfBytes(context, ref, sale);
        if (bytes != null && context.mounted) {
          await _savePdf(context, bytes, sale);
        }
        break;
      case _ReceiptAction.share:
        final bytes = await _buildPdfBytes(context, ref, sale);
        if (bytes != null && context.mounted) {
          await Printing.sharePdf(
              bytes: bytes, filename: _receiptFileName(sale));
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

  Future<void> _confirmVoid(
      BuildContext context, WidgetRef ref, Sale sale) async {
    final ac = AppColors.of(context);
    final proceed = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => AppSheetContent(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: ac.expenseTint, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.close_rounded, size: 20, color: ac.expenseFg),
          ),
          const SizedBox(height: 12),
          Text('Void this sale?', style: AppTheme.display(context, size: 19)),
          const SizedBox(height: 8),
          Text(
              'This cannot be undone. Stock will be returned and the sale removed from your totals.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.of(context).inkSoft,
                  height: 1.5)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.ghost,
                  onTap: () => Navigator.pop(ctx, false)),
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
        showAppToast(
            context, sanitizeErrorMessage(e, fallback: 'Could not void sale'));
      }
    }
  }
}

Future<Uint8List?> _buildPdfBytes(
    BuildContext context, WidgetRef ref, Sale sale) async {
  try {
    final products = ref.read(productsStreamProvider).asData?.value ?? [];
    final customers = ref.read(customersStreamProvider).asData?.value ?? [];
    final customer =
        customers.where((c) => c.id == sale.customerId).firstOrNull;
    final profile = ref.read(shopProfileProvider).asData?.value;
    final storeName = profile?.shopName ?? 'Digital Register';
    final location = profile?.location ?? '';
    final phone = profile?.phone ?? '';
    final fmt = NumberFormat('#,##0');
    final lines = sale.lineItems.map((li) {
      final prod = products.where((p) => p.id == li.productId).firstOrNull;
      return ReceiptLine(
        name: prod?.name ?? li.name ?? li.productId,
        // Whole numbers lose the trailing ".0" — "1" reads better on a receipt
        // than "1.0" for a single unit, but a cut area of 12.5 must keep it.
        qty: li.qtyOrArea == li.qtyOrArea.roundToDouble()
            ? li.qtyOrArea.toInt().toString()
            : li.qtyOrArea.toStringAsFixed(1),
        unitPrice: fmt.format(li.salePrice.toInt()),
        total: fmt.format(li.lineTotal.toInt()),
      );
    }).toList();
    final data = buildReceiptData(
      storeName: storeName,
      location: location,
      phone: phone,
      currencyCode: profile?.currency ?? 'PKR',
      receiptId: _receiptNumber(sale),
      date: '${sale.date.day}/${sale.date.month}/${sale.date.year}',
      customerName: customer?.name ?? sale.customerName ?? sale.customerId,
      items: lines,
      totalAmount: sale.amount,
      paidAmount: sale.paid,
      remainingBalance: sale.balance,
    );
    return await generateReceiptPdf(data);
  } catch (e, st) {
    logSecureError(e, st, tag: 'receipt_pdf');
    if (context.mounted) {
      showAppToast(
          context,
          sanitizeErrorMessage(e,
              fallback: 'Could not generate PDF. Please try again.'));
    }
    return null;
  }
}

enum _ReceiptAction { print, save, share, preview, voidSale }

/// Writes the receipt into the device's public Downloads folder and reports
/// where it landed.
///
/// There was no save path at all before: the only options were print and share,
/// so keeping a copy of a receipt meant photographing the screen.
///
/// The first implementation wrote the bytes with `dart:io`'s `File` straight
/// into `getDownloadsDirectory()`. That path is covered by Android's scoped
/// storage from Android 10 onward, and `WRITE_EXTERNAL_STORAGE` is capped at
/// `maxSdkVersion=28` in the manifest, so there is no permission to ask for. The
/// write silently accomplished nothing: the toast said the receipt was saved and
/// nothing ever appeared in the phone's storage.
///
/// The save now goes through MediaStore on the native side, which needs no
/// runtime permission and publishes the file to Files, Downloads and the gallery.
Future<void> _savePdf(BuildContext context, Uint8List bytes, Sale sale) async {
  final name = _receiptFileName(sale);
  try {
    final where = await ReceiptSaver.instance.save(bytes, name);
    if (!context.mounted) return;
    // Report where the file actually went. [ReceiptSaver.save] returns the
    // app's documents directory on iOS, so the previous hardcoded
    // "Saved to Downloads/..." pointed the user at a folder that does not exist
    // for them on every non-Android device.
    showAppToast(context, 'Saved to $where');
    // Surfacing the resolved location keeps this debuggable: a wrong path is
    // otherwise invisible, which is exactly how the scoped-storage bug hid.
    logSecureError('receipt saved to $where', StackTrace.current,
        tag: 'receipt_save');
  } catch (e, st) {
    // A device that still refuses the write must not lose the receipt: fall
    // back to the share sheet, where the user can send it somewhere.
    logSecureError(e, st, tag: 'receipt_save');
    if (!context.mounted) return;
    await Printing.sharePdf(bytes: bytes, filename: name);
  }
}

class ReceiptPreviewScreen extends ConsumerWidget {
  final Sale sale;
  const ReceiptPreviewScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,##0');
    final products = ref.watch(productsStreamProvider).asData?.value ?? [];
    final profile = ref.watch(shopProfileProvider).asData?.value;
    final storeName = profile?.shopName ?? 'Digital Register';
    final location = profile?.location ?? '';
    final phone = profile?.phone ?? '';

    // The preview renders the same [ReceiptData] the PDF is built from, so the
    // two cannot drift. Only the date format differs: the screen has room for
    // "22 Jul 2026 · 6:53 pm", the 80mm roll needs the compact "22/7/2026".
    final data = buildReceiptData(
      storeName: storeName,
      receiptId: _receiptNumber(sale),
      date: DateFormat('d MMM y \u00b7 h:mm a').format(sale.date),
      customerName: sale.customerName ?? sale.customerId,
      items: [
        for (final li in sale.lineItems)
          ReceiptLine(
            name:
                products.where((p) => p.id == li.productId).firstOrNull?.name ??
                    li.name ??
                    li.productId,
            // Whole numbers lose the trailing ".0" — "1" reads better on a
            // receipt than "1.0" for a single unit, but a cut area of 12.5 must
            // keep it.
            qty: li.qtyOrArea == li.qtyOrArea.roundToDouble()
                ? li.qtyOrArea.toInt().toString()
                : li.qtyOrArea.toStringAsFixed(1),
            unitPrice: fmt.format(li.salePrice.toInt()),
            total: fmt.format(li.lineTotal.toInt()),
          ),
      ],
      totalAmount: sale.amount,
      paidAmount: sale.paid,
      remainingBalance: sale.balance,
      location: location,
      phone: phone,
      currencyCode: profile?.currency ?? 'PKR',
    );

    return FullScreenOverlay(
      title: 'Receipt Preview',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _ReceiptPaper(data: data),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: AppButton(
              label: 'Print',
              icon: Icons.print_rounded,
              variant: AppButtonVariant.outline,
              onTap: () async {
                final bytes = await _buildPdfBytes(context, ref, sale);
                if (bytes != null && context.mounted)
                  await Printing.layoutPdf(onLayout: (_) => bytes);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Save PDF',
              icon: Icons.save_alt_rounded,
              variant: AppButtonVariant.outline,
              onTap: () async {
                final bytes = await _buildPdfBytes(context, ref, sale);
                if (bytes != null && context.mounted) {
                  await _savePdf(context, bytes, sale);
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Share',
              icon: Icons.share_rounded,
              onTap: () async {
                final bytes = await _buildPdfBytes(context, ref, sale);
                if (bytes != null && context.mounted) {
                  await Printing.sharePdf(
                      bytes: bytes, filename: _receiptFileName(sale));
                }
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

/// The on-screen receipt.
///
/// Rewritten to mirror `generateReceiptPdfBytes` and
/// `design/foam-shop-receipt-report-mockup.html`, because the two used to
/// disagree completely: the preview was a torn-paper design with a decorative
/// barcode, while the shared/printed PDF was a plain A4 sheet. A customer who
/// saw the preview and then received the shared file saw two different
/// documents for the same sale.
///
/// Glitches this fixes:
///  * The preview printed "Change" with a non-zero figure on a fully-paid sale
///    (`(paid - amount).abs()`) directly above a "FULLY PAID" badge.
///  * `Fraunces` was named as the shop-name font but is not bundled, so it
///    silently fell back to a different serif.
///  * The barcode was a hardcoded pseudo-random pattern carrying no data — it
///    looked scannable and verified nothing.
class _ReceiptPaper extends StatelessWidget {
  /// The shared model. Rendering this — rather than a private set of fields —
  /// is what guarantees the preview and the printed PDF describe the same sale.
  final ReceiptData data;
  const _ReceiptPaper({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    final tnum = const [FontFeature.tabularFigures()];
    final d = data;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReceiptHeader(storeName: d.storeName),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _MetaCell(label: 'DATE', value: d.date)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: _MetaCell(
                        label: 'RECEIPT #',
                        value: d.receiptNo,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                if (d.metaLine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(d.metaLine,
                      style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
                ],
                const SizedBox(height: 14),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: 'Customer: ',
                      style: TextStyle(fontSize: 12, color: ac.inkSoft),
                    ),
                    TextSpan(
                      text: d.customerName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                _ItemTable(items: d.items, tnum: tnum),
                const SizedBox(height: 14),
                _TotalsCard(
                  total: d.total,
                  paid: d.paid,
                  isDue: d.isDue,
                  dueValue: d.dueValue,
                  change: d.change,
                  tnum: tnum,
                ),
                const SizedBox(height: 12),
                _StatusBadge(isDue: d.isDue),
                const SizedBox(height: 16),
                Container(height: 1, color: ac.outline),
                const SizedBox(height: 14),
                Text(
                  'Thank you for your business!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ac.saleFg,
                  ),
                ),
                if (d.footer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    d.footer,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: ac.inkFaint),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Branded teal banner at the top of the receipt.
class _ReceiptHeader extends StatelessWidget {
  final String storeName;
  const _ReceiptHeader({required this.storeName});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ac.brandFill, ac.brandFillDeep],
        ),
      ),
      child: Column(
        children: [
          Text(
            storeName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.01,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Digital Register',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Small uppercase label above a value, used for DATE / RECEIPT #.
class _MetaCell extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _MetaCell({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.06,
            color: ac.inkFaint,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

/// The itemised table: real columns with a header rule, so qty/price/total can
/// be scanned vertically instead of read as stacked label/value pairs.
class _ItemTable extends StatelessWidget {
  final List<ReceiptLine> items;
  final List<FontFeature> tnum;

  const _ItemTable({required this.items, required this.tnum});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);

    Widget th(String label, {bool left = false}) => Expanded(
          flex: 0,
          child: Text(
            label,
            textAlign: left ? TextAlign.left : TextAlign.right,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
              color: ac.inkFaint,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(flex: 32, child: th('ITEM', left: true)),
            Expanded(flex: 10, child: th('QTY')),
            Expanded(flex: 15, child: th('PRICE')),
            Expanded(flex: 17, child: th('TOTAL')),
          ],
        ),
        const SizedBox(height: 6),
        Container(height: 1.4, color: cs.onSurface),
        for (final item in items) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 32,
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Text(
                    item.qty,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 11.5, color: ac.inkSoft, fontFeatures: tnum),
                  ),
                ),
                Expanded(
                  flex: 15,
                  child: Text(
                    item.unitPrice,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 11.5, color: ac.inkSoft, fontFeatures: tnum),
                  ),
                ),
                Expanded(
                  flex: 17,
                  child: Text(
                    item.total,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      fontFeatures: tnum,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: ac.outline),
        ],
      ],
    );
  }
}

/// The tinted totals card. Separated from the item table so the figures the
/// customer actually cares about read as one block.
class _TotalsCard extends StatelessWidget {
  final String total;
  final String paid;
  final bool isDue;
  final String dueValue;

  /// The change to hand back, already formatted. Empty when there is none.
  final String change;
  final List<FontFeature> tnum;

  const _TotalsCard({
    required this.total,
    required this.paid,
    required this.isDue,
    required this.dueValue,
    this.change = '',
    required this.tnum,
  });

  /// Mirrors [ReceiptData.hasChange] so the preview and the printed PDF decide
  /// identically whether the change row is shown.
  bool get hasChange => change.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);

    Widget row(String label, String value) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: ac.inkSoft)),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                fontFeatures: tnum,
              ),
            ),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ac.saleTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          row('Amount', total),
          const SizedBox(height: 4),
          row('Paid', paid),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: ac.saleFg.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                // Matches the PDF's grand row: an overpaid sale is settled, so
                // "Balance Rs 0" under a Rs 1,000 change reads as a
                // contradiction. The change takes the emphasized row instead.
                hasChange
                    ? 'Change Returned'
                    : (isDue ? 'Balance Due' : 'Balance'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ac.saleFg,
                ),
              ),
              Text(
                hasChange ? change : (isDue ? dueValue : 'Rs 0'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ac.saleFg,
                  fontFeatures: tnum,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Colour-coded paid/due pill.
class _StatusBadge extends StatelessWidget {
  final bool isDue;
  const _StatusBadge({required this.isDue});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isDue ? ac.expenseTint : ac.saleTint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isDue ? 'BALANCE DUE' : '\u2713 FULLY PAID',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.03,
            color: isDue ? ac.expenseFg : ac.saleFg,
          ),
        ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
        height: 260, child: Center(child: CircularProgressIndicator()));
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
        child: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      ),
    );
  }
}
