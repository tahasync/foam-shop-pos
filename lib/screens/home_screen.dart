import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/payment.dart';
import '../providers/product_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/payment_provider.dart';
import '../services/update_checker.dart';
import '../services/notification_service.dart';
import '../widgets/custom_nav_bar.dart';
import 'inventory_screen.dart';
import 'sales_entry_screen.dart';
import 'customer_khata_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  static const double kNavPillHeight = 64;
  static const double kNavPillBottomMargin = 12;
  static const double kNavPillFabGap = 16;
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  bool _invLowStockFilter = false;
  String? _invHighlightId;
  bool _notifiedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  void _checkNotifications(List<Product> products, List<Sale> sales, List<Payment> payments) {
    LocalNotificationService.checkAndNotify(
      products: products,
      sales: sales,
      payments: payments,
    );
  }

  void _goToInventory() {
    final products = ref.read(productsStreamProvider).asData?.value ?? [];
    final lowStock = products.where((p) => p.isLowStock).toList();
    if (lowStock.length == 1) {
      _invHighlightId = lowStock.first.id;
      _invLowStockFilter = false;
    } else {
      _invLowStockFilter = lowStock.isNotEmpty;
      _invHighlightId = null;
    }
    setState(() => _tab = 2);
  }

  Future<void> _checkUpdate() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final installed = pkg.version;
      final update = await checkForUpdate();
      if (update == null || !mounted) return;
      if (isNewerVersion(installed, update.tagName)) {
        showUpdateDialog(context, update);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final as = ref.watch(accountingSummaryProvider);
    final lowStockCount = as.asData?.value.lowStockCount ?? 0;
    final khataCount = ref.watch(accountingSummaryProvider).asData?.value.totalCustomerBaqaya ?? 0;

    if (!_notifiedOnce) {
      final products = ref.read(productsStreamProvider).asData?.value;
      final sales = ref.read(salesStreamProvider).asData?.value;
      final payments = ref.read(paymentsStreamProvider).asData?.value;
      if (products != null && sales != null && payments != null) {
        _notifiedOnce = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkNotifications(products, sales, payments);
        });
      }
    }

    final cs = Theme.of(context).colorScheme;

    final botPad = MediaQuery.of(context).padding.bottom;
    final fabClearance = HomeScreen.kNavPillHeight + HomeScreen.kNavPillBottomMargin + HomeScreen.kNavPillFabGap + botPad;
    final screens = <Widget>[
      DashboardScreen(onLowStockTap: _goToInventory),
      const SalesEntryScreen(),
      InventoryScreen(
        initialLowStockFilter: _invLowStockFilter,
        highlightProductId: _invHighlightId,
        fabBottomClearance: fabClearance,
      ),
      const CustomerKhataScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: screens[_tab],
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: HomeScreen.kNavPillBottomMargin),
            child: Container(
              height: HomeScreen.kNavPillHeight,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 26, offset: const Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: CustomNavBar(
                  currentIndex: _tab,
                  onTap: (i) => setState(() => _tab = i),
                  showInventoryDot: lowStockCount > 0,
                  showKhataDot: khataCount > 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}