import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/widgets/design_system/brand_mark.dart';
import 'package:foam_shop_register/theme/app_theme.dart';
import 'package:foam_shop_register/utils/brand.dart';

Map<String, dynamic> _mark() =>
    jsonDecode(File('design/brand/brand/mark.json').readAsStringSync())
        as Map<String, dynamic>;

String _source(String path) => File(path).readAsStringSync();

List<String> _paths(String source) => RegExp(r'android:pathData="([^"]+)"')
    .allMatches(source)
    .map((match) => match.group(1)!)
    .toList();

void main() {
  test('mark constants and app palette match the canonical JSON', () {
    final mark = _mark();
    final slab = mark['slab'] as Map<String, dynamic>;
    final accent = mark['accent'] as List<dynamic>;
    final palette = mark['palette'] as Map<String, dynamic>;

    expect(mark['space'], MarkGeometry.space);
    expect(slab['w'], MarkGeometry.slabW);
    expect(slab['h'], MarkGeometry.slabH);
    expect(slab['r'], MarkGeometry.slabR);
    expect(slab['gap'], MarkGeometry.gap);
    expect(
        slab['xs'], MarkGeometry.slabOrigins.map((point) => point.dx).toList());
    expect(
        slab['ys'], MarkGeometry.slabOrigins.map((point) => point.dy).toList());
    expect(mark['pores'],
        MarkGeometry.pores.map((pore) => [pore.$1, pore.$2, pore.$3]).toList());
    expect(mark['tileRadius'], MarkGeometry.tileRadius);
    expect(accent, [
      MarkGeometry.accent.$1,
      MarkGeometry.accent.$2,
      MarkGeometry.accent.$3
    ]);
    expect(mark['adaptiveScale'], MarkGeometry.adaptiveScale);

    final appColors = AppTheme.light().extension<AppColors>()!;
    expect(palette['ink'],
        '#${BrandPalette.deepInk.toRadixString(16).substring(2).toUpperCase()}');
    expect(palette['navy'],
        '#${appColors.primary.toARGB32().toRadixString(16).substring(2).toUpperCase()}');
    expect(palette['slate'],
        '#${appColors.brandSolid.toARGB32().toRadixString(16).substring(2).toUpperCase()}');
    expect(palette['periwinkle'],
        '#${BrandPalette.periwinkle.toRadixString(16).substring(2).toUpperCase()}');
    expect(palette['mauve'],
        '#${appColors.accent.toARGB32().toRadixString(16).substring(2).toUpperCase()}');
    expect(palette['foam'],
        '#${appColors.surface.toARGB32().toRadixString(16).substring(2).toUpperCase()}');
  });

  test('Android brand vectors use the canonical paths and colour palette', () {
    final paths = _mark()['paths'] as Map<String, dynamic>;
    final foreground = _paths(
      _source('android/app/src/main/res/drawable/ic_launcher_foreground.xml'),
    );
    final monochrome = _paths(
      _source('android/app/src/main/res/drawable/ic_launcher_monochrome.xml'),
    );
    final splash = _paths(
      _source('android/app/src/main/res/drawable/splash_icon.xml'),
    );
    final notification = _paths(
      _source('android/app/src/main/res/drawable/ic_stat_foam_shop.xml'),
    );

    expect(foreground, [
      paths['bottom'],
      paths['middle'],
      paths['top'],
      ...(paths['pores'] as List<dynamic>),
    ]);
    expect(monochrome, [paths['mono']]);
    expect(splash, [
      'M171,512 a341,341 0 1,0 682,0 a341,341 0 1,0 -682,0 Z',
      paths['bottom'],
      paths['middle'],
      paths['top'],
      ...(paths['pores'] as List<dynamic>),
    ]);
    expect(notification, [paths['monoNoPores']]);

    final brandColors =
        _source('android/app/src/main/res/values/brand_colors.xml');
    final colorEntries = Map.fromEntries(
      RegExp(r'<color name="brand_(\w+)">#FF([0-9A-Fa-f]{6})</color>')
          .allMatches(brandColors)
          .map((match) => MapEntry(
                match.group(1)!,
                '#${match.group(2)!.toUpperCase()}',
              )),
    );
    expect(colorEntries, _mark()['palette']);
  });

  test('brand XML and SVG assets stay flat and opaque', () {
    final files = <File>[
      ...Directory('android/app/src/main/res/drawable')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.xml')),
      ...Directory('design/brand')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.svg')),
    ];
    final violations = <String>[];
    final forbidden = RegExp(
      r'gradient|android:alpha|\bopacity\s*=|\bfilter\s*=',
      caseSensitive: false,
    );
    for (final file in files) {
      final content = file.readAsStringSync().replaceAll(
            RegExp(r'<!--.*?-->', dotAll: true),
            '',
          );
      if (forbidden.hasMatch(content)) violations.add(file.path);
    }
    expect(violations, isEmpty, reason: 'brand artwork uses flat solid fills');
  });

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
