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
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions are not supported for ${defaultTargetPlatform.name}');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCK2xTr2THNUzF-_ReoNS_uKVW-n_AKkYQ',
    appId: '1:937376123870:web:72f1136145c839365feb4f',
    messagingSenderId: '937376123870',
    projectId: 'sparkwork-f41ec',
    authDomain: 'sparkwork-f41ec.firebaseapp.com',
    storageBucket: 'sparkwork-f41ec.firebasestorage.app',
    measurementId: 'G-C2782RVGXV',
  );

  // ⚠️ Garde tes vrais valeurs Android et iOS ici — ne touche pas à ces sections
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: '1:000000000000:android:000000000000000000000000',
    messagingSenderId: '937376123870',
    projectId: 'sparkwork-f41ec',
    storageBucket: 'sparkwork-f41ec.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: '1:000000000000:ios:000000000000000000000000',
    messagingSenderId: '937376123870',
    projectId: 'sparkwork-f41ec',
    storageBucket: 'sparkwork-f41ec.firebasestorage.app',
    iosBundleId: 'com.sparkwork.sparkwork',
  );
}