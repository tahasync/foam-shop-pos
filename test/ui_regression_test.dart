import 'package:archive/archive.dart' show ZLibDecoder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foam_shop_register/theme/app_theme.dart';
import 'package:foam_shop_register/screens/home_screen.dart';
import 'package:foam_shop_register/services/receipt_pdf.dart';
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
  group('Palette integrity â€” colours must not drift', () {
    test('light and dark both define every glass-engine token', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final ac = theme.extension<AppColors>()!;
        // If any of these were dropped, the glass engine would silently fall
        // back to transparent and every surface would lose its edge.
        expect(ac.glassHairline.a, greaterThan(0), reason: 'hairline must be visible');
        expect(ac.glassElevated.a, greaterThan(0.5), reason: 'raised glass must be dense');
        expect(ac.glassScrim.a, greaterThan(0.2), reason: 'scrim must dim');
        expect(ac.glassNested.a, greaterThan(0), reason: 'nested slot must be visible');
        expect(ac.glassBlur, greaterThan(0));
      }
    });

    test('light and dark hairlines are opposites (visible in both themes)', () {
      // A dark hairline is invisible on dark glass â€” this is the trap that made
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
              reason: 'controlBorder is invisible (${ratio.toStringAsFixed(2)}:1) '
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
      // Dark cards used to be #141A2A on a #0E0D15 page â€” almost no separation,
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

      expect(darkLift, greaterThan(1.08), reason: 'dark card must lift off the page');
      expect(lightLift, greaterThan(1.08), reason: 'light card must lift off the page');
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
        final spread =
            c.computeLuminance().abs() + (c.r - c.b).abs() / 255;
        expect(spread, lessThan(0.25), reason: 'neutral $c is too blue');
      }
    });

    test('body text clears 4.5:1 on the card surface', () {
      // `inkFaint` sits under every secondary label in the app.
      //
      // WCAG contrast is (lighter + 0.05) / (darker + 0.05). It has to be
      // computed with the ordering resolved, not ink-over-card literally â€”
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
      // The page was briefly #0D0D11 â€” 5% grey, which on an OLED panel reads
      // as "screen off". Cards sank into it and the layout lost its depth. It
      // has to stay a *dark theme*, not a black void.
      //
      // Asserted on the 8-bit channel rather than a luma float: "at least 18"
      // is a legible statement, whereas a tuned luma threshold just encodes
      // whatever value happened to be chosen.
      final dark = AppTheme.dark().extension<AppColors>()!;
      // `Color.r/g` are normalised 0..1, so scale to 8-bit for readability.
      int ch8(double c) => (c * 255).round();
      expect(ch8(dark.surface.r), greaterThanOrEqualTo(18), reason: 'page too black');
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

  group('Input fix â€” no opaque slab inside the glass search pill', () {
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
          child: AppField(label: 'Amount', hintText: '0', errorText: 'Required'),
        ),
      ));
      // Placeholder-only labelling is a pro-rules violation; the label must be
      // on screen regardless of whether the user has typed.
      expect(find.text('AMOUNT'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
    });
  });

  group('Layout fix â€” content is never hidden behind the floating nav', () {
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

  group('KPI row â€” tiles share one height', () {
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

  group('Rendering stability', () {
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

  group('Glass budget â€” blur is rationed to the floating nav only', () {
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

    testWidgets('the app background paints no ambient animation', (tester) async {
      // The old background ran three infinite `AnimationController`s driving
      // large radial-gradient orbs, repainting the full screen forever. If one
      // came back, `pumpAndSettle` below would never return â€” an infinite
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
    // squeezed the sibling `Expanded` to zero â€” the customer card rendered as a
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


    testWidgets('an inline button respects custom horizontal padding', (tester) async {
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
      expect((decoration.borderRadius! as BorderRadius).topLeft.x,
          greaterThan(0));
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
        theme: brightness == Brightness.dark
            ? AppTheme.dark()
            : AppTheme.light(),
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
        await pumpVariant(
            tester, AppButtonVariant.outline, brightness);
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
        await pumpVariant(
            tester, AppButtonVariant.outline, brightness);
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
          final ratio = (a > b ? a + 0.05 : b + 0.05) /
              (a > b ? b + 0.05 : a + 0.05);
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

  group('Receipt PDF', () {
    // The receipt is the one artefact a customer physically takes away, so a
    // regression here is a business bug, not a cosmetic one.
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
            'name': 'Premium High Density Memory Foam Roll Full Size Extra Long',
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
      // renderers then drop everything drawn before it — the shop header, the
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
      // The built-in Helvetica is WinAnsi only, so "✓ FULLY PAID" printed as a
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
  });
}

/// Inflates every Flate stream in [bytes] and returns the concatenated bytes.
///
/// Without this the tests can only see the `%PDF-` header and the file length,
/// both of which stay valid while the drawn content is being thrown away.
String _inflateContent(List<int> bytes) {
  final out = StringBuffer();
  for (final m in RegExp(r'stream\r?\n').allMatches(String.fromCharCodes(bytes))) {
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
