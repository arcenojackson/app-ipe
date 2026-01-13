import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_exception.dart';
import '../models/category.dart';
import '../models/music.dart';
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
    final response = await _apiClient.get(
      '/musics/search/youtube',
      queryParameters: {'q': query},
    );
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .map(
          (item) => YoutubeSearchResult.fromJson(item as Map<String, dynamic>),
        )
        .toList();
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
}
