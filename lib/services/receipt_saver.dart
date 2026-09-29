import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Saves a PDF into the device's public Downloads folder.
///
/// Android 10 introduced scoped storage, which makes a direct `dart:io` write
/// to `/storage/emulated/0/Download` a no-op at best. MediaStore is the
/// supported route and needs no runtime permission, so Android goes through a
/// method channel implemented in `MainActivity`.
///
/// iOS has no shared Downloads folder to write to, so there the app's own
/// documents directory is used and the file is made visible to the Files app.
class ReceiptSaver {
  ReceiptSaver._();

  static final ReceiptSaver instance = ReceiptSaver._();

  /// Overridable in tests; defaults to the real platform channel.
  Future<String> Function(Uint8List bytes, String name) nativeSave =
      _defaultNativeSave;

  /// Overridable in tests so the Android branch can be exercised on a host
  /// machine, which is where the scoped-storage bug would otherwise be invisible.
  bool Function() isAndroid = () => Platform.isAndroid;

  static const MethodChannel _channel =
      MethodChannel('com.asif.foamshop/receipts');

  static Future<String> _defaultNativeSave(
    Uint8List bytes,
    String name,
  ) async {
    final result = await _channel.invokeMethod<String>('savePdf', {
      'bytes': bytes,
      'name': name,
    });
    if (result == null || result.isEmpty) {
      throw StateError('The platform returned no location for the saved PDF.');
    }
    return result;
  }

  /// Returns a human-readable description of where the file landed.
  Future<String> save(Uint8List bytes, String name) async {
    // Validate the name HERE rather than trusting every caller.
    //
    // `name` is interpolated straight into a filesystem path below, and this is
    // a public method: a caller passing '../../evil.pdf' would write outside the
    // documents directory. The current call site is safe - `billing_screen`
    // builds the name via `_safeIdPrefix`, which strips everything outside
    // [A-Za-z0-9_-] - but that is one call site, and the Android side only
    // rejects a blank name.
    final safe = _sanitizeFileName(name);
    if (isAndroid()) {
      return nativeSave(bytes, safe);
    }

    // iOS (and any non-Android host, e.g. the Dart VM under test): the app's
    // own documents directory is the closest equivalent to Downloads.
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Reduces [name] to a safe single path segment, or throws.
  ///
  /// Strips path separators and traversal (`..`), collapses anything outside
  /// [A-Za-z0-9._-] to an underscore, and requires a `.pdf` extension so a
  /// receipt can never be written as, say, an executable or an HTML file.
  static String _sanitizeFileName(String name) {
    final base = name.split(RegExp(r'[/\\]')).last;
    var safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    // `..` survives the character filter, so collapse any run of dots.
    safe = safe.replaceAll(RegExp(r'\.{2,}'), '_');
    if (safe.isEmpty || safe == '.pdf') {
      throw ArgumentError.value(
          name, 'name', 'Refusing to save a receipt with an unusable filename');
    }
    if (!safe.toLowerCase().endsWith('.pdf')) {
      throw ArgumentError.value(
          name, 'name', 'Receipt filename must end in .pdf');
    }
    return safe;
  }
}
