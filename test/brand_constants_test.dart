import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/utils/brand.dart';

void main() {
  test('the product name and tagline match the brand board', () {
    expect(AppBrand.name, 'Foam Shop');
    expect(AppBrand.tagline, 'Every sale. Every stock. Every khata.');
  });

  test('the app code and platform labels do not use the retired names', () {
    final candidates = <File>[
      ...Directory('lib').listSync(recursive: true).whereType<File>(),
      File('android/app/src/main/AndroidManifest.xml'),
      ...Directory('web').listSync(recursive: true).whereType<File>(),
    ];
    final sources = candidates.where((file) {
      final path = file.path.toLowerCase();
      return path.endsWith('.dart') ||
          path.endsWith('.xml') ||
          path.endsWith('.html') ||
          path.endsWith('.json');
    });
    for (final file in sources) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('Foam Shop POS')), reason: file.path);
      expect(source, isNot(contains('Smart POS')), reason: file.path);
    }
  });

  test('the sign-in heading and subtitle use the shared brand strings', () {
    final source = File('lib/screens/sign_in_screen.dart').readAsStringSync();
    expect(source, contains('AppBrand.name'));
    expect(source, contains('AppBrand.tagline'));
  });

  test('the descriptor remains a separate product string', () {
    expect(AppBrand.descriptor, 'Digital Register');
  });
}
