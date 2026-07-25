import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/sale.dart';
import '../providers/sale_provider.dart';
import '../providers/product_provider.dart';
import '../providers/customer_provider.dart';
import '../services/receipt_pdf.dart';
import '../providers/shop_provider.dart';
import '../utils/safe_error_handler.dart';

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final salesAsync = ref.watch(salesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Billing / Receipts')),
      body: salesAsync.when(
        data: (sales) {
          if (sales.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No sales yet', style: Theme.of(context).textTheme.bodyLarge),
            ]));
          }
          final recent = sales.take(50).toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recent.length,
            itemBuilder: (_, i) {
              final s = recent[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.receipt_rounded, color: cs.onPrimaryContainer),
                    ),
                    title: Text('${ref.read(currencySymbolProvider)}. ${NumberFormat('#,##0').format(s.amount.toInt())}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('${s.date.day}/${s.date.month}/${s.date.year} | Paid: ${NumberFormat('#,##0').format(s.paid.toInt())} | Bal: ${NumberFormat('#,##0').format(s.balance.toInt())}',
                        style: Theme.of(context).textTheme.bodySmall),
                    trailing: IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      tooltip: 'PDF',
                      onPressed: () => _generate(context, ref, s),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(sanitizeErrorMessage(e, fallback: 'Could not load billing data'),
                    style: TextStyle(color: cs.onSurface))),
            ),
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref, Sale sale) async {
    final products = ref.read(productsStreamProvider).asData?.value ?? [];
    final customers = ref.read(customersStreamProvider).asData?.value ?? [];
    final customer = customers.where((c) => c.id == sale.customerId).firstOrNull;
    final profile = ref.read(shopProfileProvider).asData?.value;
    final storeName = profile?.shopName ?? 'Digital Register';
    final location = profile?.location ?? '';
    final currencyCode = profile?.currency ?? 'PKR';
    try {
      final pdfBytes = await generateReceiptPdfBytes(
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
      if (!context.mounted) return;
      showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.print_rounded), title: const Text('Print'),
            onTap: () async { Navigator.pop(ctx); await Printing.layoutPdf(onLayout: (_) => pdfBytes); }),
        ListTile(leading: const Icon(Icons.share_rounded), title: const Text('Share PDF'),
            onTap: () async {
              Navigator.pop(ctx);
              await Printing.sharePdf(bytes: pdfBytes, filename: 'receipt_${sale.id.substring(0, 8)}.pdf');
            }),
      ])));
    } catch (e, st) {
      if (context.mounted) {
        final safeMsg = sanitizeErrorMessage(e, fallback: 'Could not generate PDF. Please try again.');
        logSecureError(e, st, tag: 'receipt_pdf');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(safeMsg), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }
}
