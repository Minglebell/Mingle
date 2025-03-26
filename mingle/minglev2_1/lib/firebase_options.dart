import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCiZMeMdKrpFWB6hyIFfShfu_N3DJrgVr0',
    appId: '1:410780510942:web:538244212c2cb157e5b04f',
    messagingSenderId: '410780510942',
    projectId: 'mingle-6db44',
    authDomain: 'mingle-6db44.firebaseapp.com',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCiZMeMdKrpFWB6hyIFfShfu_N3DJrgVr0',
    appId: '1:410780510942:web:538244212c2cb157e5b04f',
    messagingSenderId: '410780510942',
    projectId: 'mingle-6db44',
    authDomain: 'mingle-6db44.firebaseapp.com',
  );
} 