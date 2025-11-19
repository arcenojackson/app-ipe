import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:ipe_flutter/firebase_options.dart';

class FirebaseConfig {
  static FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;
  static FirebaseAnalytics? _analytics;
  static FirebaseCrashlytics? _crashlytics;

  static FirebaseAuth get auth => _auth!;
  static FirebaseFirestore get firestore => _firestore!;
  static FirebaseAnalytics get analytics => _analytics!;
  static FirebaseCrashlytics get crashlytics => _crashlytics!;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;

      await _crashlytics!.setCrashlyticsCollectionEnabled(true);
      await _analytics!.setAnalyticsCollectionEnabled(true);

      _auth!.authStateChanges().listen((User? user) {
        if (user != null) {
          // Usuário autenticado - logs gerenciados pelo Crashlytics em produção
          if (kDebugMode) {
          print('✅ Usuário logado: ${user.email} (${user.uid})');
          }
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  static bool get isInitialized => _auth != null && _firestore != null;
}
