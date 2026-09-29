import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/sale.dart';
import '../models/purchase.dart';
import '../models/expense.dart';
import '../models/payment.dart';
import '../models/supplier_payment.dart';
import '../models/opening_balance.dart';
import '../models/shop_profile.dart';
import '../models/cost_price_history.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.uid;
  }

  CollectionReference get _products =>
      _db.collection('users').doc(_uid).collection('products');
  CollectionReference get _customers =>
      _db.collection('users').doc(_uid).collection('customers');
  CollectionReference get _suppliers =>
      _db.collection('users').doc(_uid).collection('suppliers');
  CollectionReference get _sales =>
      _db.collection('users').doc(_uid).collection('sales');
  CollectionReference get _purchases =>
      _db.collection('users').doc(_uid).collection('purchases');
  CollectionReference get _expenses =>
      _db.collection('users').doc(_uid).collection('expenses');
  CollectionReference get _payments =>
      _db.collection('users').doc(_uid).collection('payments');
  CollectionReference get _supplierPayments =>
      _db.collection('users').doc(_uid).collection('supplier_payments');
  CollectionReference get _openingBalances =>
      _db.collection('users').doc(_uid).collection('opening_balances');

  String generateId() {
    return _db.collection('_ids').doc().id;
  }

  // Products
  Future<void> addProduct(Product p) => _products.doc(p.id).set(p.toMap());
  Future<void> updateProduct(Product p) =>
      _products.doc(p.id).update(p.toMap());
  Future<void> archiveProduct(String id) =>
      _products.doc(id).update({'is_archived': true});
  Stream<QuerySnapshot> get productsStream =>
      _products.where('is_archived', isEqualTo: false).snapshots();

  /// Firestore caps a `whereIn` / `in` clause at 10 values, so a cart with more
  /// than 10 distinct products has to be fetched in batches.
  ///
  /// This used to be `ids.take(10)`, which silently dropped every product past
  /// the tenth. A large sale then reached [saveSaleTransaction] with
  /// `verifiedStocks` missing entries — so the pre-flight stock check was
  /// skipped for those lines — and the sale was written with
  /// `costPriceAtSale: 0`, which understates COGS and overstates gross profit
  /// for the rest of that sale's life. Batching returns every requested product.
  Future<List<Product>> getProductsByIds(Set<String> ids) async {
    if (ids.isEmpty) return [];

    // `whereIn` is capped at 10 operands; anything more fails the query outright.
    const batchSize = 10;
    final all = ids.toList();
    final results = <Product>[];

    for (var i = 0; i < all.length; i += batchSize) {
      final end = (i + batchSize) < all.length ? (i + batchSize) : all.length;
      final snap = await _products
          .where(FieldPath.documentId, whereIn: all.sublist(i, end))
          .get();
      results.addAll(snap.docs
          .map((d) => Product.fromMap(d.data() as Map<String, dynamic>)));
    }
    return results;
  }

  // Customers
  Future<void> addCustomer(Customer c) => _customers.doc(c.id).set(c.toMap());
  Stream<QuerySnapshot> get customersStream =>
      _customers.where('is_archived', isEqualTo: false).snapshots();

  // Suppliers
  Future<void> addSupplier(Supplier s) => _suppliers.doc(s.id).set(s.toMap());
  Stream<QuerySnapshot> get suppliersStream =>
      _suppliers.where('is_archived', isEqualTo: false).snapshots();

  // Sales
  Future<void> addSale(Sale s) => _sales.doc(s.id).set(s.toMap());
  Stream<QuerySnapshot> salesStream({DateTime? from, DateTime? to}) {
    Query q = _sales.orderBy('date', descending: true);
    if (from != null)
      q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null)
      q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    return q.snapshots();
  }

  // Purchases
  //
  // There is no `addPurchase`: every purchase is created inside
  // [restockTransaction], together with the stock increase and the WAC
  // recalculation it belongs to. A standalone write path would let the two
  // disagree.
  Stream<QuerySnapshot> purchasesStream({DateTime? from, DateTime? to}) {
    Query q = _purchases.orderBy('date', descending: true);
    if (from != null)
      q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null)
      q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    return q.snapshots();
  }

  // Expenses
  Future<void> addExpense(Expense e) => _expenses.doc(e.id).set(e.toMap());
  Stream<QuerySnapshot> expensesStream({DateTime? from, DateTime? to}) {
    Query q = _expenses.orderBy('date', descending: true);
    if (from != null)
      q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null)
      q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    return q.snapshots();
  }

  // Payments (Customer Recovery)
  //
  // There is no `addPayment`: a collection always goes through
  // [savePaymentTransaction], which also decrements the customer's baqaya in
  // the same transaction. Writing the payment alone would leave the two out of
  // step.
  Future<void> savePaymentTransaction(Payment payment) async {
    await _db.runTransaction((transaction) async {
      final ref = _payments.doc(payment.id);
      final existing = await transaction.get(ref);
      if (existing.exists) return;
      transaction.set(ref, {
        ...payment.toMap(),
        'transaction_uuid': payment.id,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (payment.customerId.isNotEmpty) {
        transaction.update(_customers.doc(payment.customerId), {
          'baqaya': FieldValue.increment(-payment.amountCollected),
        });
      }
    });
  }

  Stream<QuerySnapshot> paymentsStream({DateTime? from, DateTime? to}) {
    Query q = _payments.orderBy('date', descending: true);
    if (from != null)
      q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null)
      q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    return q.snapshots();
  }

  // Supplier Payments
  Future<void> addSupplierPayment(SupplierPayment sp) =>
      _supplierPayments.doc(sp.id).set(sp.toMap());
  Stream<QuerySnapshot> supplierPaymentsStream({DateTime? from, DateTime? to}) {
    Query q = _supplierPayments.orderBy('date', descending: true);
    if (from != null)
      q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null)
      q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    return q.snapshots();
  }

  // Atomic sale transaction — also updates customer baqaya.
  // verifiedStocks is a pre-check from locally-fetched product data;
  // the authoritative stock check and decrement happen inside the
  // transaction against live server data.
  Future<void> saveSaleTransaction(Sale sale, Map<String, double> deductions,
      {Map<String, double>? verifiedStocks}) async {
    for (final entry in deductions.entries) {
      final stock = verifiedStocks?[entry.key];
      if (stock != null && stock < entry.value) {
        throw Exception('Insufficient stock for product ${entry.key}');
      }
    }
    await _db.runTransaction((transaction) async {
      final saleRef = _sales.doc(sale.id);
      final existing = await transaction.get(saleRef);
      if (existing.exists) return;

      final productEntries = deductions.entries.toList();
      final productRefs =
          productEntries.map((e) => _products.doc(e.key)).toList();
      final snaps =
          await Future.wait(productRefs.map((ref) => transaction.get(ref)));

      for (int i = 0; i < productEntries.length; i++) {
        final entry = productEntries[i];
        final snap = snaps[i];
        if (!snap.exists) throw Exception('Product ${entry.key} not found');
        final currentStock =
            (snap.data() as Map<String, dynamic>)['current_stock'] as num? ?? 0;
        if ((currentStock).toDouble() < entry.value) {
          throw Exception('Insufficient stock for product ${entry.key}');
        }
        transaction.update(productRefs[i],
            {'current_stock': (currentStock).toDouble() - entry.value});
      }

      transaction.set(saleRef, sale.toMap());
      if (sale.customerId.isNotEmpty && sale.balance > 0) {
        transaction.update(_customers.doc(sale.customerId), {
          'baqaya': FieldValue.increment(sale.balance),
        });
      }
    });
  }

  // Atomic restock transaction
  Future<void> restockTransaction(
      String productId, double restockQty, double unitCost, double amountPaid,
      {String supplierId = ''}) async {
    await _db.runTransaction((transaction) async {
      final productRef = _products.doc(productId);
      final snap = await transaction.get(productRef);
      if (!snap.exists) throw Exception('Product not found');
      final data = snap.data() as Map<String, dynamic>;
      final currentStock = (data['current_stock'] as num?)?.toDouble() ?? 0;
      final costPrice = (data['cost_price'] as num?)?.toDouble() ?? 0;

      final totalStock = currentStock + restockQty;
      if (totalStock <= 0) return;
      final weightedCost =
          ((currentStock * costPrice) + (restockQty * unitCost)) / totalStock;

      transaction.update(productRef, {
        'current_stock': totalStock,
        'cost_price': weightedCost,
      });

      final purchaseId = _db.collection('_ids').doc().id;
      final costAmount = restockQty * unitCost;
      final purchase = Purchase(
        id: purchaseId,
        date: DateTime.now(),
        supplierId: supplierId,
        productId: productId,
        qtyOrArea: restockQty,
        costAmount: costAmount,
        paid: amountPaid,
        balance: costAmount - amountPaid,
      );
      transaction.set(_purchases.doc(purchaseId), purchase.toMap());
    });
  }

  // Void / Cancel
  Future<void> voidSale(String saleId, String reason) async {
    await _db.runTransaction((transaction) async {
      final saleRef = _sales.doc(saleId);
      final saleSnap = await transaction.get(saleRef);
      if (!saleSnap.exists) throw Exception('Sale not found');

      final data = saleSnap.data() as Map<String, dynamic>;
      final sale = Sale.fromMap(data);
      if (sale.isVoided) return;

      // A quote never moved stock. Sales are saved through
      // `saveSaleTransaction`, which is the only path that decrements
      // `current_stock`; a quote is a bare `.set()` (see `addSale`), so its line
      // items were never deducted. Restocking them here would return material
      // the shop never gave out - quote 500 sq ft with 1,000 in stock, void it,
      // and the ledger now claims 1,500 sq ft of foam that does not exist. The
      // phantom stock is sellable, the owner over-buys against it, and because
      // there is no way to delete a sale to undo the mistake, it is permanent.
      //
      // Voiding is still correct for a quote - it retires the estimate so it
      // stops counting as a live order - it just must not touch inventory.
      if (sale.isQuote) {
        transaction.update(saleRef, {
          'is_voided': true,
          'void_reason': reason,
        });
        return;
      }

      // Every read must happen before the first write inside a transaction;
      // Firestore rejects the whole thing with FAILED_PRECONDITION otherwise.
      // This used to mark the sale voided and *then* read each product inside
      // the loop below, so voiding a sale always failed with "Could not void
      // sale" and the stock was never returned. saveSaleTransaction above
      // already gets the order right.
      //
      // Aggregated by product id so two lines for the same product are restocked
      // once, from a single read, instead of racing two writes off the same
      // snapshot.
      final restockByProduct = <String, double>{};
      for (final li in sale.lineItems) {
        restockByProduct[li.productId] =
            (restockByProduct[li.productId] ?? 0) + li.qtyOrArea;
      }
      final productIds = restockByProduct.keys.toList();
      final productRefs = productIds.map((id) => _products.doc(id)).toList();
      final productSnaps =
          await Future.wait(productRefs.map((ref) => transaction.get(ref)));

      transaction.update(saleRef, {
        'is_voided': true,
        'void_reason': reason,
      });

      for (int i = 0; i < productIds.length; i++) {
        final snap = productSnaps[i];
        if (!snap.exists) continue;
        final productData = snap.data() as Map<String, dynamic>;
        final currentStock =
            (productData['current_stock'] as num?)?.toDouble() ?? 0;
        transaction.update(productRefs[i],
            {'current_stock': currentStock + restockByProduct[productIds[i]]!});
      }
    });
  }

  // Opening Balance
  Future<void> setOpeningBalance(OpeningBalance ob) =>
      _openingBalances.doc(ob.id).set(ob.toMap());

  Stream<QuerySnapshot> get openingBalanceStream =>
      _openingBalances.orderBy('date', descending: true).limit(1).snapshots();

  // Shop Profile
  DocumentReference get _shopProfile => _db
      .collection('users')
      .doc(_uid)
      .collection('settings')
      .doc('shopProfile');

  Future<void> setShopProfile(ShopProfile profile) =>
      _shopProfile.set(profile.toMap());

  Future<ShopProfile?> getShopProfile() async {
    final snap = await _shopProfile.get();
    if (!snap.exists) return null;
    return ShopProfile.fromMap(snap.data() as Map<String, dynamic>);
  }

  Stream<ShopProfile?> shopProfileStream() {
    return _shopProfile.snapshots().map((snap) {
      if (!snap.exists) return null;
      return ShopProfile.fromMap(snap.data() as Map<String, dynamic>);
    });
  }

  // Cost Price History
  CollectionReference get _costPriceHistory =>
      _db.collection('users').doc(_uid).collection('cost_price_history');

  Future<void> updateCostPrice(String productId, double newCostPrice,
      {String note = ''}) async {
    final productRef = _products.doc(productId);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(productRef);
      if (!snap.exists) throw Exception('Product not found');
      final data = snap.data() as Map<String, dynamic>;
      final oldCostPrice = (data['cost_price'] as num?)?.toDouble() ?? 0;
      transaction.update(productRef, {'cost_price': newCostPrice});
      final historyId = _db.collection('_ids').doc().id;
      final history = CostPriceHistory(
        id: historyId,
        productId: productId,
        oldCostPrice: oldCostPrice,
        newCostPrice: newCostPrice,
        date: DateTime.now(),
        note: note,
      );
      transaction.set(_costPriceHistory.doc(historyId), history.toMap());
    });
  }

  Stream<List<CostPriceHistory>> costPriceHistoryStream(String productId) {
    return _costPriceHistory
        .where('product_id', isEqualTo: productId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                CostPriceHistory.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }
}
