import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:ipe_flutter/firebase_options.dart';

import 'app_environment.dart';
import 'local_firebase_options.dart';

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
      // Emulador: sempre as opções do projeto demo, qualquer que seja o
      // firebase_options.dart gerado na máquina (produção ou stub local).
      final options = AppEnvironment.useEmulator
          ? LocalFirebaseOptions.currentPlatform
          : DefaultFirebaseOptions.currentPlatform;
      _assertNotDemoOutsideEmulator(options);

      await Firebase.initializeApp(options: options);

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      if (AppEnvironment.useEmulator) {
        await _connectEmulators();
        _listenAuth();
        return;
      }

      _analytics = FirebaseAnalytics.instance;

      await _analytics!.setAnalyticsCollectionEnabled(true);

      if (!kIsWeb) {
        _crashlytics = FirebaseCrashlytics.instance;
        await _crashlytics!.setCrashlyticsCollectionEnabled(true);
      }

      _listenAuth();
    } catch (e) {
      rethrow;
    }
  }

  static void _listenAuth() {
    _auth!.authStateChanges().listen((User? user) {
      if (user != null) {
        if (kDebugMode) {
          print('✅ Usuário logado: ${user.email} (${user.uid})');
        }
      }
    });
  }

  /// Trava de segurança: a configuração demo (stub gerado pelo `npm run
  /// setup`) nunca roda sem emuladores.
  static void _assertNotDemoOutsideEmulator(FirebaseOptions options) {
    if (options.projectId.startsWith('demo-') && !AppEnvironment.useEmulator) {
      throw StateError(
        'Este clone usa a configuração local (projeto ${options.projectId}). '
        'Rode com --dart-define=USE_EMULATOR=true e os emuladores no ar '
        '(npm run dev + npm run app). Veja docs/DESENVOLVIMENTO_LOCAL.md.',
      );
    }
  }

  static Future<void> _connectEmulators() async {
    final host = AppEnvironment.emulatorHost;
    await _auth!.useAuthEmulator(host, AppEnvironment.authEmulatorPort);
    _firestore!.useFirestoreEmulator(
      host,
      AppEnvironment.firestoreEmulatorPort,
    );
    FirebaseFunctions.instance.useFunctionsEmulator(
      host,
      AppEnvironment.functionsEmulatorPort,
    );
  }

  static bool get isInitialized => _auth != null && _firestore != null;
}
