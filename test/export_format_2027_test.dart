import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/models/sale.dart';
import 'package:foam_shop_register/services/accounting_service.dart';
import 'package:foam_shop_register/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final from = DateTime(2026, 7, 1);
  final to = DateTime(2026, 7, 31);
  final sale = Sale(
    id: 'INV-123456789',
    date: DateTime(2026, 7, 22),
    customerId: '',
    customerName: null,
    lineItems: [
      SaleLineItem(
        productId: 'foam-1',
        name: 'Premium Foam Roll',
        qtyOrArea: 1.5,
        salePrice: 100.5,
        costPriceAtSale: 20.25,
      ),
    ],
    paid: 100,
  );
  final summary = AccountingSummary(
    revenue: 150.75,
    cogs: 30.375,
    grossProfit: 120.375,
    totalExpenses: 10.25,
    netProfit: 110.125,
    cashInHand: 100,
    openingCapital: 0,
    cashFromSales: 100,
    cashFromRecoveries: 0,
    cashPaidForPurchases: 0,
    cashPaidToSuppliers: 0,
    totalCustomerBaqaya: 50.75,
    totalSupplierBaqaya: 0,
    inventoryValue: 400,
    lowStockCount: 0,
    totalProducts: 1,
    categoryCount: 1,
  );

  test('CSV export carries the report hierarchy and fractional values', () {
    final csv = ExportService().buildCsvReport(
      sales: [sale],
      products: const [],
      summary: summary,
      startDate: from,
      endDate: to,
      shopName: 'Asif Foam Center',
    );

    expect(csv, startsWith('\uFEFF'));
    final rows = const CsvToListConverter().convert(utf8.decode(
      utf8.encode(csv),
    ));
    expect(csv, contains('Foam Shop - Digital Register'));
    expect(csv, contains('SUMMARY,VALUE,CURRENCY'));
    expect(csv, contains('Revenue,150.75,PKR'));
    expect(csv, contains('Walk-in Customer'));
    expect(csv, contains('Premium Foam Roll'));
    expect(rows.any((row) => row.contains('Inventory value')), isTrue);
    expect(rows.any((row) => row.contains('SALES DETAIL')), isTrue);
  });

  test('XLSX keeps financial values numeric and preserves cents', () {
    final bytes = ExportService().buildXlsxReportBytes(
      sales: [sale],
      products: const [],
      summary: summary,
      startDate: from,
      endDate: to,
      shopName: 'Asif Foam Center',
    );
    final workbook = Excel.decodeBytes(bytes);
    final summarySheet = workbook.tables['Summary']!;
    final salesSheet = workbook.tables['Sales Detail']!;

    expect(summarySheet.cell(CellIndex.indexByString('A1')).value,
        isA<TextCellValue>());
    expect(
        (summarySheet.cell(CellIndex.indexByString('B6')).value
                as DoubleCellValue)
            .value,
        150.75);
    expect(
        (salesSheet.cell(CellIndex.indexByString('E6')).value
                as DoubleCellValue)
            .value,
        150.75);
    expect(
        (salesSheet.cell(CellIndex.indexByString('F6')).value
                as DoubleCellValue)
            .value,
        30.375);
    expect(salesSheet.cell(CellIndex.indexByString('C6')).value,
        TextCellValue('Walk-in Customer'));
    expect(salesSheet.cell(CellIndex.indexByString('D6')).value,
        TextCellValue('Premium Foam Roll'));
    expect(salesSheet.cell(CellIndex.indexByString('A5')).value,
        TextCellValue('Invoice ID'));
    expect(
      summarySheet.cell(CellIndex.indexByString('C6')).value,
      TextCellValue('PKR'),
    );
  });

  test('report PDF builds with the new branded, multipage report layout',
      () async {
    final bytes = await ExportService().buildPdfReportBytes(
      sales: [sale],
      products: const [],
      summary: summary,
      startDate: from,
      endDate: to,
      shopName: 'Asif Foam Center',
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(3000));
  });
}
