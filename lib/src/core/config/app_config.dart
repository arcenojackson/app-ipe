import 'app_secrets.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'IPE';

  /// URL base para o backend em Node.js (a ser implementado).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3333',
  );

  /// API Key do YouTube Data API v3
  ///
  /// Prioridade de busca:
  /// 1. Variável de ambiente YOUTUBE_API_KEY (para desenvolvimento)
  /// 2. AppSecrets.youtubeApiKey (arquivo local não commitado)
  ///
  /// Para produção, configure a chave em app_secrets.dart
  /// (copie app_secrets.dart.example para app_secrets.dart e preencha)
  static const String youtubeApiKey = String.fromEnvironment(
    'YOUTUBE_API_KEY',
    defaultValue: AppSecrets.youtubeApiKey,
  );
}
