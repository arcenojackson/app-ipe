import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_exception.dart';
import '../../auth/models/user.dart';

class PeopleRepository {
  PeopleRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  Future<List<UserModel>> fetchAll() async {
    try {
      // Buscar usuários diretamente do Firestore
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return UserModel.fromJson(data);
      }).toList();
    } catch (e) {
      // Fallback para API REST se houver erro no Firestore
      try {
        final response = await _apiClient.get('/people');
        final data = response['data'];
        if (data is! List) return const [];
        return data
            .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
            .toList();
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
}
