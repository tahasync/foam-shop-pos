import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/theme/app_theme.dart';
import 'package:foam_shop_register/widgets/design_system/design_system.dart';

/// Regression tests for the post-sign-in loading state.
///
/// The bug these prevent: after a successful Google sign-in the app waited on
/// the Firestore shop-profile fetch, which on a cold start takes 15-25 seconds.
/// That whole window rendered as a bare `CircularProgressIndicator` on an empty
/// `Scaffold` - a blank white page that reads as a crash. Shopkeepers responded
/// by tapping sign-in repeatedly, which tripped the 5-per-minute rate limiter in
/// `AuthService` and turned a slow-but-successful load into a hard "too many
/// attempts" failure.
///
/// The rule this file encodes: a blocking wait must never be silent. It must
/// name what it is waiting for, and it must look like part of the app.
void main() {
  Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      home: child,
    );
  }

  group('LoadingScreen', () {
    testWidgets('names the wait instead of rendering a silent page',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoadingScreen(
        title: 'Setting up your shop',
        subtitle: 'Fetching your products, sales and khata.',
      )));

      expect(find.text('Setting up your shop'), findsOneWidget);
      expect(
        find.text('Fetching your products, sales and khata.'),
        findsOneWidget,
      );
      // A wait the user cannot read is the bug, so the indicator is part of the
      // contract rather than an implementation detail.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('falls back to a readable default title', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingScreen()));

      expect(find.text('Loading'), findsOneWidget);
    });

    testWidgets('omits the subtitle line when none is given', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingScreen(title: 'Working')));

      expect(find.text('Working'), findsOneWidget);
      // Guards against a stray empty Text inflating the layout.
      expect(find.text(''), findsNothing);
    });

    testWidgets('renders without overflow on a small screen', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const LoadingScreen(
        title: 'Setting up your shop',
        subtitle: 'Fetching your products, sales and khata. '
            'This can take a moment on a slow connection.',
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        const LoadingScreen(
            title: 'Setting up your shop', subtitle: 'One sec.'),
        brightness: Brightness.dark,
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('can drop the brand mark for a nested wait', (tester) async {
      await tester.pumpWidget(_wrap(
        const LoadingScreen(title: 'Updating', showBrand: false),
      ));

      expect(find.byType(BrandMark), findsNothing);
      expect(find.text('Updating'), findsOneWidget);
    });
  });

  group('AuthGate wiring', () {
    // Source-level guard. A behavioural test cannot easily hold
    // `shopProfileFutureProvider` in its loading state without booting Firebase,
    // but the regression that matters is a *silent* loading branch, and that is
    // a property of the source.
    final mainSource = File('lib/main.dart').readAsStringSync();

    test('the shop-profile loading branch uses LoadingScreen', () {
      expect(
        mainSource,
        contains('loading: () => const LoadingScreen('),
        reason: 'AuthGate must render LoadingScreen while the shop profile '
            'loads, not a bare spinner on an empty Scaffold.',
      );
    });

    test('no bare spinner is left on an empty Scaffold in AuthGate', () {
      expect(
        mainSource,
        isNot(contains('body: Center(child: CircularProgressIndicator())')),
        reason:
            'The bare spinner on an empty Scaffold is the exact blank-white '
            'page this widget was introduced to remove.',
      );
    });

    test('the auth-state loading branch also uses LoadingScreen', () {
      final gateStart = mainSource.indexOf('class AuthGate');
      expect(gateStart, greaterThan(-1), reason: 'AuthGate must still exist.');
      final gate = mainSource.substring(gateStart);
      expect(gate, contains('LoadingScreen('));
    });
  });
}
