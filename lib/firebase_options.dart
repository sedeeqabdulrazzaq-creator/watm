import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Generated Firebase configuration placeholder for project `watm-429c3`.
///
/// This file was recreated from `firebase.json` and the Firebase project ID.
/// Replace the placeholder API keys with real values if you need production
/// authentication or Firestore access outside the emulator.
class DefaultFirebaseOptions {
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
        return linux;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCGhAxfCRUlPjgdDZod0T6f-Pb2ga1lZWg',
    appId: '1:682194746130:web:7b7ae3f2edc40c20fad1cb',
    messagingSenderId: '682194746130',
    projectId: 'watm-429c3',
    authDomain: 'watm-429c3.firebaseapp.com',
    storageBucket: 'watm-429c3.firebasestorage.app',
    measurementId: 'G-KKP89JRWLS',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBBM831VkKgwSE9gE5Zpy0Qw_vw-epKrDM',
    appId: '1:682194746130:android:683377c86d388b35fad1cb',
    messagingSenderId: '682194746130',
    projectId: 'watm-429c3',
    storageBucket: 'watm-429c3.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDtqkMVyU9CVr9Jv7T1stnyXy_VZUMCIdE',
    appId: '1:682194746130:ios:4061f746862c12dafad1cb',
    messagingSenderId: '682194746130',
    projectId: 'watm-429c3',
    storageBucket: 'watm-429c3.firebasestorage.app',
    iosClientId: '682194746130-sk0of9uuh5h8871o4rsa7qr3qmoliomj.apps.googleusercontent.com',
    iosBundleId: 'com.watm.watm',
  );
  static const FirebaseOptions macos = ios;
  static const FirebaseOptions windows = android;
  static const FirebaseOptions linux = android;
}
