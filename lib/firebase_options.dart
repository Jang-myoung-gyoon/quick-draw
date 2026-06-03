import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError('Firebase is configured for web builds only.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDXBFlU3SdAIh0eBxERZJY3SIXwdARTgKM',
    appId: '1:446817919088:web:703fdbce2ae5d5633a94b5',
    messagingSenderId: '446817919088',
    projectId: 'quick-draw-aaceb',
    authDomain: 'quick-draw-aaceb.firebaseapp.com',
    databaseURL: 'https://quick-draw-aaceb-default-rtdb.firebaseio.com',
    storageBucket: 'quick-draw-aaceb.firebasestorage.app',
    measurementId: 'G-KLES2YLBT5',
  );
}
