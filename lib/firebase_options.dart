// File generated manually from Firebase Console config
// Project: trading-app-68902

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return web; // Use web config for Windows
      case TargetPlatform.linux:
        return web; // Use web config for Linux
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCwvUUybj2NEs1-WTJKWxKW7DIanSYSkpM',
    appId: '1:938293786158:web:9e69112daf0dbe7b4b51bf',
    messagingSenderId: '938293786158',
    projectId: 'trading-app-68902',
    authDomain: 'trading-app-68902.firebaseapp.com',
    storageBucket: 'trading-app-68902.firebasestorage.app',
    measurementId: 'G-KLGCHMY5X2',
  );

  // For Android, you'll need to run flutterfire configure
  // or add google-services.json manually
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCwvUUybj2NEs1-WTJKWxKW7DIanSYSkpM',
    appId: '1:938293786158:web:9e69112daf0dbe7b4b51bf',
    messagingSenderId: '938293786158',
    projectId: 'trading-app-68902',
    storageBucket: 'trading-app-68902.firebasestorage.app',
  );

  // For iOS, you'll need to run flutterfire configure
  // or add GoogleService-Info.plist manually
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCwvUUybj2NEs1-WTJKWxKW7DIanSYSkpM',
    appId: '1:938293786158:web:9e69112daf0dbe7b4b51bf',
    messagingSenderId: '938293786158',
    projectId: 'trading-app-68902',
    storageBucket: 'trading-app-68902.firebasestorage.app',
    iosBundleId: 'com.example.tradeJournalApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCwvUUybj2NEs1-WTJKWxKW7DIanSYSkpM',
    appId: '1:938293786158:web:9e69112daf0dbe7b4b51bf',
    messagingSenderId: '938293786158',
    projectId: 'trading-app-68902',
    storageBucket: 'trading-app-68902.firebasestorage.app',
    iosBundleId: 'com.example.tradeJournalApp',
  );
}

