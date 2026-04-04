import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web platform not configured');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Platform not configured');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBeWj2RfyY_3dvRyi9OWd-2t7iHbv9VtI0',
    appId: '1:1031136844636:android:d52da8726af163fc45bf99',
    messagingSenderId: '1031136844636',
    projectId: 'split-expense-2c469',
    storageBucket: 'split-expense-2c469.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBeWj2RfyY_3dvRyi9OWd-2t7iHbv9VtI0',
    appId: '1:1031136844636:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '1031136844636',
    projectId: 'split-expense-2c469',
    storageBucket: 'split-expense-2c469.firebasestorage.app',
    iosBundleId: 'com.splitter.split',
  );
}
