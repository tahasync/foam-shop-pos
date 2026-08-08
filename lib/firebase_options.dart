// Secrets injected via --dart-define-from-file=env/firebase_config.json
// Build with: flutter run --dart-define-from-file=env/firebase_config.json
// NEVER check env/firebase_config.json into version control (see .gitignore)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static String get webClientId => const String.fromEnvironment('FIREBASE_WEB_CLIENT_ID');

  static FirebaseOptions get android {
    const apiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_ANDROID_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_ANDROID_PROJECT_ID');
    const bucket = String.fromEnvironment('FIREBASE_ANDROID_STORAGE_BUCKET');
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: bucket,
    );
  }

  static FirebaseOptions get ios {
    const apiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_IOS_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_IOS_PROJECT_ID');
    const bucket = String.fromEnvironment('FIREBASE_IOS_STORAGE_BUCKET');
    const androidClientId = String.fromEnvironment('FIREBASE_IOS_ANDROID_CLIENT_ID');
    const iosClientId = String.fromEnvironment('FIREBASE_IOS_CLIENT_ID');
    const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: bucket,
      androidClientId: androidClientId,
      iosClientId: iosClientId,
      iosBundleId: iosBundleId,
    );
  }
}
