// Firebase / Identity Platform configuration for ktenas-agent-tracker.
// Generated via Firebase Management API — safe to commit (public client-side keys).

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are only configured for web. '
      'Run `flutterfire configure` to add other platforms.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCKUhk61LH39o9Dsa2Mzl2nzHHp4SDWQWM',
    appId: '1:212956760758:web:36682c74ac03658481f417',
    messagingSenderId: '212956760758',
    projectId: 'ktenas-agent-tracker',
    authDomain: 'ktenas-agent-tracker.firebaseapp.com',
    storageBucket: 'ktenas-agent-tracker.firebasestorage.app',
  );
}
