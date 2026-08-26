import 'package:firebase_core/firebase_core.dart';

/// Inert placeholder. Every value below is a literal 'REPLACE_ME' — this
/// file does nothing useful until a real Firebase project exists.
///
/// The only step needed to go live on Firestore:
///   1. Create the Firebase project, then from app/ run:
///        flutterfire configure --out=lib/core/firebase_options.dart
///      (flutterfire's default output path is lib/firebase_options.dart —
///      pass --out explicitly so it overwrites *this* file in place).
///   2. Flip AppConfig.useMockData to false (core/app_config.dart).
///
/// Nothing else in the app needs to change: AppState already swaps every
/// repository for its Firestore-backed implementation based on that flag.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME',
  );
}
