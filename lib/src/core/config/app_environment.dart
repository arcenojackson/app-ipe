import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Ambiente em que o app roda.
///
/// Por padrão é produção. Com `--dart-define=USE_EMULATOR=true` o app conecta
/// somente nos emuladores locais do Firebase (projeto `demo-ipe`) e desliga
/// o que não existe localmente (Analytics, Crashlytics, FCM e login
/// Google/Apple). Veja docs/DESENVOLVIMENTO_LOCAL.md.
class AppEnvironment {
  AppEnvironment._();

  static const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');

  /// Host dos emuladores. Padrão: `10.0.2.2` no emulador Android (alias da
  /// máquina host) e `127.0.0.1` nas demais plataformas. Em celular físico,
  /// informe o IP da máquina com `--dart-define=EMULATOR_HOST=192.168.x.x`.
  static const String _hostOverride = String.fromEnvironment('EMULATOR_HOST');

  static String get emulatorHost {
    if (_hostOverride.isNotEmpty) return _hostOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  static const int authEmulatorPort = 9099;
  static const int firestoreEmulatorPort = 8080;
  static const int functionsEmulatorPort = 5001;
  static const String localProjectId = 'demo-ipe';
  static const String _prodProjectId = 'app-ipe';
  static const String _region = 'us-central1';

  /// URL de uma Cloud Function HTTP (`onRequest`): emulador ou produção.
  static String cloudFunctionUrl(String name) {
    if (useEmulator) {
      return 'http://$emulatorHost:$functionsEmulatorPort/'
          '$localProjectId/$_region/$name';
    }
    return 'https://$_region-$_prodProjectId.cloudfunctions.net/$name';
  }
}
