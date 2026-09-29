import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android manifest and R8 configuration against permissions that
/// were declared or kept for no functional reason.
///
/// None of these fail a build or break a widget test. They are silent
/// over-grants, so they drift back in unnoticed unless something checks.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final proguard = File('android/app/proguard-rules.pro').readAsStringSync();

  /// Strips XML comments and `#` comment lines.
  ///
  /// Necessary because both config files explain WHY each decision was made,
  /// and those explanations name the very things being removed
  /// ("READ_EXTERNAL_STORAGE was removed...", "A rule reading
  /// `-keep class com.example.replaced...` sat here"). A naive `contains` over
  /// the raw text matches that prose instead of the directive, so these checks
  /// would fail while the config is actually correct - and would equally
  /// "pass" if a real `<uses-permission>` or `-keep` were re-added beside the
  /// comment explaining its removal.
  String stripComments(String source) {
    return source
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'^\s*#.*$', multiLine: true), '');
  }

  /// The manifest with comments removed - what Android actually parses.
  final manifestDirectives = stripComments(manifest);

  /// The ProGuard file with comments removed - the active directives only.
  final proguardDirectives = stripComments(proguard);

  group('Android manifest permissions', () {
    test('does not include customer data in backups', () {
      // This is a point-of-sale register. `LocalNotificationService` writes a
      // CUSTOMER PHONE NUMBER into SharedPreferences, and Firestore's local
      // persistence cache holds the entire ledger. With the Android default of
      // allowBackup="true", both are swept into the user's cloud/ADB backup in
      // cleartext and restored onto any device they sign in to.
      expect(
        manifestDirectives,
        contains('android:allowBackup="false"'),
        reason: 'Customer phone numbers and the local ledger cache must not '
            'leave the device in a backup. Firestore is the source of truth, '
            'so excluding local state costs nothing.',
      );
    });

    test('ships the data extraction rules the manifest references', () {
      // allowBackup="false" alone is not honoured on API 31+ for
      // device-to-device transfer, so the manifest points at this file. A
      // dangling @xml reference is a build failure, and an absent file means
      // the exclusion silently does not apply where it matters most.
      final rules =
          File('android/app/src/main/res/xml/data_extraction_rules.xml');
      expect(rules.existsSync(), isTrue,
          reason: 'android:dataExtractionRules points at this file; a missing '
              'file breaks the build.');
      final body = rules.readAsStringSync();
      // Both transports must be excluded, not just cloud backup.
      expect(body, contains('<cloud-backup>'));
      expect(body, contains('<device-transfer>'));
      // sharedpref is the domain that actually holds the phone number.
      expect(body, contains('sharedpref'));
    });

    test('does not request READ_EXTERNAL_STORAGE', () {
      // Declared at maxSdkVersion=32 but never exercised. The only storage
      // access is the WRITE path (MainActivity.saveLegacy, and MediaStore for
      // API 29+), and receipts are read back from app-private storage via
      // path_provider - never from shared media. On API 29-32 this granted read
      // access to the user's photos, downloads and media for nothing, on an app
      // that holds customer names and phone numbers.
      expect(
        manifestDirectives,
        isNot(contains('READ_EXTERNAL_STORAGE')),
        reason: 'READ_EXTERNAL_STORAGE is unused. Removing it drops an '
            'unrequested grant to the device media store. Re-add it only if a '
            'real read path is added, and name that path in a comment.',
      );
    });

    test('keeps POST_NOTIFICATIONS, which the app does use', () {
      // The counterpart to the test above: a guard that only removed things
      // would happily let the permission the app actually needs disappear.
      expect(
        manifestDirectives,
        contains('POST_NOTIFICATIONS'),
        reason: 'LocalNotificationService.show() needs this on API 33+.',
      );
    });

    test('keeps the legacy write permission scoped to API 28', () {
      // WRITE_EXTERNAL_STORAGE is genuinely used by MainActivity.saveLegacy(),
      // but only on API <= 28. The cap is what keeps it inert on modern
      // devices, so the cap itself is load-bearing.
      expect(
        manifestDirectives,
        contains('WRITE_EXTERNAL_STORAGE'),
        reason: 'The legacy save path still needs this on API 24-28.',
      );
      expect(
        manifestDirectives,
        contains('maxSdkVersion="28"'),
        reason: 'The write grant must stay capped at API 28; MediaStore '
            'covers 29+ with no permission.',
      );
    });
  });

  group('R8 keep rules', () {
    test('does not keep the Flutter template namespace', () {
      // `com.example.replaced` is the `flutter create` default. This app's
      // namespace is `com.asif.foamshop`, so the rule matched nothing and
      // never has. It is worse than useless: scanning the file gives the
      // impression that serialization is protected when it never was.
      expect(
        proguardDirectives,
        isNot(contains('com.example.replaced')),
        reason: 'That is the Flutter template package, not this app. It '
            'matches zero classes. Delete it rather than leaving a rule that '
            'reads like protection but provides none.',
      );
    });

    test('does not blanket-keep the Firebase or GMS trees', () {
      // Both ship consumer ProGuard rules; keeping every class disabled
      // shrinking and obfuscation across the two largest dependency trees,
      // inflating the APK and leaving names readable when decompiled.
      expect(
        proguardDirectives,
        isNot(contains('-keep class com.google.firebase.**')),
        reason: 'Firebase ships its own consumer rules. A blanket keep '
            'defeats R8 for the whole tree.',
      );
      expect(
        proguardDirectives,
        isNot(contains('-keep class com.google.android.gms.**')),
        reason: 'Play Services ships its own consumer rules. Same reason.',
      );
    });

    test('keeps the generic-signature attributes the rules still need', () {
      // The attribute rules were the genuinely useful part of the original
      // file; they must survive any cleanup of the dead rules above.
      expect(proguardDirectives, contains('-keepattributes Signature'));
      expect(proguardDirectives, contains('-keepattributes *Annotation*'));
    });
  });

  group('release logging', () {
    test('the diagnostic logger is gated on kDebugMode', () {
      final source =
          File('lib/utils/safe_error_handler.dart').readAsStringSync();
      // Both helpers must refuse to print outside a debug build. A Firebase
      // PERMISSION_DENIED message embeds the shop's UID, and a Dart stack trace
      // embeds absolute build paths; both reached Crashlytics unconditionally.
      //
      // Checked per-function rather than by counting a fixed text pattern: the
      // two helpers are written differently on purpose. `logDiagnostic` uses a
      // single-statement `if`, `logDiagnosticWithStack` uses a braced block
      // because it prints twice, so any regex pinned to one exact shape would
      // fail the moment the other form is used.
      for (final fn in ['logDiagnostic', 'logDiagnosticWithStack']) {
        final start = source.indexOf('void $fn(');
        expect(start, greaterThan(-1), reason: '$fn must still exist.');

        // The body runs to the next top-level `void` declaration.
        final next = source.indexOf('\nvoid ', start + 1);
        final body = source.substring(
          start,
          next == -1 ? source.length : next,
        );

        expect(
          body.contains('kDebugMode'),
          isTrue,
          reason: '$fn must guard its printing on kDebugMode, or its output '
              'ships in the release APK and reaches Crashlytics.',
        );
        expect(
          body.contains('debugPrint'),
          isTrue,
          reason: '$fn is expected to be the place debugPrint is used.',
        );
      }
      // And the guard must be the real compile-time flag, not a runtime bool.
      expect(
        source,
        contains("import 'package:flutter/foundation.dart';"),
        reason: 'kDebugMode comes from flutter/foundation.',
      );
    });

    test('main.dart routes release-path logs through the gated logger', () {
      final main = File('lib/main.dart').readAsStringSync();
      // A bare debugPrint in main.dart ships in release. The only ones allowed
      // anywhere in lib/ are inside utils/safe_error_handler.dart itself.
      expect(
        main.contains('debugPrint'),
        isFalse,
        reason: 'main.dart must use logDiagnostic/logDiagnosticWithStack, not '
            'raw debugPrint, so release builds do not emit stack traces.',
      );
      expect(main, contains('logDiagnostic('));
    });
  });

  group('Release plugin registrant', () {
    // `flutter build apk --release` and `flutter build appbundle --release` were
    // both failing outright with:
    //
    //   GeneratedPluginRegistrant.java:54: error: package
    //   dev.flutter.plugins.integration_test does not exist
    //
    // The mechanism. `integration_test` is a dev_dependency, and the Flutter
    // Gradle plugin deliberately omits dev-dependency plugin modules from the
    // RELEASE compile classpath - `PluginHandler.configurePluginProject` only
    // adds `${buildType}Api` when `dev_dependency` is false or the buildType is
    // not "release". Meanwhile the Java registrant is generated by the Dart
    // tool. Each side is individually correct; the mismatch is what fails.
    //
    // What makes it intermittent: the generated file is NOT tracked in git
    // (android/.gitignore lists it), and it is rewritten by nearly every
    // `flutter` invocation. A bare `flutter test` runs in a non-release context
    // and puts `integration_test` straight back in. A release build normally
    // rewrites it correctly first, so the failure needs the stale file to be
    // consumed before that happens.
    //
    // The check below therefore guards the committed source of truth - where
    // `integration_test` is declared - rather than the generated artefact,
    // which churns on every command and would fail for reasons unrelated to the
    // source. Regenerating the file is the remedy when a build does trip:
    //   rm android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
    //
    // Root cause of the mismatch above. `integration_test` MUST be declared
    // under `dev_dependencies`. If it ever moves to `dependencies`, the Gradle
    // side stops excluding it from the release classpath while the Dart-side
    // registrant keeps listing it - the two agree again, but the test-only
    // plugin is now compiled into every shipped release APK.
    //
    // This asserts the committed source of truth rather than the generated
    // file, on purpose. The generated registrant is rewritten by nearly every
    // `flutter` invocation in a non-release context (a bare `flutter test` puts
    // `integration_test` straight back into it), so asserting on it would fail
    // intermittently and for reasons that have nothing to do with the source.
    test('integration_test is a dev dependency, not a runtime one', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final devSection = pubspec.split('dev_dependencies:').last;

      expect(
        devSection,
        contains('integration_test:'),
        reason: 'integration_test must stay under dev_dependencies. In '
            'dependencies it is compiled into the shipped release APK.',
      );

      // And it must not ALSO appear in the runtime dependencies block.
      final runtimeSection = pubspec.split('dev_dependencies:').first;
      expect(
        runtimeSection.contains('integration_test:'),
        isFalse,
        reason: 'integration_test is listed in the runtime dependencies, so it '
            'ships in release builds.',
      );
    });
  });

  group('Firebase project binding', () {
    test('.firebaserc pins the project so no --project flag is needed', () {
      final rc = File('.firebaserc');
      expect(
        rc.existsSync(),
        isTrue,
        reason: 'Without .firebaserc every `firebase deploy` needs --project, '
            'and the project id is otherwise recorded only in '
            'google-services.json, which is gitignored.',
      );

      final parsed = jsonDecode(rc.readAsStringSync()) as Map<String, dynamic>;
      final projects = parsed['projects'] as Map<String, dynamic>?;
      expect(
        projects?['default'],
        isNotNull,
        reason: '.firebaserc must set projects.default.',
      );
    });

    test('the pinned project id matches google-services.json', () {
      // The two must agree, or a deploy silently targets a different project
      // than the one the app is configured for.
      final rc = jsonDecode(File('.firebaserc').readAsStringSync())
          as Map<String, dynamic>;
      final defaultProject =
          (rc['projects'] as Map<String, dynamic>)['default'] as String;

      final gservices = File('android/app/google-services.json');
      if (!gservices.existsSync()) {
        // Gitignored, so absent in some checkouts. Nothing to cross-check.
        return;
      }
      final config =
          jsonDecode(gservices.readAsStringSync()) as Map<String, dynamic>;
      final info = config['project_info'] as Map<String, dynamic>;

      expect(
        defaultProject,
        info['project_id'],
        reason: '.firebaserc and google-services.json disagree on the project '
            'id. A deploy would target one project while the app is configured '
            'for another.',
      );
    });
  });
}
