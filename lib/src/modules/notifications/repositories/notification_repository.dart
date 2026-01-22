import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_type.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtém a lista de notificações desabilitadas do usuário
  /// Retorna lista vazia se não existir (todas habilitadas por padrão)
  Future<List<String>> getDisabledNotifications(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final disabled = data['disabled_notifications'];
        
        if (disabled != null && disabled is List) {
          return disabled.map((e) => e.toString()).toList();
        }
      }
      
      // Se não existir, retorna lista vazia (todas habilitadas)
      return [];
    } catch (e) {
      throw Exception('Erro ao buscar configurações de notificação: $e');
    }
  }

  /// Habilita uma notificação (remove do array de desabilitadas)
  Future<void> enableNotification(String userId, NotificationType type) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final disabled = (data['disabled_notifications'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        
        // Remove do array se estiver presente
        final updatedDisabled = disabled.where((id) => id != type.id).toList();
        
        await docRef.update({
          'disabled_notifications': updatedDisabled.isEmpty 
              ? FieldValue.delete() 
              : updatedDisabled,
        });
      } else {
        // Se o documento não existe, não faz nada (já está habilitado por padrão)
      }
    } catch (e) {
      throw Exception('Erro ao habilitar notificação: $e');
    }
  }

  /// Desabilita uma notificação (adiciona ao array de desabilitadas)
  Future<void> disableNotification(String userId, NotificationType type) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final disabled = (data['disabled_notifications'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        
        // Adiciona ao array se não estiver presente
        if (!disabled.contains(type.id)) {
          disabled.add(type.id);
        }
        
        await docRef.update({
          'disabled_notifications': disabled,
        });
      } else {
        // Se o documento não existe, cria com a notificação desabilitada
        await docRef.set({
          'disabled_notifications': [type.id],
        }, SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception('Erro ao desabilitar notificação: $e');
    }
  }

  /// Verifica se uma notificação está habilitada para o usuário (lógica inversa)
  Future<bool> isNotificationEnabled(String userId, String notificationId) async {
    try {
      final disabled = await getDisabledNotifications(userId);
      return !disabled.contains(notificationId);
    } catch (e) {
      // Em caso de erro, assume que está habilitado (padrão)
      return true;
    }
  }

  /// Stream das notificações desabilitadas do usuário
  Stream<List<String>> watchDisabledNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final disabled = data['disabled_notifications'];
        
        if (disabled != null && disabled is List) {
          return disabled.map((e) => e.toString()).toList();
        }
      }
      
      // Retorna lista vazia por padrão (todas habilitadas)
      return <String>[];
    });
  }
}
