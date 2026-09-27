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
import '../widgets/design_system/design_system.dart';
import 'inventory_screen.dart';
import 'sales_entry_screen.dart';
import 'customer_khata_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  /// Slimmed from 70 → 58.
  ///
  /// The old 70dp pill plus 16dp gaps made the bar read as a heavy slab that
  /// competed with the content above it. 58dp is the sweet spot: it still clears
  /// the 48dp minimum touch target for every destination (the icons are laid
  /// out vertically inside a full-height tap area), but it stops dominating the
  /// screen on short devices.
  static const double kNavPillHeight = 58;

  static const double kNavPillBottomMargin = 10;
  static const double kNavPillFabGap = 14;

  /// The bottom inset every scrollable tab must reserve so its last row is not
  /// permanently hidden behind the floating nav pill.
  ///
  /// Bug fixed here: each tab computed this itself and they disagreed —
  /// Dashboard/Khata/Sales used `120 + bottom` while Inventory used a flat
  /// `80`, and none of them accounted for the pill's own height plus the
  /// bottom margin. Scrolling to the end of a list therefore parked content
  /// underneath the nav. One constant, one definition, no drift.
  static double contentBottomInset(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return kNavPillHeight +
        kNavPillBottomMargin +
        kNavPillFabGap +
        AppSpacing.xxl +
        safeBottom;
  }

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

  void _checkNotifications(
      List<Product> products, List<Sale> sales, List<Payment> payments) {
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
    // One watch, two reads. This previously called `ref.watch` on the same
    // provider twice in a row (`lowStockCount` and `khataCount`); the second
    // watch re-subscribed for a value already in hand.
    final as = ref.watch(accountingSummaryProvider);
    final summary = as.asData?.value;
    final lowStockCount = summary?.lowStockCount ?? 0;

    // The unread dot on the Khata tab means "someone owes you money", so it is
    // driven by the total outstanding balance rather than a customer count.
    final hasOutstandingBaqaya = (summary?.totalCustomerBaqaya ?? 0) > 0;

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

    // One shared inset, consumed by every tab and by the FAB.
    final contentInset = HomeScreen.contentBottomInset(context);
    final screens = <Widget>[
      DashboardScreen(
        onLowStockTap: _goToInventory,
        onNewSale: () => setState(() => _tab = 1),
        bottomInset: contentInset,
      ),
      SalesEntryScreen(bottomInset: contentInset),
      InventoryScreen(
        initialLowStockFilter: _invLowStockFilter,
        highlightProductId: _invHighlightId,
        fabBottomClearance: contentInset,
      ),
      CustomerKhataScreen(bottomInset: contentInset),
    ];

    return Scaffold(
      extendBody: true,
      body: screens[_tab],
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
                left: 16, right: 16, bottom: HomeScreen.kNavPillBottomMargin),
            child: GlassContainer(
              radius: 22,
              // The ONLY frosted surface in the app. It floats over scrolling
              // content, so the blur is doing real work here — separating the
              // nav from the list passing underneath.
              level: AppGlassLevel.floating,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: SafeArea(
                top: false,
                bottom: false,
                child: SizedBox(
                  height: HomeScreen.kNavPillHeight,
                  child: CustomNavBar(
                    currentIndex: _tab,
                    onTap: (i) => setState(() => _tab = i),
                    showInventoryDot: lowStockCount > 0,
                    showKhataDot: hasOutstandingBaqaya,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
