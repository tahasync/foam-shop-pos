import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/main.dart';

void main() {
  testWidgets('App smoke test - renders without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FoamShopApp()));
    expect(find.byType(FoamShopApp), findsOneWidget);
  });
}
