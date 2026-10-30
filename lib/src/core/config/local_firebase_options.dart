// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opções do projeto de DEMONSTRAÇÃO (`demo-ipe`), usadas somente com
/// `--dart-define=USE_EMULATOR=true`. Os valores são fictícios e só fazem
/// sentido contra os emuladores do Firebase; nada aqui acessa produção.
class LocalFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Plataforma não configurada para o ambiente local. '
          'Use web (Chrome), Android ou iOS.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-ipe',
    authDomain: 'demo-ipe.firebaseapp.com',
    storageBucket: 'demo-ipe.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-ipe',
    storageBucket: 'demo-ipe.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-ipe',
    storageBucket: 'demo-ipe.appspot.com',
    iosBundleId: 'com.ipe.app',
  );
}
