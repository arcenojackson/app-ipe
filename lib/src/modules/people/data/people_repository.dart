import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_exception.dart';
import '../../auth/models/user.dart';

class PeopleRepository {
  PeopleRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  Future<List<UserModel>> fetchAll({UserModel? currentUser}) async {
    try {
      // Buscar usuários diretamente do Firestore
      final snapshot = await _firestore.collection('users').get();
      var users = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return UserModel.fromJson(data);
      }).toList();

      // Filtrar baseado no tipo de usuário
      if (currentUser != null) {
        if (currentUser.isAdminUser) {
          // Admin vê todos
          return users;
        } else if (currentUser.isStandardUser) {
          // Padrão vê apenas pessoas com is_pending = false
          return users.where((u) => !u.isPending).toList();
        } else if (currentUser.isNewUser) {
          // Novo vê apenas seu próprio nome
          return users.where((u) => u.id == currentUser.id).toList();
        }
        // Se não se encaixa em nenhum tipo conhecido, retornar lista vazia por segurança
        return const [];
      }

      // Se não há currentUser, retornar todos (para contextos administrativos/internos)
      return users;
    } catch (e) {
      // Fallback para API REST se houver erro no Firestore
      try {
        final response = await _apiClient.get('/people');
        final data = response['data'];
        if (data is! List) return const [];
        var users = data
            .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
            .toList();

        // Aplicar o mesmo filtro
        if (currentUser != null) {
          if (currentUser.isAdminUser) {
            return users;
          } else if (currentUser.isStandardUser) {
            return users.where((u) => !u.isPending).toList();
          } else if (currentUser.isNewUser) {
            return users.where((u) => u.id == currentUser.id).toList();
          }
          // Se não se encaixa em nenhum tipo conhecido, retornar lista vazia por segurança
          return const [];
        }

        // Se não há currentUser, retornar todos (para contextos administrativos/internos)
        return users;
      } catch (apiError) {
        throw AppException(
          message: 'Erro ao carregar usuários: ${e.toString()}',
        );
      }
    }
  }

  Future<void> toggleAdmin({
    required String userId,
    required bool isAdmin,
  }) async {
    try {
      // Atualizar no Firestore diretamente
      await _firestore.collection('users').doc(userId).update({
        'is_admin': isAdmin,
      });
    } catch (e) {
      // Fallback para API REST se houver erro no Firestore
      try {
        final response = await _apiClient.put(
          '/people/$userId',
          body: {'is_admin': isAdmin},
        );
        final message = response['message']?.toString();
        if (message == null) {
          throw AppException(message: 'Falha ao atualizar o usuário.');
        }
      } catch (apiError) {
        throw AppException(
          message: 'Falha ao atualizar o usuário: ${e.toString()}',
        );
      }
    }
  }

  Future<void> setTeachingRole({
    required String userId,
    required TeachingRole role,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'teaching_role': role.value,
      });
    } catch (e) {
      throw AppException(
        message: 'Falha ao atualizar o papel de ensino: ${e.toString()}',
      );
    }
  }

  Future<void> approveUser({required String userId}) async {
    try {
      // Atualizar no Firestore diretamente - aprovar usuário (remover is_pending)
      await _firestore.collection('users').doc(userId).update({
        'is_pending': false,
      });
    } catch (e) {
      // Fallback para API REST se houver erro no Firestore
      try {
        final response = await _apiClient.put(
          '/people/$userId',
          body: {'is_pending': false},
        );
        final message = response['message']?.toString();
        if (message == null) {
          throw AppException(message: 'Falha ao aprovar o usuário.');
        }
      } catch (apiError) {
        throw AppException(
          message: 'Falha ao aprovar o usuário: ${e.toString()}',
        );
      }
    }
  }

  Future<void> deleteUser({required String userId}) async {
    try {
      // Excluir do Firestore diretamente
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      // Fallback para API REST se houver erro no Firestore
      try {
        final response = await _apiClient.delete('/people/$userId');
        final message = response['message']?.toString();
        if (message == null) {
          throw AppException(message: 'Falha ao excluir o usuário.');
        }
      } catch (apiError) {
        throw AppException(
          message: 'Falha ao excluir o usuário: ${e.toString()}',
        );
      }
    }
  }
}
