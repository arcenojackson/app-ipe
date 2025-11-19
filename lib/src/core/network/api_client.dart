import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/app_exception.dart';

class ApiClient {
  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final response = await _httpClient.get(uri, headers: _defaultHeaders);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _httpClient.post(
      uri,
      body: jsonEncode(body ?? {}),
      headers: _defaultHeaders,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _httpClient.put(
      uri,
      body: jsonEncode(body ?? {}),
      headers: _defaultHeaders,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _httpClient.delete(
      uri,
      body: body == null ? null : jsonEncode(body),
      headers: _defaultHeaders,
    );
    return _handleResponse(response);
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final trimmedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(
      '${AppConfig.apiBaseUrl}/$trimmedPath',
    ).replace(queryParameters: query);
  }

  Map<String, String> get _defaultHeaders => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final message = decoded['message']?.toString() ?? 'Erro de comunicação.';
    throw AppException(message: message, statusCode: response.statusCode);
  }
}
