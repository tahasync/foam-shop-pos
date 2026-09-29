import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android launcher icon against the state that shipped: the home
/// screen and app drawer still showed Flutter's stock launcher mark while the
/// sign-in screen already showed the new Foam Shop BrandMark. The two read as
/// different products.
///
/// These assertions read the shipped Android resources and the Dart source,
/// because the symptom (the wrong mark on the launcher) is a device-rendering
/// outcome a widget test cannot observe.
void main() {
  const res = 'android/app/src/main/res';

  late String manifest;
  late String adaptive;
  late String adaptiveRound;
  late String background;
  late String foreground;
  late String monochrome;
  late String brandMarkSource;

  setUpAll(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    adaptive =
        File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    adaptiveRound =
        File('$res/mipmap-anydpi-v26/ic_launcher_round.xml').readAsStringSync();
    background =
        File('$res/drawable/ic_launcher_background.xml').readAsStringSync();
    foreground =
        File('$res/drawable/ic_launcher_foreground.xml').readAsStringSync();
    monochrome =
        File('$res/drawable/ic_launcher_monochrome.xml').readAsStringSync();
    brandMarkSource =
        File('lib/widgets/design_system/brand_mark.dart').readAsStringSync();
  });

  /// Strips XML comments so a structural assertion cannot be satisfied - or
  /// defeated - by prose in a comment. The rationale for these rules lives in
  /// the resource comments and that prose names the very strings under test.
  String markupOnly(String xml) =>
      xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  group('adaptive icon layers', () {
    test('the adaptive icon exists for API 26+', () {
      expect(
          File('$res/mipmap-anydpi-v26/ic_launcher.xml').existsSync(), isTrue,
          reason: 'Without an adaptive icon the launcher falls back to the '
              'legacy PNGs and the mark is never masked or themed.');
      expect(adaptive, contains('<adaptive-icon'));
    });

    test('declares background, foreground and monochrome layers', () {
      final xml = markupOnly(adaptive);
      expect(xml, contains('<background'));
      expect(xml, contains('<foreground'));
      expect(xml, contains('<monochrome'),
          reason: 'Without a monochrome layer the icon has no Android 13+ '
              'themed-icon form and launchers render it unthemed.');
    });

    test('the round variant reuses the same layers, not a pre-shaped copy', () {
      expect(File('$res/mipmap-anydpi-v26/ic_launcher_round.xml').existsSync(),
          isTrue);
      final sq = markupOnly(adaptive);
      final rd = markupOnly(adaptiveRound);
      for (final layer in [
        'ic_launcher_background',
        'ic_launcher_foreground',
        'ic_launcher_monochrome'
      ]) {
        expect(rd, contains(layer),
            reason: 'The round icon must reference $layer too, otherwise the '
                'square and round variants can drift apart.');
        expect(sq, contains(layer));
      }
    });

    test('the background is full-bleed and not pre-rounded', () {
      final xml = markupOnly(background);
      expect(xml, contains('android:viewportWidth="108"'));
      expect(xml, contains('android:viewportHeight="108"'));
      // The launcher applies its own mask. Baking our own corner radius into
      // the background means the corners get cut twice and look visibly wrong.
      expect(xml, isNot(contains('a12.96')),
          reason: 'The background must not carry rounded corners; the '
              'launcher mask owns the silhouette.');
      expect(xml, contains('M0,0h108v108h-108z'),
          reason: 'The background layer must fill the entire 108dp canvas.');
    });

    test('the background uses the app brand tokens, not new hues', () {
      final xml = markupOnly(background);
      expect(xml, contains('@color/ic_launcher_brand_deep'));
      expect(xml, contains('@color/ic_launcher_brand_fill'));

      final colors = File('$res/values/colors.xml').readAsStringSync();
      expect(colors, contains('#FF182346'),
          reason: 'brandFillDeep must stay the Deep Navy token from '
              'AppColors in app_theme.dart.');
      expect(colors, contains('#FF3D5387'),
          reason: 'brandFill must stay the Slate Blue token from AppColors.');
      expect(brandMarkSource, contains('brandFill'),
          reason: 'BrandMark is the in-app mark the launcher must match.');
    });
  });
  group('foreground geometry survives the launcher mask', () {
    test('the rule sits inside the 72dp visible area', () {
      final xml = markupOnly(foreground);
      // BrandMark draws its rule at 0.68 of the mark. Treating the central 72dp
      // as the whole mark gives a 48.96dp rule spanning 29.52..78.48.
      expect(xml, contains('M42.48,29.52'),
          reason: 'The rule must start at the safe-zone geometry, not at a '
              'naive 0.68 x 108 mapping that the launcher mask would clip.');
      expect(xml, contains('a12.96,12.96'));
    });

    test('the glyph is centred and scaled, not hand-baked into the path', () {
      final xml = markupOnly(foreground);
      expect(xml, contains('android:translateX="37.125"'));
      expect(xml, contains('android:scaleX="1.40625"'));
      expect(xml, contains('android:scaleY="1.40625"'),
          reason: 'The glyph must be positioned by a <group> transform so it '
              'can be re-derived from the Dart painter, not by editing path '
              'numbers by hand.');
    });

    test('the rule and glyph are white on a transparent foreground', () {
      final xml = markupOnly(foreground);
      expect(xml, contains('@color/ic_launcher_ring'));
      expect(xml, contains('#FFFFFFFF'));
      // The foreground layer must not paint a backdrop; the background layer
      // owns that, and doubling it is what produces a flat icon.
      expect(xml, isNot(contains('M0,0h108v108h-108z')));
    });
  });

  group('the glyph cannot drift from the Dart painter', () {
    /// Re-derives the foam glyph path from `_FoamGlyphPainter` in
    /// brand_mark.dart by reading its real coefficients, scaling the
    /// normalised 0..1 values onto the 24-unit viewport the vector uses.
    ///
    /// This is the load-bearing test in this file. The vector drawable and the
    /// Dart painter are two hand-maintained copies of one shape; the failure
    /// mode is a tweak to the in-app mark that ships while the launcher icon
    /// stays stale - a silent brand regression that reading these files by eye
    /// would not catch. Deriving the expectation from the source of truth
    /// makes that impossible.
    String deriveGlyphPathFromPainter(String source) {
      final painter =
          source.substring(source.indexOf('class _FoamGlyphPainter'));
      const viewport = 24.0; // the vector's glyph viewport
      final buffer = StringBuffer();

      for (final raw in painter.split('\n')) {
        final line = raw.trim();
        if (line.startsWith('//') || line.isEmpty) continue;

        final isMove = line.contains('path.moveTo(');
        final isCubic = line.contains('path.cubicTo(');
        if (!isMove && !isCubic) continue;

        final coords = RegExp(r'[wh] \* ([0-9.]+)').allMatches(line).map((m) {
          // w and h are both the glyph box, so the two axes scale alike.
          final v = double.parse(m.group(1)!) * viewport;
          final r = (v * 10000).round() / 10000;
          return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
        }).toList();

        if (isMove) {
          buffer.write('M${coords[0]},${coords[1]}');
        } else if (coords.length == 6) {
          buffer.write('C${coords.join(' ')}');
        }
      }
      buffer.write('Z');
      return buffer.toString();
    }

    /// Normalises a path into comparable tokens: command letters plus one
    /// token per coordinate.
    ///
    /// Comparing raw strings is not safe here, because SVG path syntax treats
    /// a comma and a space as interchangeable separators ("C4.8 10.08" and
    /// "C4.8,10.08" are the same curve). Stripping all whitespace instead
    /// glues coordinates together and corrupts the very thing being compared.
    /// So both sides are tokenised and numbers are normalised, which leaves a
    /// mismatch meaning one of two things: a genuinely different number, or a
    /// different command order. Both are real drift.
    List<String> pathTokens(String path) {
      // Split command letters away from the numbers. In SVG a command letter
      // may abut a coordinate with no separator at all ("17.28C4.8" is valid),
      // so a plain whitespace split fuses the two into one meaningless token.
      final spaced = path
          .replaceAll(',', ' ')
          .replaceAllMapped(RegExp(r'[A-Za-z]'), (m) => ' ${m[0]} ');
      return spaced.split(' ').where((t) => t.isNotEmpty).map((t) {
        final n = double.tryParse(t);
        if (n == null) return t.toUpperCase();
        final r = (n * 10000).round() / 10000;
        return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
      }).toList();
    }

    String? glyphPathIn(String xml) =>
        RegExp(r'android:pathData="(M2\.88[^"]+)"').firstMatch(xml)?.group(1);

    test('the vector glyph path matches the in-app BrandMark glyph', () {
      final expected = deriveGlyphPathFromPainter(brandMarkSource);
      expect(expected, isNot(contains('M0,0')),
          reason: 'The painter path could not be parsed; without this guard '
              'the comparison below would pass vacuously.');

      final pathData = glyphPathIn(markupOnly(foreground));
      expect(pathData, isNotNull,
          reason: 'No foam glyph path found in the launcher foreground.');

      expect(pathTokens(pathData!), pathTokens(expected),
          reason: 'The launcher glyph has drifted from _FoamGlyphPainter in '
              'brand_mark.dart. The launcher icon must show the same foam mark '
              'as the sign-in screen.');
    });

    test('the monochrome glyph matches the colour glyph', () {
      final colour = glyphPathIn(markupOnly(foreground))!;
      final mono = glyphPathIn(markupOnly(monochrome))!;
      expect(pathTokens(mono), pathTokens(colour),
          reason: 'The themed icon must not resize or redraw the mark when the '
              'user switches themed icons on.');
    });
  });

  group('monochrome layer', () {
    test('has no painted background, so the system can tint it freely', () {
      final xml = markupOnly(monochrome);
      expect(xml, isNot(contains('<background')));
      expect(xml, isNot(contains('M0,0h108v108h-108z')),
          reason: 'A themed icon must be shape-only; any painted backdrop '
              'defeats re-tinting.');
    });

    test('is fully opaque, because the system flattens alpha anyway', () {
      final xml = markupOnly(monochrome);
      expect(xml, contains('#FFFFFFFF'));
      expect(xml, isNot(contains('@color/ic_launcher_ring')),
          reason: 'A 35%-alpha rule flattens to a solid block under re-tint; '
              'the themed variant must be opaque.');
    });
  });

  group('legacy PNG fallbacks', () {
    // Adaptive icons do not exist below API 26, so the raster icons still ship
    // for those devices and must be regenerated rather than left as Flutter's
    // stock mark.
    const expected = [
      'mipmap-mdpi',
      'mipmap-hdpi',
      'mipmap-xhdpi',
      'mipmap-xxhdpi',
      'mipmap-xxxhdpi',
    ];

    for (final dir in expected) {
      test('$dir has ic_launcher.png and ic_launcher_round.png', () {
        final f = File('$res/$dir/ic_launcher.png');
        expect(f.existsSync(), isTrue,
            reason: 'Pre-API-26 launchers have no adaptive icon and would '
                'otherwise show the stock Flutter mark.');
        expect(f.lengthSync(), greaterThan(0));
        expect(File('$res/$dir/ic_launcher_round.png').existsSync(), isTrue,
            reason: 'Round fallbacks should exist at every density too.');
      });
    }
  });

  group('manifest wiring', () {
    test('declares both the square and round launcher icon', () {
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
      expect(
          manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    });

    test('the notification small icon is still NOT the launcher icon', () {
      // Guards the earlier fix: Android renders a notification small icon as
      // an alpha-only mask, so pointing it at an adaptive icon with an opaque
      // background layer shows a solid block in the status bar.
      final app = manifest.substring(manifest.indexOf('<application'));
      final iconTag =
          RegExp(r'android:icon="([^"]+)"').firstMatch(app)!.group(1);
      final notifIcon = RegExp(
              r'default_notification_icon"\s*\n?\s*android:resource="([^"]+)"')
          .firstMatch(manifest)!
          .group(1);
      expect(notifIcon, isNot(iconTag),
          reason: 'The notification icon and the launcher icon must stay '
              'separate resources.');
      expect(notifIcon, '@drawable/ic_stat_foam_shop');
    });
  });

  // __PART2__
}
