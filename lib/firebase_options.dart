import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // For Android only in this project
    return android;
  }

  /// Firebase options for Android platform.
  /// You need to replace these values with your own Firebase project configuration.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBh8AvpmR_ey_5t_TaY7mtc0IKTa7hUkCk',
    appId: '1:695577455303:android:fa70d9f5ee4af0f1882ce2',
    messagingSenderId: '695577455303',
    projectId: 'test2-9c019',
    storageBucket: 'test2-9c019.firebasestorage.app',
  );
} 