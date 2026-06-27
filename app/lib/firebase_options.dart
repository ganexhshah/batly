// Firebase configuration auto-generated from google-services.json.
// Project: zone-e4bb4 | Package: com.wiperspace.crack
//
// To regenerate this file, run:
//   flutterfire configure --project=zone-e4bb4

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// True when the current platform has a real Firebase app ID (not placeholder).
  static bool get isConfigured => !currentPlatform.appId.contains('TODO');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions has not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDZzYgbmUdGqG_VWkUDCkB1DAeOgPY5-Zc',
    appId: '1:599762240617:android:9493219b9140f5f9dccef8',
    messagingSenderId: '599762240617',
    projectId: 'zone-e4bb4',
    storageBucket: 'zone-e4bb4.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDZzYgbmUdGqG_VWkUDCkB1DAeOgPY5-Zc',
    appId: '1:599762240617:ios:TODO',
    messagingSenderId: '599762240617',
    projectId: 'zone-e4bb4',
    storageBucket: 'zone-e4bb4.firebasestorage.app',
    iosBundleId: 'com.wiperspace.crack',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDZzYgbmUdGqG_VWkUDCkB1DAeOgPY5-Zc',
    appId: '1:599762240617:ios:TODO',
    messagingSenderId: '599762240617',
    projectId: 'zone-e4bb4',
    storageBucket: 'zone-e4bb4.firebasestorage.app',
    iosBundleId: 'com.wiperspace.crack',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDZzYgbmUdGqG_VWkUDCkB1DAeOgPY5-Zc',
    appId: '1:599762240617:web:TODO',
    messagingSenderId: '599762240617',
    projectId: 'zone-e4bb4',
    authDomain: 'zone-e4bb4.firebaseapp.com',
    storageBucket: 'zone-e4bb4.firebasestorage.app',
  );

  /// OAuth 2.0 Web client ID from Firebase / Google Cloud Console.
  /// Required for Google Sign-In on Flutter web.
  static const String googleWebClientId =
      '599762240617-nureqkhmpd0c0vh7badk4kfv270r86e7.apps.googleusercontent.com';

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDZzYgbmUdGqG_VWkUDCkB1DAeOgPY5-Zc',
    appId: '1:599762240617:web:TODO',
    messagingSenderId: '599762240617',
    projectId: 'zone-e4bb4',
    storageBucket: 'zone-e4bb4.firebasestorage.app',
  );
}