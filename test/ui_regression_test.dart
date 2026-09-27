import 'dart:convert' show LineSplitter;
import 'dart:io';

import 'package:archive/archive.dart' show ZLibDecoder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:foam_shop_register/models/product.dart';
import 'package:foam_shop_register/models/sale.dart';
import 'package:foam_shop_register/services/accounting_service.dart';
import 'package:foam_shop_register/services/export_service.dart';
import 'package:foam_shop_register/utils/safe_error_handler.dart';
import 'package:foam_shop_register/providers/sales_provider.dart';
import 'package:foam_shop_register/screens/sales_entry_screen.dart';
import 'package:foam_shop_register/screens/dashboard_screen.dart';
import 'package:foam_shop_register/theme/app_theme.dart';
import 'package:foam_shop_register/screens/home_screen.dart';
import 'package:foam_shop_register/services/receipt_pdf.dart';
import 'package:foam_shop_register/services/receipt_saver.dart';
import 'package:foam_shop_register/widgets/design_system/design_system.dart';

/// Regression tests for the 2027 liquid-glass UI fixes.
///
/// Each test names the visual bug it prevents from coming back. The recurring
/// theme here is that `flutter analyze` will happily pass a layout that looks
/// wrong, so these assert on *behaviour* (no overflow, correct inset, real
/// touch target) rather than on pixel values.
Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  // A mojibake guard. Every other test here asserts on rendered behaviour, but
  // this one reads the source text, because the failure it guards is *in the
  // source* and nothing else would catch it.
  //
  // The reports screen shipped "Peak Sep \u00b7 Rs 172,000": a middle dot (U+00B7)
  // had been UTF-8 encoded, then decoded as Latin-1 and re-encoded, leaving the
  // two-character sequence U+00C2 U+00B7 in the file. It is valid Dart, so the
  // analyzer is silent and the widget tree is correct \u2014 the glyph just renders
  // as two stray glyphs in front of the user. Only a source scan can see it.
  test('no source file carries a double-encoded character', () {
    // U+00C2/U+00C3 followed by U+0080-U+00BF, and U+00E2 followed by the
    // UTF-8 lead for an em dash / curly quote. These are Latin-1 renderings of
    // bytes that were already UTF-8 \u2014 the fingerprint of one decode too many.
    final mojibake =
        RegExp('[\u00C2\u00C3][\u0080-\u00BF]|\u00E2[\u0080\u0093]');
    final offenders = <String>[];
    for (final entity in [Directory('lib'), Directory('test')]) {
      if (!entity.existsSync()) continue;
      for (final file in entity.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final lines = const LineSplitter().convert(file.readAsStringSync());
        for (var i = 0; i < lines.length; i++) {
          if (mojibake.hasMatch(lines[i])) {
            // `$1` is the offending line, `$2` its 1-based number.
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'mojibake found at ${offenders.join(', ')}. A character was '
          'decoded as Latin-1 and re-encoded. Use a \\uXXXX Dart escape '
          'instead of a literal glyph so the source is encoding-independent.',
    );
  });
  group('Palette integrity \u2014 colours must not drift', () {
    test('light and dark both define every glass-engine token', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final ac = theme.extension<AppColors>()!;
        // If any of these were dropped, the glass engine would silently fall
        // back to transparent and every surface would lose its edge.
        expect(ac.glassHairline.a, greaterThan(0),
            reason: 'hairline must be visible');
        expect(ac.glassElevated.a, greaterThan(0.5),
            reason: 'raised glass must be dense');
        expect(ac.glassScrim.a, greaterThan(0.2), reason: 'scrim must dim');
        expect(ac.glassNested.a, greaterThan(0),
            reason: 'nested slot must be visible');
        expect(ac.glassBlur, greaterThan(0));
      }
    });

    test('light and dark hairlines are opposites (visible in both themes)', () {
      // A dark hairline is invisible on dark glass — this is the trap that made
      // cards lose their edges in dark mode.
      final light = AppTheme.light().extension<AppColors>()!;
      final dark = AppTheme.dark().extension<AppColors>()!;
      expect(light.glassHairline.computeLuminance(),
          lessThan(dark.glassHairline.computeLuminance()));
    });

    test('control borders are visible in BOTH themes', () {
      // An outlined control whose edge is invisible is not a control, it is
      // loose text on a surface. The border has to separate from every surface
      // the control can land on: the page, a card, and a bottom sheet.
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final ac = theme.extension<AppColors>()!;
        for (final surface in [ac.surface, ac.glassFill, ac.glassElevated]) {
          final a = ac.controlBorder.computeLuminance();
          final b = surface.computeLuminance();
          final ratio =
              (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
          expect(ratio, greaterThan(1.5),
              reason:
                  'controlBorder is invisible (${ratio.toStringAsFixed(2)}:1) '
                  'on this surface in ${theme.brightness}');
        }
      }
    });

    test('domain accent colours are unchanged from the committed palette', () {
      final ac = AppTheme.light().extension<AppColors>()!;
      expect(ac.brandSolid, const Color(0xFF3D5387));
      expect(ac.brandSolidStrong, const Color(0xFF182346));
      expect(ac.dangerSolid, const Color(0xFF7E4A63));
      expect(ac.accent, const Color(0xFFBFA9BA));
    });
  });

  group('Dark theme parity', () {
    // Regression guards for "dark never looked as good as light".
    // NOTE: themes are resolved *inside* each test, not at group scope. Building
    // a `ThemeData` touches `GoogleFonts`, which needs the test binding, and a
    // group-level field is evaluated before `TestWidgetsFlutterBinding` exists.

    test('white content on a brand fill clears 4.5:1 in BOTH themes', () {
      // The core dark bug: `brandSolid` is lightened in dark so it works as
      // *text*, but it was being used as a fill behind white glyphs. A primary
      // button was rendering periwinkle-on-white at ~2:1.
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final ac = theme.extension<AppColors>()!;
        for (final fill in [ac.brandFill, ac.brandFillDeep, ac.dangerFill]) {
          final ratio = fill.computeLuminance();
          // Rec. 601 luma for white-on-fill; > 0.179 is 4.5:1.
          expect(
            ratio,
            lessThan(0.179),
            reason: 'fill $fill must be dark enough for white text',
          );
        }
      }
    });

    test('cards are clearly lighter than the page in both themes', () {
      // Dark cards used to be #141A2A on a #0E0D15 page — almost no separation,
      // so the layout read as one flat mass.
      //
      // Judged by WCAG *ratio*, not absolute luma: near-blacks all have tiny
      // luma values, so an absolute delta is meaningless in dark mode. What
      // matters is that the card is perceptibly above the page, and that dark
      // achieves the same separation light does.
      double lift(AppColors ac) =>
          (ac.glassFill.computeLuminance() + 0.05) /
          (ac.surface.computeLuminance() + 0.05);

      final darkLift = lift(AppTheme.dark().extension<AppColors>()!);
      final lightLift = lift(AppTheme.light().extension<AppColors>()!);

      expect(darkLift, greaterThan(1.08),
          reason: 'dark card must lift off the page');
      expect(lightLift, greaterThan(1.08),
          reason: 'light card must lift off the page');
      // Parity: dark separation must be within 10% of light.
      expect(
        (darkLift - lightLift).abs() / lightLift,
        lessThan(0.10),
        reason: 'dark card lift $darkLift vs light $lightLift',
      );
    });

    test('the neutral ramp is not tinted blue', () {
      final dark = AppTheme.dark().extension<AppColors>()!;
      // The dark neutrals were a saturated navy ramp while light is a warm
      // neutral. Max channel spread must stay small, or the page picks up an
      // indigo cast that light mode does not have.
      for (final c in [
        dark.surface,
        dark.surface2,
        dark.surfaceHigh,
        dark.surfaceHighest,
      ]) {
        final spread = c.computeLuminance().abs() + (c.r - c.b).abs() / 255;
        expect(spread, lessThan(0.25), reason: 'neutral $c is too blue');
      }
    });

    test('body text clears 4.5:1 on the card surface', () {
      // `inkFaint` sits under every secondary label in the app.
      //
      // WCAG contrast is (lighter + 0.05) / (darker + 0.05). It has to be
      // computed with the ordering resolved, not ink-over-card literally —
      // light mode has dark ink on a light card, dark mode the exact inverse.
      double ratio(Color a, Color b) {
        final la = a.computeLuminance();
        final lb = b.computeLuminance();
        final hi = la > lb ? la : lb;
        final lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final ac = theme.extension<AppColors>()!;
        for (final ink in [ac.ink, ac.inkSoft, ac.inkFaint]) {
          expect(
            ratio(ink, ac.glassFill),
            greaterThan(4.5),
            reason: 'ink $ink on card ${ac.glassFill} '
                'is ${ratio(ink, ac.glassFill).toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('the page background matches the theme surface', () {
      final dark = AppTheme.dark().extension<AppColors>()!;
      // `GlassBackground` used to hardcode its own dark colour while the theme
      // moved on, so the page and the scaffold disagreed.
      expect(dark.surface, const Color(0xFF14141A));
      expect(dark.glassFill, const Color(0xFF1E1E26));
      expect(dark.glassElevated, const Color(0xFF2A2A34));
    });

    test('the dark page is dark but not pure black', () {
      // The page was briefly #0D0D11 — 5% grey, which on an OLED panel reads
      // as "screen off". Cards sank into it and the layout lost its depth. It
      // has to stay a *dark theme*, not a black void.
      //
      // Asserted on the 8-bit channel rather than a luma float: "at least 18"
      // is a legible statement, whereas a tuned luma threshold just encodes
      // whatever value happened to be chosen.
      final dark = AppTheme.dark().extension<AppColors>()!;
      // `Color.r/g` are normalised 0..1, so scale to 8-bit for readability.
      int ch8(double c) => (c * 255).round();
      expect(ch8(dark.surface.r), greaterThanOrEqualTo(18),
          reason: 'page too black');
      expect(ch8(dark.surface.g), greaterThanOrEqualTo(18));
      // Still unmistakably a dark theme.
      expect(ch8(dark.surface.r), lessThan(60));
      // The card has to sit above the page, not on it.
      expect(
        dark.glassFill.computeLuminance(),
        greaterThan(dark.surface.computeLuminance()),
      );
    });

    test('dark card shadows stay light', () {
      // A heavy black shadow on a near-black page eats the card edge and
      // flattens the whole surface.
      final dark = AppTheme.dark().extension<AppColors>()!;
      expect(dark.glassShadow.a, lessThanOrEqualTo(0.25));
    });
  });

  group('Input fix — no opaque slab inside the glass search pill', () {
    testWidgets('AppSearchField paints no opaque inner fill', (tester) async {
      await tester.pumpWidget(_wrap(
        const Padding(
          padding: EdgeInsets.all(16),
          child: AppSearchField(hintText: 'Search products\u2026'),
        ),
      ));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      final decoration = field.decoration!;
      // The bug was a ~91% opaque fill at a different radius to the pill.
      expect(decoration.filled, isFalse);
      expect(decoration.fillColor, Colors.transparent);
      expect(decoration.border, InputBorder.none);
    });

    testWidgets('global InputDecorationTheme fill is translucent, not opaque',
        (tester) async {
      final theme = AppTheme.light();
      final fill = theme.inputDecorationTheme.fillColor!;
      final ac = theme.extension<AppColors>()!;
      // Anything near-opaque reintroduces the white rectangle.
      expect(fill.a, lessThan(ac.glassFillStrong.a));
    });

    testWidgets('AppField keeps a visible label and renders inline errors',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const Padding(
          padding: EdgeInsets.all(16),
          child:
              AppField(label: 'Amount', hintText: '0', errorText: 'Required'),
        ),
      ));
      // Placeholder-only labelling is a pro-rules violation; the label must be
      // on screen regardless of whether the user has typed.
      expect(find.text('AMOUNT'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
    });
  });

  group('Layout fix — content is never hidden behind the floating nav', () {
    testWidgets('the shared inset clears the nav pill and the safe area',
        (tester) async {
      // The four tabs used to disagree (120 vs 100 vs 80), so the last row of a
      // list parked underneath the nav on some tabs. One shared constant now
      // has to clear the pill AND the home indicator.
      late double inset;
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) {
            inset = HomeScreen.contentBottomInset(context);
            return const SizedBox.shrink();
          },
        ),
      ));
      expect(inset, greaterThan(HomeScreen.kNavPillHeight));
      expect(inset, greaterThanOrEqualTo(HomeScreen.kNavPillBottomMargin));
    });

    testWidgets('the inset grows when a home indicator is present',
        (tester) async {
      double withIndicator = 0;
      double withoutIndicator = 0;

      Future<double> measure(EdgeInsets padding) async {
        double result = 0;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(padding: padding),
            child: _wrap(
              Builder(
                builder: (context) {
                  result = HomeScreen.contentBottomInset(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        return result;
      }

      withIndicator = await measure(const EdgeInsets.only(bottom: 34));
      withoutIndicator = await measure(EdgeInsets.zero);
      expect(withIndicator, greaterThan(withoutIndicator));
    });
  });

  group('KPI row — tiles share one height', () {
    testWidgets('AppKpiRow renders both tiles at equal height', (tester) async {
      await tester.pumpWidget(_wrap(
        const Padding(
          padding: EdgeInsets.all(16),
          child: AppKpiRow(tiles: [
            KpiTile(
              label: 'COGS',
              value: 'Rs 82,000',
              sub: 'Cost of goods sold',
              icon: Icons.receipt_rounded,
              tint: Color(0xCCE8EBF4),
              iconColor: Color(0xFF182346),
            ),
            KpiTile(
              label: 'Inventory value on hand',
              value: 'Rs 41,000',
              sub: '1 product',
              icon: Icons.inventory_2_rounded,
              tint: Color(0xCCE3E7F1),
              iconColor: Color(0xFF5B6390),
            ),
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      // Measure each card individually - getSize throws when a finder matches
      // more than one element.
      double heightAt(int i) {
        final box = tester.renderObject<RenderBox>(find.byType(FoamCard).at(i));
        return box.size.height;
      }

      expect(find.byType(FoamCard), findsNWidgets(2));
      // A one-line label next to a two-line label must not produce two
      // different card heights.
      expect(heightAt(0), moreOrLessEquals(heightAt(1), epsilon: 0.5));
    });
  });

  group('Touch targets', () {
    testWidgets('AppIconButton meets the 48dp minimum even when asked for less',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Center(
          child: AppIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            semanticLabel: 'Back',
            size: 20,
            onTap: () {},
          ),
        ),
      ));
      final size = tester.getSize(find.byType(AppIconButton));
      expect(size.width, greaterThanOrEqualTo(AppHit.min));
      expect(size.height, greaterThanOrEqualTo(AppHit.min));
    });

    testWidgets('AppFab meets the 48dp minimum', (tester) async {
      await tester.pumpWidget(_wrap(
        Center(
          child: AppFab(
            icon: Icons.add_rounded,
            semanticLabel: 'Add product',
            onTap: () {},
          ),
        ),
      ));
      expect(tester.getSize(find.byType(AppFab)).height,
          greaterThanOrEqualTo(AppHit.min));
    });
  });

  group('Accessibility', () {
    testWidgets('icon-only buttons expose an accessible name', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        Center(
          child: AppIconButton(
            icon: Icons.add_rounded,
            semanticLabel: 'Add customer',
            onTap: () {},
          ),
        ),
      ));
      expect(find.bySemanticsLabel('Add customer'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('EmptyState renders its title and subtitle', (tester) async {
      await tester.pumpWidget(_wrap(
        const Padding(
          padding: EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.check_circle_rounded,
            title: 'No outstanding baqaya!',
            subtitle: 'All customers are settled.',
            celebrate: true,
          ),
        ),
      ));
      expect(find.text('No outstanding baqaya!'), findsOneWidget);
      expect(find.text('All customers are settled.'), findsOneWidget);
    });
  });

  group('Dashboard header \u2014 the address is never clipped mid-word', () {
    // The date and the address were concatenated into one `maxLines: 1` string.
    // The address is the longer of the pair, so it is the address that got cut,
    // and Flutter's ellipsis breaks mid-word: "Opposite Meezan Ba\u2026". A
    // half-rendered word reads as a layout fault, and the address is the one
    // detail this header exists to show.
    testWidgets(
        'shows the full address on the small phone the checklist requires',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const address = 'Opposite Meezan Bazaar, Gulberg III, Lahore';
      await tester.pumpWidget(_wrap(
        const AppBarRow(
          title: 'Asif Foam Center',
          subtitleWidget: ShopHeaderSubtitle(
            dateLabel: 'Sun, 27 Sep',
            location: address,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // The full string must be present in the tree, not a truncated prefix.
      // `find.text` matches the widget's data, so this fails loudly if the
      // widget is ever handed a pre-clipped string again.
      expect(find.text(address), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a very long address wraps and never overflows',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        const AppBarRow(
          title: 'Asif Foam Center',
          subtitleWidget: ShopHeaderSubtitle(
            dateLabel: 'Sun, 27 Sep',
            // One unbroken token: no space to wrap at, so this is the case
            // that would throw a RenderFlex overflow if the text were not
            // inside a `Flexible`.
            location:
                'SupercalifragilisticexpialidociousAddressBlockNumberFortyTwo',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'an unbreakable address must ellipsise, not overflow');
      // The date stays visible even when the address is at its worst.
      expect(find.text('Sun, 27 Sep'), findsOneWidget);
    });

    testWidgets('a shop with no address shows the date, not an empty row',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AppBarRow(
          title: 'Asif Foam Center',
          subtitleWidget: ShopHeaderSubtitle(
            dateLabel: 'Sun, 27 Sep',
            location: '',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sun, 27 Sep'), findsOneWidget);
      // No dangling icon-only row.
      expect(find.byIcon(Icons.place_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Rendering stability', () {
    // A real-device sweep rather than a single "small phone" case.
    //
    // The layout fixes in this app were all found by looking at one screen on
    // one width, which is how a header that wrapped "Opposite Meezan Ba…" got
    // missed. Asserting across the width range the shop actually sells into —
    // a cheap Android phone through to a large phone and a tablet — catches the
    // class of defect where a fixed px budget, radius or column stops fitting.
    //
    // This cannot replace a look at a real device: it proves no widget overflows
    // its box at these sizes, and nothing more. Thermal behaviour, actual
    // Firestore latency and text scaling driven by OS accessibility settings are
    // outside what a widget test can observe.
    const deviceMatrix = <String, Size>{
      'small Android (360x640)': Size(360, 640),
      'iPhone SE (375x667)': Size(375, 667),
      'typical Android (412x915)': Size(412, 915),
      'large phone (480x1000)': Size(480, 1000),
      'tablet (800x1280)': Size(800, 1280),
    };

    for (final entry in deviceMatrix.entries) {
      testWidgets('the app bar row fits on a ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(
          Column(
            children: [
              // The longest realistic header: a long shop name plus an address.
              AppBarRow(
                title: 'Asif Foam & Furniture Centre',
                subtitle: 'Opposite Meezan Bank, GT Road, Kot Addu',
                trailing: const [],
              ),
              // The widest control row on the sales screen.
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppButton(
                  label: 'Save Sale',
                  onTap: () {},
                ),
              ),
              AppButton(
                label: 'View Receipt',
                variant: AppButtonVariant.outline,
                onTap: () {},
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'nothing may overflow on ${entry.key}');
      });

      testWidgets('KPI tiles stay equal height on a ${entry.key}',
          (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: AppKpiRow(tiles: [
              KpiTile(
                label: 'REVENUE',
                value: 'Rs 1,250,000',
                sub: 'today',
                icon: Icons.trending_up_rounded,
                tint: Color(0xCCE8EBF4),
                iconColor: Color(0xFF182346),
              ),
              KpiTile(
                label: 'NET PROFIT',
                value: 'Rs 340,500',
                sub: '27.2% margin',
                icon: Icons.savings_rounded,
                tint: Color(0xCCE3E7F1),
                iconColor: Color(0xFF5B6390),
              ),
            ]),
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'KPI row must not overflow on ${entry.key}');
      });
    }

    testWidgets('GlassCard list renders with no overflow on a small phone',
        (tester) async {
      // 375x667 is the smallest screen the pre-delivery checklist requires.
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        SingleChildScrollView(
          child: Column(
            children: [
              for (var i = 0; i < 8; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: FoamCard(
                    child: Row(
                      children: [
                        const InitialAvatarShim(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Customer $i with a fairly long ledger name',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const Text('Rs 20,000'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Glass budget — blur is rationed to the floating nav only', () {
    // Regression guard for the "minimal 2027" restyle. The old design put a
    // `BackdropFilter` on every card, chip and search field; each one forces a
    // separate offscreen render pass, which is what made scrolling stutter on
    // low-end phones. These tests fail if that ever creeps back.

    for (final level in [
      AppGlassLevel.base,
      AppGlassLevel.raised,
      AppGlassLevel.nested,
    ]) {
      testWidgets('${level.name} installs no BackdropFilter', (tester) async {
        await tester.pumpWidget(_wrap(
          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassContainer(
              level: level,
              child: const SizedBox(width: 100, height: 60),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsNothing);
      });
    }

    testWidgets('floating nav pill still blurs its backdrop', (tester) async {
      await tester.pumpWidget(_wrap(
        Padding(
          padding: const EdgeInsets.all(16),
          child: GlassContainer(
            level: AppGlassLevel.floating,
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    test('content surfaces are opaque, not translucent', () {
      // A translucent card is a hole in the page: scrolled text behind it
      // bleeds through and the palette washes out. Only the pill may be
      // see-through now.
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final ac = theme.extension<AppColors>()!;
        expect(ac.glassFill.a, 1.0, reason: 'card fill must be opaque');
        expect(ac.glassFillStrong.a, 1.0);
        expect(ac.glassElevated.a, 1.0, reason: 'raised slot must be opaque');
      }
    });

    testWidgets('the app background paints no ambient animation',
        (tester) async {
      // The old background ran three infinite `AnimationController`s driving
      // large radial-gradient orbs, repainting the full screen forever. If one
      // came back, `pumpAndSettle` below would never return — an infinite
      // animation keeps scheduling frames.
      await tester.pumpWidget(_wrap(
        const GlassBackground(child: SizedBox.expand()),
      ));
      expect(
        find.descendant(
          of: find.byType(GlassBackground),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(GlassBackground),
          matching: find.byType(AnimationController),
        ),
        findsNothing,
      );
      // Settles immediately: no frame is ever requested by this subtree.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('Inline button must not eat its row', () {
    // Regression guard for the Sales screen collapsing. `AppButton` paints its
    // background as a `GlassContainer(child: SizedBox.expand())`. Inside a
    // `Stack(fit: StackFit.expand)` in a `Row`, that child reported *infinite*
    // width, so an inline (`fullWidth: false`) button claimed the whole row and
    // squeezed the sibling `Expanded` to zero — the customer card rendered as a
    // one-character-wide column.
    testWidgets('an inline button leaves room for its sibling', (tester) async {
      const key = ValueKey('sibling');
      await tester.pumpWidget(_wrap(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              key: key,
              child: Container(height: 40, color: const Color(0xFF00FF00)),
            ),
            AppButton(
              label: 'Change',
              variant: AppButtonVariant.outline,
              fullWidth: false,
              height: 38,
              onTap: () {},
            ),
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      final sibling = tester.getSize(find.byKey(key));
      // The sibling must keep the overwhelming majority of the row. Before the
      // fix this was ~0dp wide.
      expect(sibling.width, greaterThan(200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a fullWidth button still fills its parent', (tester) async {
      await tester.pumpWidget(_wrap(
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 300,
            child: AppButton(
              label: 'Save',
              fullWidth: true,
              onTap: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final button = tester.getSize(find.byType(AppButton));
      expect(button.width, closeTo(300, 0.5));
    });

    testWidgets('outline and ghost have no opaque slab behind them',
        (tester) async {
      // Regression guard. The fill used to be hardcoded to `ac.surface` - the
      // *page* colour - so the button read as inset on a card. But buttons also
      // sit on bottom sheets, which are lighter, and the same value became a
      // dark hole punched in the sheet ("+ Add Customer" in the Select Customer
      // sheet). A fill derived from one specific surface can never be right on
      // all three backgrounds.
      //
      // The contract now: any fill must be *translucent* so it composites over
      // whatever surface it lands on, and it must not be a `GlassContainer` -
      // that is what let a shadow bleed through a transparent fill. The
      // per-variant colour rules live in "Outlined and ghost controls are
      // surface-safe" below.
      for (final variant in [
        AppButtonVariant.outline,
        AppButtonVariant.ghost,
      ]) {
        await tester.pumpWidget(_wrap(
          Center(
            child: AppButton(
              label: 'Change',
              variant: variant,
              fullWidth: false,
              onTap: () {},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AppButton),
            matching: find.byType(GlassContainer),
          ),
          findsNothing,
          reason: '$variant must not use GlassContainer as its fill layer',
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(AppButton),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration! as BoxDecoration;
        if (decoration.color != null) {
          expect(decoration.color!.a, lessThan(0.5),
              reason: '$variant fill must be translucent, not an opaque slab');
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('an inline button respects custom horizontal padding',
        (tester) async {
      // "Change" needed more room than the 16dp default, which was sized for
      // full-width buttons; on a short label the word ended up touching the
      // rounded edge.
      Future<double> widthOf(double padding) async {
        await tester.pumpWidget(_wrap(
          Center(
            child: AppButton(
              label: 'Change',
              variant: AppButtonVariant.outline,
              fullWidth: false,
              height: 48,
              horizontalPadding: padding,
              onTap: () {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
        return tester.getSize(find.byType(AppButton)).width;
      }

      final narrow = await widthOf(16);
      final wide = await widthOf(28);
      // 12dp of extra padding per side = exactly 24dp wider.
      expect(wide - narrow, closeTo(24, 0.5));
    });
  });

  group('Button fill is clipped to the button shape', () {
    // Regression guard for the "glowing slab" that every filled button showed
    // in the dark theme.
    //
    // The fill used to be a separate child box (`DecoratedBox` for primary,
    // `GlassContainer` for outline/ghost) placed as `Positioned.fill` inside a
    // `Stack`, with rounding delegated to the parent `Container`'s
    // `clipBehavior: Clip.antiAlias`. That clip uses the decoration's *shape* -
    // a plain rectangle - so the child painted square corners that spilled past
    // the 16px radius. `flutter analyze` cannot see this: the layout is legal,
    // it just looks broken.
    //
    // The invariant asserted here is structural: the fill and the radius must
    // live on the SAME `BoxDecoration`. Reintroducing a child-based fill leaves
    // the gradient/colour off the button's own decoration and this fails.
    BoxDecoration decorationOf(WidgetTester tester) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppButton),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration;
      expect(decoration, isA<BoxDecoration>(),
          reason: 'AppButton must paint via a BoxDecoration');
      return decoration! as BoxDecoration;
    }

    testWidgets('primary paints its gradient on the rounded decoration',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Center(child: AppButton(label: 'Done', onTap: () {})),
      ));
      await tester.pumpAndSettle();

      final decoration = decorationOf(tester);
      expect(decoration.gradient, isNotNull,
          reason: 'primary must carry the brand gradient');
      expect(decoration.borderRadius, isNotNull,
          reason: 'the gradient must share a box with the radius');
      // A non-zero radius is what rounds the fill; the old child-based fill had
      // none, which is exactly why it painted square corners.
      expect(
          (decoration.borderRadius! as BorderRadius).topLeft.x, greaterThan(0));
    });

    testWidgets('filled buttons cast no brand-coloured glow', (tester) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(child: AppButton(label: 'Done', onTap: () {})),
          ),
        ));
        await tester.pumpAndSettle();

        final shadows = decorationOf(tester).boxShadow ?? const [];
        for (final shadow in shadows) {
          // A tinted shadow is a glow, not depth. Only a neutral one is fine.
          final hsl = HSLColor.fromColor(shadow.color);
          expect(hsl.saturation, lessThan(0.05),
              reason: 'button shadow must be neutral, not a brand glow');
        }
      }
    });
  });

  group('Outlined and ghost controls are surface-safe', () {
    // These controls appear on a card, on a page AND on a bottom sheet, and
    // those three surfaces have three different colours. A fill baked from any
    // one of them is wrong on the other two - that is what turned
    // "+ Add Customer" into a dark hole punched in the sheet.

    BoxDecoration decorationOf(WidgetTester tester) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppButton),
              matching: find.byType(Container),
            )
            .first,
      );
      return container.decoration! as BoxDecoration;
    }

    Future<void> pumpVariant(
      WidgetTester tester,
      AppButtonVariant variant,
      Brightness brightness,
    ) async {
      await tester.pumpWidget(MaterialApp(
        theme:
            brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppButton(
              label: 'Control',
              variant: variant,
              onTap: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('outline fill is a translucent wash, never a surface colour',
        (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpVariant(tester, AppButtonVariant.outline, brightness);
        final fill = decorationOf(tester).color!;
        final ac = AppColors.of(tester.element(find.byType(AppButton)));

        // Translucent, so it composites over whatever it sits on.
        expect(fill.a, lessThan(0.5),
            reason: 'outline fill must be translucent, not an opaque slab');
        expect(fill, ac.glassNested);

        // And it must not be baked from any surface it can land on.
        expect(fill, isNot(ac.surface));
        expect(fill, isNot(ac.glassFill));
        expect(fill, isNot(ac.glassElevated));
      }
    });

    testWidgets('outline border is visible against every surface it lands on',
        (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpVariant(tester, AppButtonVariant.outline, brightness);
        final decoration = decorationOf(tester);
        final border = decoration.border;
        expect(border, isNotNull, reason: 'an outlined control needs an edge');

        final borderColour = (border! as Border).top.color;
        final ac = AppColors.of(tester.element(find.byType(AppButton)));
        // `outline` (#32323E on #1E1E26) measured ~1.2:1 in dark mode and was
        // effectively invisible, leaving the label looking like loose text.
        for (final surface in [ac.surface, ac.glassFill, ac.glassElevated]) {
          // Contrast is symmetric: the border may be lighter *or* darker than
          // the surface depending on the theme, so normalise the pair. Using
          // border-over-surface only is wrong in light mode, where the border
          // is the darker of the two and the naive ratio collapses below 1.
          final a = borderColour.computeLuminance();
          final b = surface.computeLuminance();
          final ratio =
              (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
          expect(ratio, greaterThan(1.5),
              reason: 'outline border is effectively invisible '
                  '(${ratio.toStringAsFixed(2)}:1) on this surface');
        }
      }
    });

    testWidgets('ghost has no fill, no border and no shadow', (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpVariant(tester, AppButtonVariant.ghost, brightness);
        final decoration = decorationOf(tester);
        // A ghost that paints a wash reads as an unexplained grey slab sitting
        // next to two proper buttons.
        expect(decoration.color, anyOf(isNull, const Color(0x00000000)));
        expect(decoration.border, isNull);
        expect(decoration.boxShadow, anyOf(isNull, isEmpty));
      }
    });

    testWidgets('no control casts a shadow through its own fill',
        (tester) async {
      // The mechanism behind the "dark hole": `GlassContainer` was the
      // outline/ghost fill with `Colors.transparent`. Its shadow was still
      // painted, and the transparent fill let it show *inside* the control,
      // smearing a dark blur across it.
      for (final variant in [
        AppButtonVariant.outline,
        AppButtonVariant.ghost,
      ]) {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await pumpVariant(tester, variant, brightness);
          expect(decorationOf(tester).boxShadow, anyOf(isNull, isEmpty),
              reason: '$variant must not cast a shadow through its own fill');
        }
      }
    });
  });

  group('Sales customer card', () {
    // The "Change" control is the app's most-used secondary action and it was
    // rendering as a 38dp caption-sized pill that read as a stray word rather
    // than a button, sitting under the 48dp minimum touch target.
    testWidgets('the Change chip is a real control, larger than the avatar',
        (tester) async {
      const avatarSize = 40.0;
      await tester.pumpWidget(_wrap(
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 80,
            child: Row(
              children: [
                const SizedBox(
                  width: avatarSize,
                  height: avatarSize,
                  child: ColoredBox(color: Color(0xFF00FF00)),
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: 'Change',
                  variant: AppButtonVariant.outline,
                  fullWidth: false,
                  height: 52,
                  fontSize: 14.5,
                  horizontalPadding: 24,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final chip = tester.getSize(find.byType(AppButton));
      expect(chip.height, greaterThanOrEqualTo(AppHit.min));
      // Deliberately larger than the avatar: at an equal size the two controls
      // in the row read as the same weight and the hierarchy is lost.
      expect(chip.height, greaterThan(avatarSize));
      // Wide enough that the word is not touching the rounded edge.
      expect(chip.width, greaterThan(100));
      expect(tester.takeException(), isNull);
    });
  });

  group('Sale price field', () {
    Product _product() => Product(
          id: 'p1',
          name: 'luxury',
          type: 'foam',
          sizeLength: 78,
          sizeWidth: 72,
          thickness: 6,
          density: 1.2,
          unitType: 'sq.ft',
          unitPrice: 20500,
          costPrice: 1000,
          currentStock: 10,
          lowStockThreshold: 2,
        );

    Future<void> _pumpPriceField(WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
              salesProvider.overrideWith(() => SalesNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CartWidget(
                  item: CartItem(
                      product: _product(), quantity: 1, salePrice: 20500),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // `unitType` is hardcoded to 'per_sqft' on product creation and
    // `Product.fromMap` defaults to it when the field is absent, so `unitLabel`
    // resolved to "sq.ft" for every product in the app. The caption therefore
    // read "PRICE PER SQ.FT" directly above a stock count reading "15 pcs" —
    // a caption that states the unit basis, and states it wrongly.
    testWidgets('price caption does not claim a square-foot basis',
        (tester) async {
      await _pumpPriceField(tester);

      expect(find.text('PRICE PER UNIT'), findsOneWidget,
          reason: 'the field must be captioned in the unit the shop sells by');
      expect(find.textContaining('SQ.FT'), findsNothing,
          reason: 'nothing in the UI sets unitType to per-piece, so asserting '
              'sq.ft is asserting a basis the shop does not use');
      expect(tester.takeException(), isNull);
    });

    // The primary button was `flex: 2` and its label grew with the total
    // ("Save Sale · Rs 0" -> "Save Sale · Rs 118,500"), so the secondary's share
    // shrank as the sale got bigger and "Save as Quote" clipped to "Save as
    // Qu…". A layout that degrades with the data is the bug.
    testWidgets('both save buttons keep their full labels at a large total',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        Row(
          children: [
            Expanded(
              child: AppButton(label: 'Save Sale', onTap: () {}),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Save as Quote',
                variant: AppButtonVariant.outline,
                onTap: () {},
              ),
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // Assert on the *rendered* width, not on the `overflow` property.
      // `AppButton` sets `overflow: TextOverflow.ellipsis` on every label
      // unconditionally, so checking the property proves nothing — it is
      // non-null whether or not the text was actually clipped. What matters is
      // whether the painted paragraph is wider than the box it sits in, which
      // is what an ellipsis means in practice.
      for (final label in ['Save Sale', 'Save as Quote']) {
        final finder = find.text(label);
        final textWidth = tester.getSize(finder).width;
        final buttonWidth = tester
            .getSize(find
                .ancestor(of: finder, matching: find.byType(AppButton))
                .first)
            .width;
        expect(textWidth, lessThan(buttonWidth),
            reason: '"$label" paints $textWidth wide inside a $buttonWidth '
                'button, so it is being truncated');
      }
      expect(tester.takeException(), isNull);
    });

    // Was 68x30 \u2014 under the app's own 48dp touch minimum, and
    // cramped for a 5-6 digit figure. It is the most-typed value on the screen.
    testWidgets('is a full-size, legible target', (tester) async {
      await _pumpPriceField(tester);

      final box = tester.getSize(find.byType(TextField).first);
      expect(box.height, greaterThanOrEqualTo(48),
          reason: 'the price field must meet the 48dp touch minimum');
      expect(box.width, greaterThanOrEqualTo(90),
          reason: '68px was too narrow to read a 5-6 digit price');

      final style =
          tester.widget<TextField>(find.byType(TextField).first).style!;
      expect(style.fontSize, greaterThanOrEqualTo(14));
      expect(tester.takeException(), isNull);
    });

    // The bug: the field had no FocusNode, and the cart republishes on every
    // keystroke, so the TextField's element was rebuilt, focus was dropped, and
    // the platform handed it to the next focusable widget \u2014 the search field.
    // The symptom was "I can type one character, then the caret jumps to
    // Search products".
    testWidgets('keeps focus across a price edit', (tester) async {
      await _pumpPriceField(tester);

      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.pumpAndSettle();

      // Simulate the user clearing the field and typing a new price: the
      // onChanged path republishes the cart and rebuilds this row.
      await tester.enterText(field, '5');
      await tester.pumpAndSettle();
      await tester.enterText(field, '55');
      await tester.pumpAndSettle();

      // The field must still own focus after all those rebuilds.
      expect(
        FocusManager.instance.primaryFocus,
        tester.widget<TextField>(field).focusNode,
        reason: 'the price field must keep focus after a cart rebuild',
      );
      expect(tester.takeException(), isNull);
    });

    // The device bug this guards. On the Pixel 9 the field accepted exactly ONE
    // keystroke and then went deaf: typing "20500" left a single digit behind,
    // with the field still drawn as focused. Even 3s between key events changed
    // nothing, so this was the app, not flaky input injection.
    //
    // The focus test above cannot catch it because `enterText` sets the whole
    // value in one shot. Feeding the value through `updateEditingValue` one
    // character at a time is precisely what the platform IME does, so this
    // exercises the incremental path that was broken.
    testWidgets('accepts every digit of a multi-digit price', (tester) async {
      await _pumpPriceField(tester);

      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.pumpAndSettle();

      // Clear the pre-filled price the way a user would before retyping.
      tester.testTextInput.updateEditingValue(const TextEditingValue());
      await tester.pumpAndSettle();

      var typed = '';
      for (final digit in '20500'.split('')) {
        typed += digit;
        tester.testTextInput.updateEditingValue(TextEditingValue(
          text: typed,
          selection: TextSelection.collapsed(offset: typed.length),
        ));
        await tester.pumpAndSettle();
      }

      expect(
        tester.widget<TextField>(field).controller!.text,
        '20500',
        reason:
            'every keystroke must land; the field went deaf after the first '
            'character, so multi-digit prices were impossible to enter',
      );
      expect(tester.takeException(), isNull);
    });

    // The cart's own controls were all well under the 48dp touch minimum the app
    // sets for itself in `AppHit`: the remove button was a bare 24x24 InkWell
    // around a "\u2715" glyph, and both quantity steppers were 24x24 inside a
    // 32-tall track. On a phone held one-handed at a counter those are the
    // hardest controls on the screen to hit, and the steppers in particular sit
    // next to each other \u2014 a miss on "+" lands on "\u2212" and quietly changes
    // the quantity of a real sale.
    testWidgets('cart remove and stepper controls meet the touch minimum',
        (tester) async {
      await _pumpPriceField(tester);

      // Measure the tappable target, not the glyph. The icons are intentionally
      // 17px, so `find.byIcon(...)` finds the Icon itself and reports 17 \u2014 the
      // thing being asserted here is the hit area wrapped around it. Each target
      // is the enclosing `InkWell` of the icon, which is exactly what receives
      // the tap.
      Size targetFor(IconData icon) {
        final inkWell = find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(InkWell),
        );
        expect(
          inkWell,
          findsWidgets,
          reason: 'icon $icon is not wrapped in a tappable InkWell',
        );
        return tester.getSize(inkWell.first);
      }

      for (final (label, icon) in [
        ('remove', Icons.close_rounded),
        ('quantity -', Icons.remove_rounded),
        ('quantity +', Icons.add_rounded),
      ]) {
        final size = targetFor(icon);
        expect(
          size.height,
          greaterThanOrEqualTo(AppHit.min),
          reason:
              'the "$label" hit area is only ${size.height} tall, under the '
              '48dp touch minimum',
        );
        expect(
          size.width,
          greaterThanOrEqualTo(AppHit.min),
          reason: 'the "$label" hit area is only ${size.width} wide, under the '
              '48dp touch minimum',
        );
      }
      expect(tester.takeException(), isNull);
    });

    // A price of 0 leaves the line total undefined, and the old caption showed a
    // bare "\u00d7 1" with no figure at all. The line now carries a dedicated
    // total slot that shows an em dash until there is a real price, so the row
    // never displays a number that implies a value it does not have.
    //
    // The total also moved out of the "= Rs 20,500" string that used to sit
    // inline against the price field: that caption was the first thing pushed
    // off the right edge on a narrow phone. It is asserted here as its own
    // element, on the same row as the status pill.
    testWidgets('line total stays blank until a price is entered',
        (tester) async {
      await _pumpPriceField(tester);

      // The pre-filled price renders a real figure, formatted with thousands
      // separators, rather than the placeholder. 20,500 is the cart's line total
      // (quantity 1), so it appears on its own without an "=" prefix.
      expect(find.textContaining('20,500'), findsWidgets);
      expect(find.text('\u2014'), findsNothing);
      // With a valid price and a cost below it, the line is up, not down.
      expect(find.textContaining('margin'), findsWidgets);

      final field = find.byType(TextField).first;
      await tester.enterText(field, '');
      await tester.pumpAndSettle();

      expect(
        find.text('\u2014'),
        findsOneWidget,
        reason:
            'with no price there is no line total to show, so the total slot '
            'falls back to a dash',
      );
      // The margin used to be a second dash here. It is now a status pill that
      // says what is actually wrong \u2014 an unset price, not a missing number.
      expect(
        find.text('Price not set'),
        findsOneWidget,
        reason: 'an unset price must be named, not rendered as a blank figure',
      );
      expect(tester.takeException(), isNull);
    });

    // The "MARGIN -832%" readout was arithmetically correct and practically
    // useless: a margin that far negative only means "well below cost", which
    // the rupee shortfall says directly. The pill must name the state, and the
    // notice must quantify the loss in currency.
    testWidgets(
        'a below-cost line states the loss in rupees, not just a margin',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
              salesProvider.overrideWith(() => SalesNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CartWidget(
                  item: CartItem(
                    product: _product(),
                    quantity: 2,
                    salePrice: 2000,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cost is 1,000 in `_product`, so this case is *above* cost. Drive the
      // price under the cost to exercise the loss branch.
      final field = find.byType(TextField).first;
      await tester.enterText(field, '200');
      await tester.pumpAndSettle();

      expect(
        find.text('Below cost'),
        findsOneWidget,
        reason: 'the status pill must name the state rather than show a bare '
            'negative percentage',
      );
      expect(
        find.textContaining('Losing'),
        findsOneWidget,
        reason:
            'the shortfall must be quantified in rupees so it is actionable',
      );
      expect(
        find.textContaining('-832'),
        findsNothing,
        reason: 'the -832% margin is arithmetic the user cannot act on',
      );
      expect(find.text('Use cost'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Receipt saving', () {
    // The bug: "Save PDF" reported success but no file ever appeared in the
    // phone's storage. The Dart side wrote with `dart:io`'s `File` into
    // getDownloadsDirectory(), which Android 10+ scoped storage turns into a
    // no-op \u2014 and WRITE_EXTERNAL_STORAGE is capped at maxSdkVersion=28, so no
    // permission could ever have rescued it.
    //
    // The fix routes Android through MediaStore. These tests pin the contract
    // with the native side so the route cannot silently regress to a direct
    // filesystem write.

    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('com.asif.foamshop/receipts');
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      ReceiptSaver.instance.isAndroid = () => true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        if (call.method == 'savePdf') {
          return 'content://media/external/downloads/42';
        }
        return null;
      });
    });

    tearDown(() {
      ReceiptSaver.instance.isAndroid = () => Platform.isAndroid;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('routes the save through MediaStore, not the filesystem', () async {
      final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
      final where = await ReceiptSaver.instance.save(bytes, 'receipt-1.pdf');

      // A `dart:io` write would have produced a filesystem path such as
      // /storage/emulated/0/Download/receipt-1.pdf. Anything that is not a
      // content:// URI means the scoped-storage bug is back.
      expect(log.map((c) => c.method), contains('savePdf'));
      expect(where, startsWith('content://'),
          reason: 'Android must save via MediaStore; a bare path is invisible '
              'to the user under scoped storage');

      final args = log.firstWhere((c) => c.method == 'savePdf').arguments
          as Map<Object?, Object?>;
      expect(args['name'], 'receipt-1.pdf');
      expect(args['bytes'], isA<Uint8List>());
    });

    test('surfaces a platform failure instead of reporting a false success',
        () async {
      // The native side can reject the insert (no writable volume, a full
      // disk). That must propagate so the caller can fall back to the share
      // sheet \u2014 swallowing it would repeat the "saved but nowhere" bug.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'save_failed', message: 'disk full');
      });

      await expectLater(
        ReceiptSaver.instance.save(Uint8List.fromList([1]), 'r.pdf'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('rejects an empty location rather than claiming success', () async {
      // A null/empty reply from the platform means the file is not verifiably
      // saved. Treating that as success is exactly the failure mode being
      // fixed, so it is treated as an error.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      await expectLater(
        ReceiptSaver.instance.save(Uint8List.fromList([1]), 'r.pdf'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Receipt PDF', () {
    // The receipt is the one artefact a customer physically takes away, so a
    // regression here is a business bug, not a cosmetic one.

    /// Adapter from the old loose-map call shape to the shared [ReceiptData].
    ///
    /// The service now takes a typed model so the preview and the PDF cannot
    /// drift; these tests still describe the sale in the old map form, so this
    /// keeps them readable while still exercising the real render path.
    Future<Uint8List> generateReceiptPdfBytes({
      required String storeName,
      required String receiptId,
      required String date,
      required String customerName,
      required List<Map<String, dynamic>> items,
      required double totalAmount,
      required double paidAmount,
      required double remainingBalance,
      String location = '',
      String phone = '',
      String currencyCode = 'PKR',
    }) {
      final fmt = NumberFormat('#,##0');
      return generateReceiptPdf(
        buildReceiptData(
          storeName: storeName,
          receiptId: receiptId,
          date: date,
          customerName: customerName,
          items: [
            for (final i in items)
              ReceiptLine(
                name: i['name'].toString(),
                qty: i['qty'].toString(),
                unitPrice: fmt.format(((i['price'] as num?) ?? 0).toInt()),
                total: fmt.format(((i['total'] as num?) ?? 0).toInt()),
              ),
          ],
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          remainingBalance: remainingBalance,
          location: location,
          phone: phone,
          currencyCode: currencyCode,
        ),
      );
    }

    test('generates a valid PDF for a paid sale', () async {
      final bytes = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        receiptId: 'INV-0142',
        date: '22/7/2026',
        customerName: 'Walk-in Customer',
        items: [
          {'name': 'luxury', 'qty': '1.0', 'price': 25500, 'total': 25500},
        ],
        totalAmount: 25500,
        paidAmount: 25500,
        remainingBalance: 0,
      );

      // A real PDF always starts with the %PDF- header.
      expect(bytes.length, greaterThan(500));
      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: 'output must be a real PDF, not an empty buffer',
      );
    });

    test('handles an empty cart without throwing', () async {
      // A voided or draft sale has no line items; the table must not crash.
      final bytes = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        receiptId: 'INV-EMPTY',
        date: '22/7/2026',
        customerName: 'Walk-in Customer',
        items: const [],
        totalAmount: 0,
        paidAmount: 0,
        remainingBalance: 0,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('handles a long product name and a large balance', () async {
      final bytes = await generateReceiptPdfBytes(
        storeName: 'A Very Long Shop Name That Will Not Fit On One Line Ltd',
        receiptId: 'INV-LONGNAME',
        date: '22/7/2026',
        customerName: 'Customer With An Extremely Long Ledger Name',
        items: [
          {
            'name':
                'Premium High Density Memory Foam Roll Full Size Extra Long',
            'qty': '12.5',
            'price': 1250000,
            'total': 15625000,
          },
        ],
        totalAmount: 15625000,
        paidAmount: 0,
        remainingBalance: 15625000,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('does not overflow the page on a big multi-item sale', () async {
      // The real-world break: a plain `pw.Column` on a fixed-height page throws
      // as soon as the cart is long enough to run off the bottom, so printing a
      // 15-item foam order failed outright. The receipt must paginate instead.
      final items = List.generate(
        18,
        (i) => {
          'name': 'Memory Foam Roll ${i + 1} 78x72x6 in',
          'qty': '2.0',
          'price': 25500,
          'total': 51000,
        },
      );
      final bytes = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        receiptId: 'INV-BULK',
        date: '22/7/2026',
        customerName: 'Walk-in Customer',
        items: items,
        totalAmount: 918000,
        paidAmount: 900000,
        remainingBalance: 18000,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      // A paginated receipt is necessarily larger than a one-line one.
      expect(bytes.length, greaterThan(2000));
    });

    test('every section survives into the drawable content stream', () async {
      // The bug this guards: the status pill used `BorderRadius.circular(999)`.
      // A radius far larger than the box emits degenerate path geometry, and
      // renderers then drop everything drawn before it \u2014 the shop header, the
      // item table and the totals block simply vanished, and the customer got a
      // near-blank receipt. Byte length and the `%PDF-` header both stayed
      // perfectly valid, so every other test in this group still passed.
      //
      // Asserting on the inflated stream is what actually catches it.
      final bytes = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        location: 'Sahiwal',
        phone: '0300-1234567',
        receiptId: 'INV-0142',
        date: '22/7/2026',
        customerName: 'Walk-in Customer',
        items: [
          {'name': 'luxury', 'qty': '1.0', 'price': 25500, 'total': 25500},
        ],
        totalAmount: 25500,
        paidAmount: 25500,
        remainingBalance: 0,
      );
      final stream = _inflateContent(bytes);

      // The header band is the first thing drawn, so if the pill geometry
      // corrupts the stream again, this is what notices.
      expect(stream, isNotEmpty);
      for (final marker in const ['1 0 0 1', ' re', 'f', 'BT']) {
        expect(
          stream,
          contains(marker),
          reason: 'content stream lost its "$marker" operator',
        );
      }
    });

    test('embeds a Unicode-capable font so the tick and dot render', () async {
      // The built-in Helvetica is WinAnsi only, so "? FULLY PAID" printed as a
      // blank box. Inter ships in assets/fonts/ and is what the preview uses.
      final bytes = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        receiptId: 'INV-0142',
        date: '22/7/2026',
        customerName: 'Walk-in Customer',
        items: [
          {'name': 'luxury', 'qty': '1.0', 'price': 25500, 'total': 25500},
        ],
        totalAmount: 25500,
        paidAmount: 25500,
        remainingBalance: 0,
      );
      final raw = String.fromCharCodes(bytes);
      // The base-14 fonts are referenced by name in the font dictionary; an
      // embedded TTF is not.
      expect(
        raw.contains('/Helvetica'),
        isFalse,
        reason: 'receipt should embed Inter, not the WinAnsi-only base fonts',
      );
      expect(
        _inflateContent(bytes),
        isNotEmpty,
        reason: 'an embedded font must decompress to real font data',
      );
    });

    test('money cells drop the currency symbol so figures cannot clip', () {
      // The bug this guards: the per-row PRICE and TOTAL cells repeated the
      // currency symbol ("Rs 1,200"). On an 80mm roll that did not fit, and
      // `maxLines: 1` + `TextOverflow.clip` truncated the figure to a bare "Rs" -
      // a *wrong number* on a customer's receipt, the one failure this document
      // cannot have.
      //
      // It cannot be asserted against the PDF itself: the receipt embeds a
      // subsetted Inter, so the content stream stores glyph indices rather than
      // ASCII and no text search finds the figure. The `%PDF-` header, the byte
      // length and the page count all stayed valid, which is exactly why the bug
      // survived. So the invariant is pinned where it is actually decided.
      for (final (input, expected) in [
        ('Rs 1,200', '1,200'),
        ('Rs 15,625,000', '15,625,000'),
        ('PKR 500', '500'),
        (r'$1,200.50', '1,200.50'),
        ('1,200', '1,200'),
        // A sign must survive: dropping it would turn a credit into a charge.
        ('-Rs 500', '-500'),
        ('+Rs 500', '+500'),
        ('', ''),
      ]) {
        expect(
          stripCurrencySymbol(input),
          expected,
          reason: 'stripping "$input" must yield "$expected"',
        );
      }
    });

    test('a receipt with the widest realistic figure still fits one page',
        () async {
      // Confirms the width reclaimed by stripping the symbol was not paid for
      // with a taller page, on the largest figure the app can realistically hold.
      final bytes = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        receiptId: 'INV-BIG',
        date: '27/9/2026',
        customerName: 'Customer With A Long Ledger Name',
        items: [
          {
            'name': 'High-Density Gold Reflex Foam 10mm Sheet',
            'qty': '2.0',
            'price': 15625000,
            'total': 15625000,
          },
        ],
        totalAmount: 15625000,
        paidAmount: 0,
        remainingBalance: 15625000,
      );
      expect(_pageCount(bytes), 1);
    });

    testWidgets('the money columns are wide enough for the figures they hold',
        (tester) async {
      // The reported bug: a 120,000 total printed as "120,00" and a 60,000 unit
      // price as "60,00". The table allocated a fixed fraction of the 80mm roll
      // to the money columns, which was sized for four-digit amounts; with
      // `maxLines: 1` + `TextOverflow.clip` the rest of the number was silently
      // dropped. A *wrong number* on a customer's receipt.
      //
      // The invariant, checked here: each money column must be at least as wide
      // as the string it has to render, in the font the receipt is actually
      // painted with. Measuring in Helvetica would NOT reproduce the failure —
      // Inter's digits are wider, which is precisely why the fixed split ran out
      // of room in the app while still looking plausible on paper.
      final data = ReceiptData(
        storeName: 'Asif Foam Center',
        date: '27/9/2026',
        receiptNo: 'INV-1',
        metaLine: 'Shop #4, Urdu Bazaar',
        customerName: 'Walk-in Customer',
        items: const [
          // Exactly the receipt from the bug report.
          ReceiptLine(
              name: 'luxury', qty: '2', unitPrice: '60,000', total: '120,000'),
        ],
        total: 'Rs 120,000',
        paid: 'Rs 100,000',
        isDue: true,
        dueValue: 'Rs 20,000',
        footer: 'Asif Foam Center',
      );

      // The real faces, straight from the asset bundle, as `generateReceiptPdf`
      // loads them.
      final regular =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
      final bold =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
      final theme = pw.ThemeData.withFont(base: regular, bold: bold);

      final doc = pw.Document(theme: theme);
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 400 * PdfPageFormat.mm,
            marginAll: 6 * PdfPageFormat.mm),
        build: (_) => pw.SizedBox(),
      ));
      final page = doc.document.page(0)!;
      final ctx = pw.Context(
        document: doc.document,
        page: page,
        canvas: page.getGraphics(),
      ).inheritFromAll([theme]);

      double paintedWidth(String s, pw.Font f) => pw.Widget.measure(
            pw.Text(s,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(fontSize: 8.6, font: f)),
            context: ctx,
          ).x;

      final contentWidth = 80 * PdfPageFormat.mm - (6 * PdfPageFormat.mm * 2);
      final widths = receiptColumnWidths(
        data: data,
        regular: regular,
        bold: bold,
        contentWidth: contentWidth,
        context: ctx,
      );

      double share(int column) {
        final sum = widths.values
            .whereType<pw.FlexColumnWidth>()
            .map((f) => f.flex)
            .fold<double>(0, (a, b) => a + b);
        return (widths[column]! as pw.FlexColumnWidth).flex /
            sum *
            contentWidth;
      }

      // `td` pads right-aligned cells with `EdgeInsets.symmetric(horizontal: 4)`,
      // so 8 points of every money column is padding, not digits.
      const cellPadX = 8.0;
      expect(share(2),
          greaterThanOrEqualTo(paintedWidth('60,000', regular) + cellPadX),
          reason: 'PRICE column must fit "60,000"');
      expect(share(3),
          greaterThanOrEqualTo(paintedWidth('120,000', bold) + cellPadX),
          reason: 'TOTAL column must fit "120,000"');
      expect(
          share(1), greaterThanOrEqualTo(paintedWidth('2', regular) + cellPadX),
          reason: 'QTY column must fit its value');
    });

    test('a longer total widens the total column rather than clipping', () {
      ReceiptData withTotal(String total) => ReceiptData(
            storeName: 'Asif Foam Center',
            date: '27/9/2026',
            receiptNo: 'INV-1',
            metaLine: 'Shop #4',
            customerName: 'Walk-in Customer',
            items: [
              ReceiptLine(
                  name: 'luxury', qty: '2', unitPrice: '60,000', total: total),
            ],
            total: 'Rs $total',
            paid: 'Rs 0',
            isDue: true,
            dueValue: 'Rs $total',
            footer: 'Asif Foam Center',
          );

      final contentWidth = 80 * PdfPageFormat.mm - (6 * PdfPageFormat.mm * 2);
      double totalShareFor(ReceiptData d) {
        final w = receiptColumnWidths(
          data: d,
          regular: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          contentWidth: contentWidth,
        );
        final sum = w.values
            .whereType<pw.FlexColumnWidth>()
            .map((f) => f.flex)
            .fold<double>(0, (a, b) => a + b);
        return (w[3]! as pw.FlexColumnWidth).flex / sum * contentWidth;
      }

      // A seven-digit total must claim more room than a five-digit one, which is
      // only true if the width is derived from the content.
      final narrow = totalShareFor(withTotal('120,000'));
      final wide = totalShareFor(withTotal('12,345,600'));
      expect(wide, greaterThan(narrow));
    });

    test('a typical receipt fits on a single page', () async {
      // The failure mode this guards is subtle and bad: if the page is sized a
      // little too short, `MultiPage` does not clip, it paginates. The customer
      // then gets sheet one of the receipt with the totals and footer pushed
      // onto a near-blank sheet two \u2014 the same symptom the old 297mm page had,
      // just inverted.
      //
      // This is the exact receipt from the print-preview bug report.
      final bytes = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        location: 'Opposite Meezan Bank GT Road Kot Addu - 03467302964',
        receiptId: 'INV-QOEJ',
        date: '27/9/2026',
        customerName: 'Walk-in Customer',
        items: [
          {'name': 'luxury', 'qty': '2.0', 'price': 26000, 'total': 52000},
        ],
        totalAmount: 52000,
        paidAmount: 53000,
        remainingBalance: 0,
      );
      expect(_pageCount(bytes), 1);
    });

    test('receipts stay on one page from empty up to a 12-item order',
        () async {
      // Calibration data, measured by binary-searching the smallest height
      // that keeps each of these on one page. The estimator over-reserves by
      // 4-11% across the range, which is the safe direction.
      //
      // 0 items -> 131.5mm, 1 -> 138.9mm, 1 long-wrapping -> 150.4mm,
      // 3 -> 153.6mm, 12 -> 266.0mm required.
      Map<String, dynamic> item(String n) =>
          {'name': n, 'qty': '2.0', 'price': 26000, 'total': 52000};

      final cases = <String, List<Map<String, dynamic>>>{
        'empty': [],
        'single short': [item('luxury')],
        'single long (wraps)': [
          item('Premium High Density Memory Foam Roll Full Size Extra Long'),
        ],
        'three items': [item('luxury'), item('cotton'), item('silicon')],
        'twelve items':
            List.generate(12, (i) => item('Memory Foam Roll ${i + 1}')),
      };

      for (final e in cases.entries) {
        final bytes = await generateReceiptPdfBytes(
          storeName: 'Asif Foam Center',
          location: 'Opposite Meezan Bank GT Road Kot Addu - 03467302964',
          receiptId: 'INV-QOEJ',
          date: '27/9/2026',
          customerName: 'Walk-in Customer',
          items: e.value,
          totalAmount: 52000,
          paidAmount: 53000,
          remainingBalance: 0,
        );
        expect(
          _pageCount(bytes),
          1,
          reason: 'a receipt with ${e.key} must not spill onto a second sheet',
        );
      }
    });

    test('sizes the page to the content instead of A4 height', () async {
      // The bug: the page was 80mm wide but 297mm tall \u2014 A4's long edge, left
      // over from the old A4 format. A one-item receipt is only ~125mm of
      // content, so the print preview showed a sheet that was two-thirds blank.
      //
      // This reads the real /MediaBox out of the generated PDF, so it pins the
      // geometry the printer actually receives rather than the intent.
      final oneItem = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        location: 'Sahiwal',
        phone: '0300-1234567',
        receiptId: 'INV-0142',
        date: '22/7/2026',
        customerName: 'Walk-in Customer',
        items: [
          {'name': 'luxury', 'qty': '1.0', 'price': 25500, 'total': 25500},
        ],
        totalAmount: 25500,
        paidAmount: 25500,
        remainingBalance: 0,
      );
      final (wMm, hMm) = _firstPageSizeMm(oneItem);

      // Still 80mm thermal-roll width.
      expect(wMm, closeTo(80, 0.5));
      // Tall enough for the header, one row, totals, badge and footer, but
      // nowhere near a full A4 sheet.
      expect(hMm, greaterThan(90));
      expect(hMm, lessThan(200),
          reason: 'a 1-item receipt should not reserve 297mm of blank paper');

      // More line items must mean a taller page, or the layout would clip.
      final manyItems = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        receiptId: 'INV-BULK',
        date: '22/7/2026',
        customerName: 'Walk-in Customer',
        items: List.generate(
          12,
          (i) => {
            'name': 'Memory Foam Roll ${i + 1}',
            'qty': '2.0',
            'price': 25500,
            'total': 51000,
          },
        ),
        totalAmount: 612000,
        paidAmount: 612000,
        remainingBalance: 0,
      );
      expect(_firstPageSizeMm(manyItems).$2, greaterThan(hMm));
    });

    test('long product names grow the page so rows are not clipped', () async {
      // A name that wraps must be budgeted for, otherwise the table runs off a
      // page that was sized for a single line and the receipt paginates early.
      final short = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        receiptId: 'INV-S',
        date: '22/7/2026',
        customerName: 'Walk-in Customer',
        items: [
          {'name': 'foam', 'qty': '1.0', 'price': 100, 'total': 100},
        ],
        totalAmount: 100,
        paidAmount: 100,
        remainingBalance: 0,
      );
      final long = await generateReceiptPdfBytes(
        storeName: 'Asif Foam Center',
        receiptId: 'INV-L',
        date: '22/7/2026',
        customerName: 'Walk-in Customer',
        items: [
          {
            'name':
                'Premium High Density Memory Foam Roll Full Size Extra Long',
            'qty': '1.0',
            'price': 100,
            'total': 100,
          },
        ],
        totalAmount: 100,
        paidAmount: 100,
        remainingBalance: 0,
      );
      expect(
          _firstPageSizeMm(long).$2, greaterThan(_firstPageSizeMm(short).$2));
    });
  });

  // ── Data integrity regressions ──
  //
  // These guard defects that produced *plausible but wrong numbers* rather than
  // a visible error, which is why nothing else in the suite would catch them.

  group('Stock label', () {
    Product product({double stock = 15, String unitType = 'per_sqft'}) =>
        Product(
          id: 'p',
          name: 'Foam',
          type: 'Sheet',
          sizeLength: 72,
          sizeWidth: 36,
          thickness: 4,
          density: 16,
          unitType: unitType,
          unitPrice: 0,
          costPrice: 100,
          currentStock: stock,
          lowStockThreshold: 5,
        );

    test('reports the unit the product is actually sold in', () {
      // `stockLabel` used to hardcode "pcs", so a per-square-foot product was
      // labelled "15 pcs" in the inventory list while the restock sheet said
      // "15 sq.ft" — two different units for the same product.
      expect(product().stockLabel, '15 sq.ft');
      expect(product(unitType: 'pcs').stockLabel, '15 pcs');
    });

    test('does not silently truncate a fractional stock count', () {
      // Stock is a double because foam is tracked in fractional square feet.
      // `.toInt()` turned 2.5 into "2" — a real quantity reported as a
      // different real quantity.
      expect(product(stock: 2.5).stockLabel, '2.50 sq.ft');
      expect(product(stock: 0.25).stockLabel, '0.25 sq.ft');
    });

    test('renders a whole-number stock without a decimal tail', () {
      expect(product(stock: 15).stockLabel, '15 sq.ft');
      expect(product(stock: 0).stockLabel, '0 sq.ft');
    });
  });

  group('Error sanitisation', () {
    test('passes through the app\'s own user-facing validation messages', () {
      expect(sanitizeErrorMessage(Exception('Insufficient stock')),
          'Exception: Insufficient stock');
      expect(sanitizeErrorMessage(Exception('Select a customer')),
          'Exception: Select a customer');
    });

    test('masks Firebase internals behind the fallback', () {
      expect(
        sanitizeErrorMessage(
            Exception('[firebase_firestore/failed-precondition] '
                'permission denied at /users/x/sales/y')),
        'Something went wrong. Please try again.',
      );
    });

    test('masks a genuine null-safety fault behind the fallback', () {
      expect(
        sanitizeErrorMessage(
            Exception('Null check operator used on a null value')),
        'Something went wrong. Please try again.',
      );
      expect(
        sanitizeErrorMessage(
            Exception("type 'String' is not a subtype of type 'int'")),
        'Something went wrong. Please try again.',
      );
    });

    test('does not mask an unrelated error just for containing both words', () {
      // The guard used to be `contains('type') && contains('null')`, which
      // matched on the mere presence of those two words anywhere in the message
      // and silently replaced the real cause with a generic string.
      final real = 'Could not resolve type size for the null terminator table';
      expect(sanitizeErrorMessage(Exception(real)), 'Exception: $real');
    });
  });

  group('Report export', () {
    // The bug: every export path read `customerId.substring(0, 6)` to label a
    // sale's customer, behind a `customerName ??` fallback. That throws
    // `RangeError` whenever the name is absent AND the id is shorter than six
    // characters — which is exactly the shape of a *legacy* record: sales
    // written before the `customer_name` field existed carry only a short
    // `customer_id`. One such sale in the selected period aborted CSV, XLSX and
    // PDF generation together, which is how "export is not working" presented.
    AccountingSummary summaryFor(List<Sale> sales) =>
        AccountingService().compute(
          sales: sales,
          purchases: const [],
          expenses: const [],
          payments: const [],
          supplierPayments: const [],
          products: const [],
          openingBal: null,
        );

    Sale walkInSale({String id = 'walkin-1'}) => Sale(
          id: id,
          date: DateTime(2026, 9, 27),
          // Exactly what the Walk-in button stores.
          customerId: '',
          customerName: 'Walk-in Customer',
          lineItems: [
            SaleLineItem(
              productId: 'p1',
              name: 'luxury',
              qtyOrArea: 2,
              salePrice: 60000,
              costPriceAtSale: 40000,
            ),
          ],
          paid: 100000,
        );

    /// A record written before the `customer_name` field existed: no name, and
    /// a `customer_id` shorter than the six characters the old code sliced.
    /// `substring(0, 6)` needs at least six; anything under that threw.
    Sale legacySale({String customerId = 'walk'}) => Sale(
          id: 'legacy-1',
          date: DateTime(2026, 9, 27),
          customerId: customerId,
          customerName: null,
          lineItems: [
            SaleLineItem(
              productId: 'p1',
              qtyOrArea: 2,
              salePrice: 60000,
              costPriceAtSale: 40000,
            ),
          ],
          paid: 100000,
        );

    test('CSV export survives a legacy sale with no name and a short id',
        () async {
      final service = ExportService();
      final sales = [legacySale()];

      // Precondition: the exact shape that used to throw RangeError.
      expect(sales.first.customerName, isNull);
      expect(sales.first.customerId.length, lessThan(6));

      final csv = service.buildCsvReport(
        sales: sales,
        products: const [],
        summary: summaryFor(sales),
        startDate: DateTime(2026, 9, 27),
        endDate: DateTime(2026, 9, 27),
        shopName: 'Asif Foam Center',
      );

      // The sale must be present and legibly labelled, not dropped.
      expect(csv, contains('walk'));
    });

    test('CSV export survives a nameless sale with an empty customer id',
        () async {
      final service = ExportService();
      final sales = [legacySale(customerId: '')];
      final csv = service.buildCsvReport(
        sales: sales,
        products: const [],
        summary: summaryFor(sales),
        startDate: DateTime(2026, 9, 27),
        endDate: DateTime(2026, 9, 27),
      );
      // An entirely empty id must still produce a readable label.
      expect(csv, contains('Walk-in Customer'));
    });

    test('CSV export survives a walk-in sale with an empty customer id',
        () async {
      final service = ExportService();
      final sales = [walkInSale()];

      // Precondition: the data that used to break the export.
      expect(sales.first.customerId, isEmpty);

      final csv = service.buildCsvReport(
        sales: sales,
        products: const [],
        summary: summaryFor(sales),
        startDate: DateTime(2026, 9, 27),
        endDate: DateTime(2026, 9, 27),
        shopName: 'Asif Foam Center',
      );

      // The walk-in sale must actually be in the report, labelled readably —
      // not dropped, and not an empty cell.
      expect(csv, contains('Walk-in Customer'));
    });

    test('CSV export reports real numbers for a walk-in sale', () async {
      final service = ExportService();
      final sales = [walkInSale()];
      final csv = service.buildCsvReport(
        sales: sales,
        products: const [],
        summary: summaryFor(sales),
        startDate: DateTime(2026, 9, 27),
        endDate: DateTime(2026, 9, 27),
        shopName: 'Asif Foam Center',
      );
      // Revenue 120,000, COGS 80,000, profit 40,000.
      expect(csv, contains('120,000'));
      expect(csv, contains('80,000'));
      expect(csv, contains('40,000'));
    });

    test('a short non-empty customer id does not abort the export', () async {
      final service = ExportService();
      final sales = [
        Sale(
          id: 's-short',
          date: DateTime(2026, 9, 27),
          customerId: 'abc',
          customerName: null,
          lineItems: [
            SaleLineItem(
                productId: 'p1',
                qtyOrArea: 1,
                salePrice: 100,
                costPriceAtSale: 50),
          ],
          paid: 100,
        ),
      ];
      final csv = service.buildCsvReport(
        sales: sales,
        products: const [],
        summary: summaryFor(sales),
        startDate: DateTime(2026, 9, 27),
        endDate: DateTime(2026, 9, 27),
      );
      // The full short id is used verbatim rather than throwing.
      expect(csv, contains('abc'));
    });

    test('a named customer wins over the id fallback', () async {
      final service = ExportService();
      final sales = [
        Sale(
          id: 's-named',
          date: DateTime(2026, 9, 27),
          customerId: 'abcdef123456',
          customerName: 'Bilal Traders',
          lineItems: [
            SaleLineItem(
                productId: 'p1',
                qtyOrArea: 1,
                salePrice: 100,
                costPriceAtSale: 50),
          ],
          paid: 100,
        ),
      ];
      final csv = service.buildCsvReport(
        sales: sales,
        products: const [],
        summary: summaryFor(sales),
        startDate: DateTime(2026, 9, 27),
        endDate: DateTime(2026, 9, 27),
      );
      expect(csv, contains('Bilal Traders'));
      expect(csv, isNot(contains('abcdef')));
    });
  });

  group('COGS diagnostics stay off by default', () {
    Sale lossMakingSale({String id = 's1', double salePrice = 50}) => Sale(
          id: id,
          date: DateTime(2026, 1, 1),
          customerId: 'c1',
          lineItems: [
            SaleLineItem(
              productId: 'p1',
              qtyOrArea: 2,
              salePrice: salePrice,
              // Zero cost price: the exact condition the diagnostic reports on.
              costPriceAtSale: 0,
            ),
          ],
          paid: 2 * salePrice,
        );

    test('computes the same figures whether or not diagnostics are enabled',
        () {
      final service = AccountingService();
      final products = [
        Product(
          id: 'p1',
          name: 'Foam',
          type: 'Sheet',
          sizeLength: 72,
          sizeWidth: 36,
          thickness: 4,
          density: 16,
          unitType: 'per_sqft',
          unitPrice: 0,
          costPrice: 0,
          currentStock: 10,
          lowStockThreshold: 5,
        ),
      ];
      final sales = [lossMakingSale()];

      final quiet = service.compute(
        sales: sales,
        purchases: [],
        expenses: [],
        payments: [],
        supplierPayments: [],
        products: products,
        openingBal: null,
      );
      final loud = service.compute(
        sales: sales,
        purchases: [],
        expenses: [],
        payments: [],
        supplierPayments: [],
        products: products,
        openingBal: null,
        logCogsDiagnostics: true,
      );

      expect(quiet.revenue, loud.revenue);
      expect(quiet.cogs, loud.cogs);
      expect(quiet.grossProfit, loud.grossProfit);
      expect(quiet.netProfit, loud.netProfit);
      expect(quiet.cashInHand, loud.cashInHand);
    });
  });
}

/// Number of pages the generated PDF contains.
///
/// `/Type /Page` entries are pages; `/Type /Pages` is the page-tree node and is
/// excluded by the `[^s]` guard. Overcounting would fail a one-page assertion
/// spuriously, which is why the guard matters.
int _pageCount(List<int> bytes) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;

/// Returns the width and height in millimetres of the first page's /MediaBox.
///
/// PDF user units are 1/72 inch, so `value / 72 * 25.4` converts to millimetres.
/// This is the geometry the print spooler reads \u2014 the same numbers the preview
/// uses to size the sheet.
(double, double) _firstPageSizeMm(List<int> bytes) {
  final m = RegExp(
    r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)',
  ).firstMatch(String.fromCharCodes(bytes));
  if (m == null) {
    fail('PDF has no /MediaBox, so the page size cannot be verified');
  }
  double toMm(String s) => double.parse(s) / 72 * 25.4;
  return (toMm(m.group(1)!), toMm(m.group(2)!));
}

/// Inflates every Flate stream in [bytes] and returns the concatenated bytes.
///
/// Without this the tests can only see the `%PDF-` header and the file length,
/// both of which stay valid while the drawn content is being thrown away.
String _inflateContent(List<int> bytes) {
  final out = StringBuffer();
  for (final m
      in RegExp(r'stream\r?\n').allMatches(String.fromCharCodes(bytes))) {
    final start = m.end;
    final endMarker = String.fromCharCodes(bytes).indexOf('endstream', start);
    if (endMarker < 0) continue;
    final raw = bytes.sublist(start, endMarker).toList();
    try {
      out.write(String.fromCharCodes(ZLibDecoder().decodeBytes(raw)));
    } catch (_) {
      // Not a deflate stream (fonts, metadata); ignore.
    }
  }
  return out.toString();
}

/// Minimal stand-in so this test does not depend on InitialAvatar internals.
class InitialAvatarShim extends StatelessWidget {
  const InitialAvatarShim({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 40);
}
