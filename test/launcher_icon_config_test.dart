import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const res = 'android/app/src/main/res';

  String markupOnly(String xml) =>
      xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  (int, int) pngDimensions(File file) {
    final bytes = file.readAsBytesSync();
    expect(bytes.length, greaterThanOrEqualTo(24));
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    return (data.getUint32(16), data.getUint32(20));
  }

  test('adaptive square and round icons reference all three shared layers', () {
    final square = markupOnly(
        File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync());
    final round = markupOnly(
        File('$res/mipmap-anydpi-v26/ic_launcher_round.xml')
            .readAsStringSync());
    for (final layer in [
      'ic_launcher_background',
      'ic_launcher_foreground',
      'ic_launcher_monochrome',
    ]) {
      expect(square, contains(layer));
      expect(round, contains(layer));
    }
  });

  test('background fills the 1024 canvas with only the brand navy and disc',
      () {
    final xml = markupOnly(
        File('$res/drawable/ic_launcher_background.xml').readAsStringSync());
    expect(xml, contains('android:viewportWidth="1024"'));
    expect(xml, contains('android:viewportHeight="1024"'));
    expect(xml, contains('@color/brand_navy'));
    expect(xml, contains('@color/brand_slate'));
    expect(xml, contains('M0,0h1024v1024h-1024z'));
    expect(xml, isNot(contains('<gradient')));
    expect(xml, isNot(contains('android:alpha')));
    expect(xml, isNot(contains('android:fillAlpha')));
  });

  test('foreground is transparent and applies the mark safe-zone scale', () {
    final xml = markupOnly(
        File('$res/drawable/ic_launcher_foreground.xml').readAsStringSync());
    expect(xml, contains('android:viewportWidth="1024"'));
    expect(xml, contains('android:viewportHeight="1024"'));
    expect(xml, contains('android:scaleX="0.86"'));
    expect(xml, contains('android:scaleY="0.86"'));
    for (final color in [
      '@color/brand_periwinkle',
      '@color/brand_mauve',
      '@color/brand_foam',
    ]) {
      expect(xml, contains(color));
    }
    expect(xml, isNot(contains('M0,0h1024v1024h-1024z')));
  });

  test('monochrome layer is present, opaque, white and uses a cut-out path',
      () {
    final adaptive = markupOnly(
        File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync());
    final xml = markupOnly(
        File('$res/drawable/ic_launcher_monochrome.xml').readAsStringSync());
    expect(adaptive, contains('<monochrome'));
    expect(xml, contains('#FFFFFFFF'));
    expect(xml, contains('android:fillType="evenOdd"'));
    expect(xml, isNot(contains('android:alpha')));
    expect(xml, isNot(contains('<background')));
  });

  test('legacy launcher PNGs have the exact density dimensions', () {
    const expected = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    for (final entry in expected.entries) {
      for (final variant in ['ic_launcher', 'ic_launcher_round']) {
        final file = File('$res/${entry.key}/$variant.png');
        expect(file.existsSync(), isTrue, reason: file.path);
        expect(pngDimensions(file), (entry.value, entry.value),
            reason: file.path);
      }
    }
  });

  test('Android manifest keeps app, launcher and notification icons wired', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:label="Foam Shop"'));
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    expect(manifest, contains('@drawable/ic_stat_foam_shop'));
    expect(manifest, contains('@color/notification_color'));
    expect(File('$res/drawable/ic_stat_foam_shop.xml').existsSync(), isTrue);
    expect(
        File('test/notification_icon_config_test.dart').existsSync(), isTrue);
  });

  test('Flutter icon config points at the real square master without hazards',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec,
        contains('image_path: "design/brand/icon/app-icon-square-1024.png"'));
    expect(pubspec, contains('Do NOT run flutter_launcher_icons.'));
    expect(File('design/brand/icon/app-icon-square-1024.png').existsSync(),
        isTrue);
    expect(File('assets/logo.svg').existsSync(), isFalse);
    expect(File('assets/logo.png').existsSync(), isFalse);
    expect(pubspec, isNot(contains('assets/logo.svg')));
    expect(pubspec, isNot(contains('assets/logo.png')));
  });

  test('splash uses the brand page colour and Android 12 icon on both themes',
      () {
    final colors = File('$res/values/brand_colors.xml').readAsStringSync();
    final darkColors =
        File('$res/values-night/brand_colors.xml').readAsStringSync();
    expect(colors, contains('<color name="brand_ink">#FF0E0D15</color>'));
    expect(colors, contains('<color name="brand_navy">#FF182346</color>'));
    expect(colors, contains('<color name="brand_slate">#FF3D5387</color>'));
    expect(
        colors, contains('<color name="brand_periwinkle">#FF7C83AD</color>'));
    expect(colors, contains('<color name="brand_mauve">#FFBFA9BA</color>'));
    expect(colors, contains('<color name="brand_foam">#FFF7F4F2</color>'));
    expect(
        colors, contains('<color name="splash_background">#FFF7F4F2</color>'));
    expect(darkColors,
        contains('<color name="splash_background">#FF14141A</color>'));
    for (final path in [
      '$res/drawable/launch_background.xml',
      '$res/drawable-v21/launch_background.xml',
    ]) {
      expect(File(path).readAsStringSync(), contains('@drawable/splash_icon'));
    }
    for (final path in [
      '$res/values-v31/styles.xml',
      '$res/values-night-v31/styles.xml',
    ]) {
      final xml = File(path).readAsStringSync();
      expect(xml, contains('@color/splash_background'));
      expect(xml, contains('@drawable/splash_icon'));
    }
  });

  test('web manifest points to the supplied Foam Shop icons', () {
    final manifest = File('web/manifest.json').readAsStringSync();
    expect(manifest, contains('"name": "Foam Shop"'));
    expect(manifest, contains('"src": "icons/Icon-192.png"'));
    expect(manifest, contains('"src": "icons/Icon-512.png"'));
    for (final name in [
      'Icon-192.png',
      'Icon-512.png',
      'Icon-maskable-192.png',
      'Icon-maskable-512.png',
    ]) {
      expect(File('web/icons/$name').existsSync(), isTrue, reason: name);
    }
    expect(File('web/favicon.png').existsSync(), isTrue);
  });

  test('iOS icon PNGs replace the kit slots without changing its manifest', () {
    final appIcons = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
    final manifest = File('${appIcons.path}/Contents.json');
    expect(manifest.existsSync(), isTrue);
    for (final name in [
      'Icon-App-20x20@1x.png',
      'Icon-App-20x20@2x.png',
      'Icon-App-20x20@3x.png',
      'Icon-App-29x29@1x.png',
      'Icon-App-40x40@3x.png',
      'Icon-App-60x60@3x.png',
      'Icon-App-76x76@2x.png',
      'Icon-App-83.5x83.5@2x.png',
      'Icon-App-1024x1024@1x.png',
    ]) {
      expect(File('${appIcons.path}/$name').existsSync(), isTrue, reason: name);
    }
  });
}
