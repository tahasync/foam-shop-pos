import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/widgets/design_system/brand_mark.dart';

void main() {
  testWidgets('the painter pixel probes match the brand geometry',
      (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1024, 1024);
      const painter = FoamMarkPainter(showField: true);
      painter.paint(canvas, size);
      final image = await recorder.endRecording().toImage(1024, 1024);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bytes, isNotNull);

      final pixel = bytes!;
      int alphaAt(int x, int y) => pixel.getUint8((y * 1024 + x) * 4 + 3);
      Color colorAt(int x, int y) {
        final offset = (y * 1024 + x) * 4;
        return Color.fromARGB(
          pixel.getUint8(offset + 3),
          pixel.getUint8(offset),
          pixel.getUint8(offset + 1),
          pixel.getUint8(offset + 2),
        );
      }

      final top = MarkGeometry.slabOrigins[2];
      final middle = MarkGeometry.slabOrigins[1];
      final topGapY =
          (top.dy + MarkGeometry.slabH + MarkGeometry.gap / 2).round();
      final middleGapY =
          (middle.dy + MarkGeometry.slabH + MarkGeometry.gap / 2).round();
      final pore = MarkGeometry.pores[0];
      final poreX = (top.dx + pore.$1).round();
      final poreY = (top.dy + pore.$2).round();

      expect(alphaAt(30, 30), 0, reason: 'rounded-tile corner is transparent');
      expect(colorAt(100, 100), MarkGeometry.navy, reason: 'tile field');
      expect(colorAt(500, 330), MarkGeometry.foam, reason: 'top layer');
      expect(colorAt(500, topGapY), MarkGeometry.navy,
          reason: 'the top-to-middle cut-out shows the field');
      expect(colorAt(500, 580), MarkGeometry.mauve, reason: 'middle layer');
      expect(colorAt(500, middleGapY), MarkGeometry.navy,
          reason: 'the middle-to-bottom cut-out shows the field');
      expect(colorAt(500, 700), MarkGeometry.periwinkle,
          reason: 'bottom layer');
      expect(colorAt(poreX, poreY), MarkGeometry.mauve, reason: 'top pore');
      expect(colorAt(900, 900), MarkGeometry.slate, reason: 'accent disc');

      image.dispose();
    });
  });
}
