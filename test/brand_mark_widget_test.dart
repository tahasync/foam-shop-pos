import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/widgets/design_system/brand_mark.dart';

void main() {
  for (final size in [38.0, 56.0, 64.0]) {
    testWidgets('BrandMark at $size dp keeps its existing footprint',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(child: BrandMark(size: size, iconSize: size / 2)),
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(BrandMark)), Size.square(size));
        final node = tester.getSemantics(find.byType(BrandMark));
        expect(node.label, 'Foam Shop');
        expect(node.flagsCollection.isImage, isTrue);
      } finally {
        semantics.dispose();
      }
    });
  }
}
