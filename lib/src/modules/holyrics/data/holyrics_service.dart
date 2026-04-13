import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ipe_flutter/src/modules/holyrics/data/holyrics_config.dart';

class HolyricsService {
  final http.Client _httpClient;
  HolyricsConfig? _config;

  HolyricsService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Future<void> _loadConfig() async {
    if (_config != null) return;
    _config = await HolyricsConfig.loadConfig();
  }

  String? _getBaseUrl() {
    if (_config == null) return null;
    return 'http://${_config!.ip}:${_config!.port}/api';
  }

  String? getBaseUrl() => _getBaseUrl();

  Future<bool> isConfigured() async {
    await _loadConfig();
    return _config != null && _config!.isValid();
  }

  Future<bool> testConnection() async {
    try {
      await _loadConfig();
      final baseUrl = _getBaseUrl();
      if (baseUrl == null) return false;
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/GetTokenInfo?token=${_config!.token}'),
            headers: {'Content-Type': 'application/json'},
            body: '{}',
          )
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Helper interno para chamadas à API
  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _loadConfig();
    final baseUrl = _getBaseUrl();
    if (baseUrl == null) throw Exception('Holyrics não configurado');
    if (!_config!.isValid()) throw Exception('Configuração do Holyrics inválida');
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/$action?token=${_config!.token}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Falha em $action: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Busca uma música pelo título no banco do Holyrics.
  // Retorna o ID da primeira correspondência, ou null se não encontrada.
  Future<String?> searchSong(String title) async {
    try {
      final result = await _post('SearchLyrics', {
        'text': title,
        'title': true,
      });
      final data = result['data'];
      if (data is! List || data.isEmpty) return null;
      return (data.first as Map<String, dynamic>)['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  // Cria uma nova música no banco do Holyrics e retorna o ID criado.
  // Requer Holyrics Plan e permissão avançada habilitada em:
  //   Arquivo > Configurações > Avançado > JavaScript > Permissões avançadas
  // Lança Exception se o Holyrics retornar erro.
  Future<String> createSong({
    required String title,
    required String artist,
    String? lyrics,
    String? tone,
    bool minorTone = false,
    String? bpm,
  }) async {
    final slides = _lyricsToSlides(lyrics);
    final key = tone != null && tone.isNotEmpty
        ? (minorTone ? '${tone}m' : tone)
        : '';
    final body = <String, dynamic>{
      'title': title,
      'artist': artist,
      if (key.isNotEmpty) 'key': key,
      if (bpm != null && double.tryParse(bpm) != null)
        'bpm': double.parse(bpm),
      if (slides.isNotEmpty) 'slides': slides,
    };
    final result = await _post('CreateSong', body, timeout: const Duration(seconds: 15));
    if (result['status'] != 'ok') {
      final error = result['error']?.toString() ?? 'resposta inesperada';
      throw Exception('Holyrics recusou a criação: $error');
    }
    final data = result['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Holyrics não retornou dados da música criada');
    }
    final id = data['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Holyrics retornou ID vazio para a música criada');
    }
    return id;
  }

  List<Map<String, dynamic>> _lyricsToSlides(String? lyrics) {
    if (lyrics == null || lyrics.trim().isEmpty) return [];
    // Divide a letra em estrofes separadas por linha em branco
    return lyrics
        .split(RegExp(r'\n\s*\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => {'text': s})
        .toList();
  }

  // Projeta uma música imediatamente na tela (uso ao vivo).
  // Busca pelo título no Holyrics e projeta pelo ID encontrado.
  Future<void> showSong(String songTitle) async {
    final id = await searchSong(songTitle);
    if (id == null) {
      throw Exception('Música "$songTitle" não encontrada no Holyrics');
    }
    await _post('ShowLyrics', {'id': id});
  }

  // Projeta um versículo bíblico imediatamente na tela (uso ao vivo).
  // references: formato brasileiro, ex: "Sl 23.1", "Jo 3:16-18", "Rm 12:2"
  Future<void> showVerse(String references) async {
    await _post('ShowVerse', {'references': references});
  }

  // Projeta um texto imediatamente na tela (uso ao vivo).
  Future<void> showText(String text) async {
    await _post('ShowText', {'text': text});
  }

  // Adiciona uma lista de itens à playlist de mídia do Holyrics.
  // Tipos suportados nos itens:
  //   {"type": "title",      "name": "Culto Domingo"}
  //   {"type": "song",       "id": "abc123"}
  //   {"type": "verse",      "references": "Sl 23.1"}
  //   {"type": "plain_text", "name": "Título", "text": "..."}
  Future<void> addToPlaylist(List<Map<String, dynamic>> items) async {
    await _post(
      'AddToPlaylist',
      {'items': items, 'index': -1},
      timeout: const Duration(seconds: 30),
    );
  }

  // Avança para o próximo slide no Holyrics
  Future<void> actionNext() async {
    await _post('ActionNext', {}, timeout: const Duration(seconds: 5));
  }

  // Volta para o slide anterior no Holyrics
  Future<void> actionPrevious() async {
    await _post('ActionPrevious', {}, timeout: const Duration(seconds: 5));
  }

  void clearConfig() {
    _config = null;
  }

  Future<void> close() async {
    _httpClient.close();
  }
}
