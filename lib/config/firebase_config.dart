import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static Future<void> init() async {
    await Firebase.initializeApp();
  }
}