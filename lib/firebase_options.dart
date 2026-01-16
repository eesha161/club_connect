// File generated manually
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not supported in this manual configuration yet.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'MacOS is not supported in this manual configuration yet.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Windows is not supported in this manual configuration yet.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Linux is not supported in this manual configuration yet.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC92XUriZMUAfcP3e3_cyt--2LoaGWlxlM',
    appId: '1:189700476090:android:998b1620e350762a148683',
    messagingSenderId: '189700476090',
    projectId: 'club-connect', // Replace if different
    storageBucket: 'club-connect.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC92XUriZMUAfcP3e3_cyt--2LoaGWlxlM',
    appId: '1:189700476090:ios:cc6875e1529b608a148683',
    messagingSenderId: '189700476090',
    projectId: 'club-connect', // Replace if different
    storageBucket: 'club-connect.appspot.com',
    iosClientId: '189700476090-htt43b5l4hejive5ahj1b6blequv99m9.apps.googleusercontent.com',
    iosBundleId: 'com.example.clubConnect',
  );
}
