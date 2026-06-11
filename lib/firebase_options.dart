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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBAQx8uo7kgbCxBpdeuE4b2Y7SM_6SSIkc',
    appId: '1:937376123870:android:1d871d5dd8d05c8d5feb4f',
    messagingSenderId: '937376123870',
    projectId: 'sparkwork-f41ec',
    storageBucket: 'sparkwork-f41ec.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCLkUahFqBnFQV4aIxzYeIpw1Cu5GIGR9w',
    appId: '1:937376123870:ios:6267024edcb16cbb5feb4f',
    messagingSenderId: '937376123870',
    projectId: 'sparkwork-f41ec',
    storageBucket: 'sparkwork-f41ec.firebasestorage.app',
    iosBundleId: 'com.sparkwork.sparkwork',
  );
}