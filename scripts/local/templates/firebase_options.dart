// ARQUIVO LOCAL GERADO por `npm run setup` — configuração de DEMONSTRAÇÃO.
// Serve só para o projeto compilar sem credenciais. Com
// `--dart-define=USE_EMULATOR=true` (o `npm run app` já faz isso) o app usa
// LocalFirebaseOptions e conecta apenas nos emuladores; sem a flag, este stub
// recusa iniciar. Para a config real de produção (somente mantenedores):
// `flutterfire configure`.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:ipe_flutter/src/core/config/local_firebase_options.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      LocalFirebaseOptions.currentPlatform;
}
