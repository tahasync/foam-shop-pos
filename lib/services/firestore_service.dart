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

  CollectionReference get _products => _db.collection('users').doc(_uid).collection('products');
  CollectionReference get _customers => _db.collection('users').doc(_uid).collection('customers');
  CollectionReference get _suppliers => _db.collection('users').doc(_uid).collection('suppliers');
  CollectionReference get _sales => _db.collection('users').doc(_uid).collection('sales');
  CollectionReference get _purchases => _db.collection('users').doc(_uid).collection('purchases');
  CollectionReference get _expenses => _db.collection('users').doc(_uid).collection('expenses');
  CollectionReference get _payments => _db.collection('users').doc(_uid).collection('payments');
  CollectionReference get _supplierPayments => _db.collection('users').doc(_uid).collection('supplier_payments');
  CollectionReference get _openingBalances => _db.collection('users').doc(_uid).collection('opening_balances');

  String generateId() {
    return _db.collection('_ids').doc().id;
  }

  // Products
  Future<void> addProduct(Product p) => _products.doc(p.id).set(p.toMap());
  Future<void> updateProduct(Product p) => _products.doc(p.id).update(p.toMap());
  Future<void> archiveProduct(String id) => _products.doc(id).update({'is_archived': true});
  Stream<QuerySnapshot> get productsStream => _products.where('is_archived', isEqualTo: false).snapshots();

  // Customers
  Future<void> addCustomer(Customer c) => _customers.doc(c.id).set(c.toMap());
  Future<void> updateCustomer(Customer c) => _customers.doc(c.id).update(c.toMap());
  Future<void> archiveCustomer(String id) => _customers.doc(id).update({'is_archived': true});
  Stream<QuerySnapshot> get customersStream => _customers.where('is_archived', isEqualTo: false).snapshots();
  Stream<QuerySnapshot> get customersWithBaqayaStream =>
      _customers.where('baqaya', isGreaterThan: 0).where('is_archived', isEqualTo: false).snapshots();

  static const walkInCustomerId = 'walk_in_customer';
  Future<Customer> ensureWalkInCustomer() async {
    final ref = _customers.doc(walkInCustomerId);
    final snap = await ref.get();
    if (snap.exists) {
      return Customer.fromMap(snap.data() as Map<String, dynamic>);
    }
    final c = Customer(id: walkInCustomerId, name: 'Walk-in Customer', phone: '');
    await ref.set(c.toMap());
    return c;
  }

  // Suppliers
  Future<void> addSupplier(Supplier s) => _suppliers.doc(s.id).set(s.toMap());
  Future<void> updateSupplier(Supplier s) => _suppliers.doc(s.id).update(s.toMap());
  Future<void> archiveSupplier(String id) => _suppliers.doc(id).update({'is_archived': true});
  Stream<QuerySnapshot> get suppliersStream => _suppliers.where('is_archived', isEqualTo: false).snapshots();

  // Sales
  Future<void> addSale(Sale s) => _sales.doc(s.id).set(s.toMap());
  Future<void> updateSale(Sale s) => _sales.doc(s.id).update(s.toMap());
  Future<Sale?> getSale(String id) async {
    final snap = await _sales.doc(id).get();
    if (!snap.exists) return null;
    return Sale.fromMap(snap.data() as Map<String, dynamic>);
  }
  Stream<QuerySnapshot> salesStream({DateTime? from, DateTime? to}) {
    Query q = _sales.orderBy('date', descending: true);
    if (from != null) q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null) q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    return q.snapshots();
  }
  Future<List<Sale>> getCustomerSales(String customerId, {int limit = 5}) async {
    final snap = await _sales
        .where('customer_id', isEqualTo: customerId)
        .where('is_quote', isEqualTo: false)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => Sale.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  // Purchases
  Future<void> addPurchase(Purchase p) => _purchases.doc(p.id).set(p.toMap());
  Stream<QuerySnapshot> purchasesStream({DateTime? from, DateTime? to}) {
    Query q = _purchases.orderBy('date', descending: true);
    if (from != null) q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null) q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    return q.snapshots();
  }

  // Expenses
  Future<void> addExpense(Expense e) => _expenses.doc(e.id).set(e.toMap());
  Stream<QuerySnapshot> expensesStream({DateTime? from, DateTime? to}) {
    Query q = _expenses.orderBy('date', descending: true);
    if (from != null) q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null) q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    return q.snapshots();
  }

  // Payments (Customer Recovery)
  Future<void> addPayment(Payment p) => _payments.doc(p.id).set(p.toMap());

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
    if (from != null) q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null) q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    return q.snapshots();
  }

  // Supplier Payments
  Future<void> addSupplierPayment(SupplierPayment sp) => _supplierPayments.doc(sp.id).set(sp.toMap());
  Stream<QuerySnapshot> supplierPaymentsStream({DateTime? from, DateTime? to}) {
    Query q = _supplierPayments.orderBy('date', descending: true);
    if (from != null) q = q.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    if (to != null) q = q.where('date', isLessThanOrEqualTo: to.toIso8601String());
    return q.snapshots();
  }

  // Idempotency
  Future<bool> saleExistsByUuid(String uuid) async {
    final snap = await _sales.where('transaction_uuid', isEqualTo: uuid).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  // Atomic sale transaction — also updates customer baqaya
  Future<void> saveSaleTransaction(Sale sale, Map<String, double> deductions) async {
    final exists = await saleExistsByUuid(sale.transactionUuid ?? sale.id);
    if (exists) return;
    await _db.runTransaction((transaction) async {
      final saleRef = _sales.doc(sale.id);
      for (final entry in deductions.entries) {
        final productRef = _products.doc(entry.key);
        final snap = await transaction.get(productRef);
        if (!snap.exists) throw Exception('Product ${entry.key} not found');
        final data = snap.data() as Map<String, dynamic>;
        final currentStock = (data['current_stock'] as num?)?.toDouble() ?? 0;
        if (currentStock < entry.value) {
          throw Exception('Insufficient stock for product ${entry.key}');
        }
        transaction.update(productRef, {'current_stock': currentStock - entry.value});
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
  Future<void> restockTransaction(String productId, double restockQty, double unitCost, double amountPaid, {String supplierId = ''}) async {
    await _db.runTransaction((transaction) async {
      final productRef = _products.doc(productId);
      final snap = await transaction.get(productRef);
      if (!snap.exists) throw Exception('Product not found');
      final data = snap.data() as Map<String, dynamic>;
      final currentStock = (data['current_stock'] as num?)?.toDouble() ?? 0;
      final costPrice = (data['cost_price'] as num?)?.toDouble() ?? 0;

      final totalStock = currentStock + restockQty;
      if (totalStock <= 0) return;
      final weightedCost = ((currentStock * costPrice) + (restockQty * unitCost)) / totalStock;

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

      transaction.update(saleRef, {
        'is_voided': true,
        'void_reason': reason,
      });

      for (final li in sale.lineItems) {
        final productRef = _products.doc(li.productId);
        final snap = await transaction.get(productRef);
        if (snap.exists) {
          final productData = snap.data() as Map<String, dynamic>;
          final currentStock = (productData['current_stock'] as num?)?.toDouble() ?? 0;
          transaction.update(productRef, {'current_stock': currentStock + li.qtyOrArea});
        }
      }
    });
  }

  Future<void> restoreStockAfterVoid(Sale sale) async {
    await _db.runTransaction((transaction) async {
      for (final li in sale.lineItems) {
        final productRef = _products.doc(li.productId);
        final snap = await transaction.get(productRef);
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final currentStock = (data['current_stock'] as num).toDouble();
          transaction.update(productRef, {'current_stock': currentStock + li.qtyOrArea});
        }
      }
    });
  }

  Future<void> revertSaleStock(Sale sale) => restoreStockAfterVoid(sale);

  // Opening Balance
  Future<void> setOpeningBalance(OpeningBalance ob) => _openingBalances.doc(ob.id).set(ob.toMap());
  Future<OpeningBalance?> getOpeningBalance() async {
    final snap = await _openingBalances.orderBy('date', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return OpeningBalance.fromMap(snap.docs.first.data() as Map<String, dynamic>);
  }

  Stream<QuerySnapshot> get openingBalanceStream =>
      _openingBalances.orderBy('date', descending: true).limit(1).snapshots();

  // Shop Profile
  DocumentReference get _shopProfile =>
      _db.collection('users').doc(_uid).collection('settings').doc('shopProfile');

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

  Future<void> updateCostPrice(String productId, double newCostPrice, {String note = ''}) async {
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
            .map((d) => CostPriceHistory.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }
}
