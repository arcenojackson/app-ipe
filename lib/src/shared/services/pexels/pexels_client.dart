import 'package:dio/dio.dart';

import 'pexels_models.dart';

/// Chave da API Pexels. Definir via --dart-define=PEXELS_API_KEY=sua_chave
/// ou no ambiente (ex: PEXELS_API_KEY).
const String _kPexelsApiKey = String.fromEnvironment(
  'PEXELS_API_KEY',
  defaultValue: '',
);

/// Client HTTP para a API Pexels (busca de fotos).
class PexelsClient {
  PexelsClient({String? apiKey}) : _apiKey = apiKey ?? _kPexelsApiKey {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.pexels.com',
      headers: {
        'Authorization': _apiKey,
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  final String _apiKey;
  late final Dio _dio;

  bool get hasApiKey => _apiKey.isNotEmpty;

  /// Busca fotos. [query] = termos (ex: "abstract gradient").
  /// [orientation] = portrait (padrão para arte vertical).
  /// Cancela a request anterior se [cancelToken] for o mesmo entre chamadas.
  Future<PexelsSearchResponse> search({
    required String query,
    String orientation = 'portrait',
    int perPage = 30,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    if (!hasApiKey) {
      throw PexelsException('PEXELS_API_KEY não configurada. Use --dart-define=PEXELS_API_KEY=sua_chave');
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/search',
        queryParameters: {
          'query': query.isEmpty ? 'abstract' : query,
          'orientation': orientation,
          'per_page': perPage.clamp(1, 80),
          'page': page,
        },
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.json),
      );
      final data = response.data;
      if (data == null) return const PexelsSearchResponse();
      return PexelsSearchResponse.fromJson(data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw PexelsCancelException();
      }
      final status = e.response?.statusCode;
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['error']?.toString()
          : null;
      throw PexelsException(msg ?? 'Erro Pexels: ${e.message} (${status ?? "?"})');
    }
  }
}

class PexelsException implements Exception {
  PexelsException(this.message);
  final String message;
  @override
  String toString() => 'PexelsException: $message';
}

class PexelsCancelException implements Exception {}
