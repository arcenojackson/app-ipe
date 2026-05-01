import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/config/firebase_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_exception.dart';
import '../models/category.dart';
import '../models/music.dart';
import '../models/music_status.dart';
import '../models/youtube_search_result.dart';

class MusicsRepository {
  MusicsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  Future<List<MusicModel>> fetchAll() async {
    try {
      final snapshot = await _firestore.collection('musics').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return MusicModel.fromJson(data);
      }).toList();
    } catch (e) {
      // Fallback para API REST se houver erro no Firestore
      try {
        final response = await _apiClient.get('/musics');
        final data = response['data'];
        if (data is! List) return const [];
        return data
            .map((item) => MusicModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (apiError) {
        throw AppException(message: 'Erro ao carregar músicas: ${e.toString()}');
      }
    }
  }

  Future<MusicModel> fetchById(String id) async {
    try {
      final doc = await _firestore.collection('musics').doc(id).get();
      if (!doc.exists) {
        throw AppException(message: 'Música não encontrada.');
      }
      final data = doc.data()!;
      data['id'] = doc.id;
      return MusicModel.fromJson(data);
    } catch (e) {
      // Fallback para API REST se houver erro no Firestore
      try {
        final response = await _apiClient.get('/musics/$id');
        final data = response['data'];
        if (data is! Map<String, dynamic>) {
          throw AppException(message: 'Música não encontrada.');
        }
        data['id'] = id;
        return MusicModel.fromJson(data);
      } catch (apiError) {
        throw AppException(message: 'Erro ao buscar música: ${e.toString()}');
      }
    }
  }

  Future<List<CategoryModel>> fetchCategories() async {
    final response = await _apiClient.get('/categories');
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<YoutubeSearchResult>> searchYoutube(String query) async {
    try {
      // Buscar diretamente na API do YouTube Data v3
      final apiKey = AppConfig.youtubeApiKey;
      if (apiKey.isEmpty) {
        throw AppException(
          message: 'API Key do YouTube não configurada. Configure YOUTUBE_API_KEY no app_config.dart ou como variável de ambiente.',
        );
      }

      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search'
        '?part=snippet'
        '&type=video'
        '&maxResults=10'
        '&q=$encodedQuery'
        '&key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['error']?['message']?.toString() ??
            'Erro ao buscar no YouTube';
        throw AppException(message: errorMessage);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];

      return items.map((item) {
        final itemData = item as Map<String, dynamic>;
        final id = itemData['id'] as Map<String, dynamic>?;
        final snippet = itemData['snippet'] as Map<String, dynamic>?;
        final thumbnails = snippet?['thumbnails'] as Map<String, dynamic>?;
        final defaultThumbnail = thumbnails?['default'] as Map<String, dynamic>?;

        return YoutubeSearchResult(
          id: id?['videoId']?.toString() ?? '',
          title: snippet?['title']?.toString() ?? '',
          thumbnail: defaultThumbnail?['url']?.toString() ?? '',
        );
      }).toList();
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
        message: 'Erro ao buscar no YouTube: ${e.toString()}',
      );
    }
  }

  /// Returns the existing music that conflicts, along with which field matched.
  /// [excludeId] is used on updates to ignore the music being edited.
  Future<({MusicModel music, String field})?> findDuplicate({
    required String title,
    String? youtube,
    required String cipher,
    String? excludeId,
  }) async {
    final all = await fetchAll();
    final normTitle = title.trim().toLowerCase();
    final normYoutube = (youtube?.trim().isNotEmpty == true) ? youtube!.trim() : null;
    final normCipher = cipher.trim();

    for (final existing in all) {
      if (excludeId != null && existing.id == excludeId) continue;

      if (existing.title.trim().toLowerCase() == normTitle) {
        return (music: existing, field: 'título');
      }
      if (normYoutube != null &&
          existing.youtube?.trim().isNotEmpty == true &&
          existing.youtube!.trim() == normYoutube) {
        return (music: existing, field: 'URL do YouTube');
      }
      if (normCipher.isNotEmpty &&
          existing.cipher.trim().isNotEmpty &&
          existing.cipher.trim() == normCipher) {
        return (music: existing, field: 'link da cifra');
      }
    }
    return null;
  }

  Future<MusicModel> create(MusicModel music) async {
    try {
      final musicData = Map<String, dynamic>.from(music.toJson());
      // Remove o ID do JSON antes de salvar (o Firestore gerencia o ID)
      musicData.remove('id');
      
      DocumentReference docRef;
      if (music.id.isNotEmpty) {
        // Se tem ID, usa ele
        docRef = _firestore.collection('musics').doc(music.id);
        await docRef.set(musicData);
      } else {
        // Se não tem ID, deixa o Firestore gerar
        docRef = _firestore.collection('musics').doc();
        await docRef.set(musicData);
      }
      
      // Busca o documento criado para retornar com todos os dados
      final createdDoc = await docRef.get();
      final createdData = Map<String, dynamic>.from(createdDoc.data() as Map);
      createdData['id'] = docRef.id;
      return MusicModel.fromJson(createdData);
    } catch (e) {
      // Fallback para API REST se houver erro no Firestore
      try {
        final response = await _apiClient.post('/musics', body: music.toJson());
        final data = response['data'];
        if (data is! Map<String, dynamic>) {
          throw AppException(message: 'Falha ao criar música.');
        }
        return MusicModel.fromJson(data);
      } catch (apiError) {
        throw AppException(message: 'Erro ao criar música: ${e.toString()}');
      }
    }
  }

  Future<MusicModel> update(MusicModel music) async {
    try {
      final musicData = Map<String, dynamic>.from(music.toJson());
      musicData.remove('id'); // Remove o ID do JSON antes de atualizar
      
      await _firestore.collection('musics').doc(music.id).update(musicData);
      
      // Busca o documento atualizado para retornar com todos os dados
      final updatedDoc = await _firestore.collection('musics').doc(music.id).get();
      final updatedData = Map<String, dynamic>.from(updatedDoc.data() as Map);
      updatedData['id'] = music.id;
      return MusicModel.fromJson(updatedData);
    } catch (e) {
      // Fallback para API REST se houver erro no Firestore
      try {
        final response = await _apiClient.put(
          '/musics/${music.id}',
          body: music.toJson(),
        );
        final data = response['data'];
        if (data is! Map<String, dynamic>) {
          throw AppException(message: 'Falha ao atualizar música.');
        }
        return MusicModel.fromJson(data);
      } catch (apiError) {
        throw AppException(message: 'Erro ao atualizar música: ${e.toString()}');
      }
    }
  }

  Future<void> delete(String id) async {
    try {
      await _firestore.collection('musics').doc(id).delete();
    } catch (e) {
      // Fallback para API REST se houver erro no Firestore
      try {
        await _apiClient.delete('/musics/$id');
      } catch (apiError) {
        throw AppException(message: 'Erro ao excluir música: ${e.toString()}');
      }
    }
  }

  Future<void> addEventDate(String musicId, DateTime date) async {
    try {
      final music = await fetchById(musicId);
      final dateStr = date.toIso8601String();
      if (!music.selectedTimes.contains(dateStr)) {
        final newTimes = List<String>.from(music.selectedTimes)..add(dateStr);
        await update(music.copyWith(selectedTimes: newTimes));
      }
    } catch (e) {
      throw AppException(message: 'Erro ao adicionar data à música: $e');
    }
  }

  Future<void> removeEventDate(String musicId, DateTime date) async {
    try {
      final music = await fetchById(musicId);
      final dateStr = date.toIso8601String();
      if (music.selectedTimes.contains(dateStr)) {
        final newTimes = List<String>.from(music.selectedTimes)..remove(dateStr);
        await update(music.copyWith(selectedTimes: newTimes));
      }
    } catch (e) {
      throw AppException(message: 'Erro ao remover data da música: $e');
    }
  }

  Future<void> sendToEvaluation(String musicId) async {
    try {
      await _firestore.collection('musics').doc(musicId).update({
        'status': MusicStatus.emAvaliacao.value,
      });
    } catch (e) {
      throw AppException(message: 'Erro ao enviar música para avaliação: $e');
    }
  }

  Future<void> setFinalStatus(String musicId, MusicStatus status) async {
    try {
      await _firestore.collection('musics').doc(musicId).update({
        'status': status.value,
      });
    } catch (e) {
      throw AppException(message: 'Erro ao definir status final: $e');
    }
  }
}
