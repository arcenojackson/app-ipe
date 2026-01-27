import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/utils/app_exception.dart';
import '../models/society.dart';

class SocietiesRepository {
  SocietiesRepository();

  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  String? get _currentUserId => FirebaseConfig.auth.currentUser?.uid;

  /// Busca todas as sociedades do Firestore
  Future<List<SocietyModel>> fetchAll() async {
    try {
      final snapshot = await _firestore.collection('societies').get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return SocietyModel.fromJson(data);
      }).toList();
    } catch (e) {
      throw AppException(
        message: 'Erro ao carregar sociedades: ${e.toString()}',
      );
    }
  }

  /// Busca uma sociedade por ID
  Future<SocietyModel> fetchById(String id) async {
    try {
      final doc = await _firestore.collection('societies').doc(id).get();
      if (!doc.exists) {
        throw AppException(message: 'Sociedade não encontrada.');
      }
      final data = doc.data()!;
      data['id'] = doc.id;
      return SocietyModel.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao buscar sociedade: ${e.toString()}',
      );
    }
  }

  /// Busca uma sociedade por nome
  Future<SocietyModel?> fetchByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection('societies')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return SocietyModel.fromJson(data);
    } catch (e) {
      throw AppException(
        message: 'Erro ao buscar sociedade por nome: ${e.toString()}',
      );
    }
  }

  /// Cria uma nova sociedade
  Future<SocietyModel> createSociety({
    required String name,
    required String description,
    required int color,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      final docRef = await _firestore.collection('societies').add({
        'name': name,
        'description': description,
        'color': color,
        'userId': userId,
        'members': [],
        'board': [],
      });

      return await fetchById(docRef.id);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao criar sociedade: ${e.toString()}',
      );
    }
  }

  /// Atualiza uma sociedade existente
  Future<SocietyModel> updateSociety({
    required String id,
    String? name,
    String? description,
    int? color,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (color != null) updates['color'] = color;

      if (updates.isEmpty) {
        return await fetchById(id);
      }

      await _firestore.collection('societies').doc(id).update(updates);
      return await fetchById(id);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao atualizar sociedade: ${e.toString()}',
      );
    }
  }

  /// Exclui uma sociedade
  Future<void> deleteSociety(String id) async {
    try {
      await _firestore.collection('societies').doc(id).delete();
    } catch (e) {
      throw AppException(
        message: 'Erro ao excluir sociedade: ${e.toString()}',
      );
    }
  }

  /// Atualiza os membros de uma sociedade
  Future<void> updateMembers({
    required String id,
    required List<String> membersIds,
  }) async {
    try {
      await _firestore.collection('societies').doc(id).update({
        'members': membersIds,
      });
    } catch (e) {
      throw AppException(
        message: 'Erro ao atualizar membros: ${e.toString()}',
      );
    }
  }

  /// Atualiza a diretoria de uma sociedade
  Future<void> updateBoard({
    required String id,
    required List<String> boardIds,
  }) async {
    try {
      await _firestore.collection('societies').doc(id).update({
        'board': boardIds,
      });
    } catch (e) {
      throw AppException(
        message: 'Erro ao atualizar diretoria: ${e.toString()}',
      );
    }
  }

  /// Atualiza a diretoria de uma sociedade com cargos
  Future<void> updateBoardWithPositions({
    required String id,
    required Map<String, List<String>> boardWithPositions,
  }) async {
    try {
      await _firestore.collection('societies').doc(id).update({
        'board': boardWithPositions,
      });
    } catch (e) {
      throw AppException(
        message: 'Erro ao atualizar diretoria: ${e.toString()}',
      );
    }
  }

  /// Atualizar usuários do Fórum por categoria
  Future<void> updateForumUsersByCategory({
    required String id,
    required Map<String, List<String>> forumUsersByCategory,
  }) async {
    try {
      await _firestore.collection('societies').doc(id).update({
        'forumUsersByCategory': forumUsersByCategory,
      });
    } catch (e) {
      throw AppException(
        message: 'Erro ao atualizar usuários do Fórum: ${e.toString()}',
      );
    }
  }

  /// Buscar usuários do Fórum por categoria
  Future<Map<String, List<String>>> getForumUsersByCategory(String id) async {
    try {
      final doc = await _firestore.collection('societies').doc(id).get();
      if (!doc.exists) {
        return {};
      }
      final data = doc.data()!;
      final forumUsersData = data['forumUsersByCategory'];
      if (forumUsersData == null || forumUsersData is! Map) {
        return {};
      }
      final result = <String, List<String>>{};
      forumUsersData.forEach((key, value) {
        if (value is List) {
          result[key.toString()] = value.map((e) => e.toString()).toList();
        }
      });
      return result;
    } catch (e) {
      throw AppException(
        message: 'Erro ao buscar usuários do Fórum: ${e.toString()}',
      );
    }
  }
}

