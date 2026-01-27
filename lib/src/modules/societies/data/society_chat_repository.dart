import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/utils/app_exception.dart';
import '../../auth/models/user.dart';
import '../../events/models/chat_message.dart';

class SocietyChatRepository {
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  String? get _currentUserId => FirebaseConfig.auth.currentUser?.uid;

  /// Escuta mensagens em tempo real da sociedade
  Stream<List<ChatMessageModel>> listenMessages(String societyId) {
    return _firestore
        .collection('societies')
        .doc(societyId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ChatMessageModel.fromJson(data);
      }).toList();
    });
  }

  /// Envia uma nova mensagem
  Future<void> sendMessage(
    String societyId,
    String text,
    List<String> mentionedUserIds, {
    String? quotedMessageId,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      if (text.trim().isEmpty) {
        throw AppException(message: 'Mensagem não pode estar vazia.');
      }

      // Buscar nome do usuário
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userName = userDoc.data()?['name']?.toString() ??
          userDoc.data()?['email']?.toString() ??
          'Usuário';

      // Buscar dados da mensagem citada se houver
      Map<String, dynamic>? quotedData;
      if (quotedMessageId != null && quotedMessageId.isNotEmpty) {
        final quotedDoc = await _firestore
            .collection('societies')
            .doc(societyId)
            .collection('messages')
            .doc(quotedMessageId)
            .get();

        if (quotedDoc.exists) {
          final quotedMsgData = quotedDoc.data()!;
          quotedData = {
            'quotedMessageId': quotedDoc.id,
            'quotedMessageText': quotedMsgData['text']?.toString() ?? '',
            'quotedMessageUserName': quotedMsgData['userName']?.toString() ?? '',
          };
        }
      }

      final messageData = {
        'text': text.trim(),
        'userId': userId,
        'userName': userName,
        'timestamp': Timestamp.now(),
        'mentionedUserIds': mentionedUserIds,
        'isDeleted': false,
        if (quotedData != null) ...quotedData,
      };

      await _firestore
          .collection('societies')
          .doc(societyId)
          .collection('messages')
          .add(messageData);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao enviar mensagem: ${e.toString()}');
    }
  }

  /// Deleta uma mensagem (marca como deletada)
  Future<void> deleteMessage(String societyId, String messageId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      // Verificar se o usuário é o autor ou admin
      final messageDoc = await _firestore
          .collection('societies')
          .doc(societyId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw AppException(message: 'Mensagem não encontrada.');
      }

      final messageData = messageDoc.data()!;
      final messageUserId = messageData['userId']?.toString();

      // Verificar se é admin
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final isAdmin = userDoc.data()?['is_admin'] == true ||
          userDoc.data()?['isAdmin'] == true;

      if (messageUserId != userId && !isAdmin) {
        throw AppException(
          message: 'Você não tem permissão para deletar esta mensagem.',
        );
      }

      // Marcar como deletada (não deletar fisicamente para manter histórico)
      await _firestore
          .collection('societies')
          .doc(societyId)
          .collection('messages')
          .doc(messageId)
          .update({'isDeleted': true});
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao deletar mensagem: ${e.toString()}');
    }
  }

  // Normaliza string removendo acentos para comparação
  String _normalize(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n');
  }

  /// Extrai menções do texto (@usuário ou @todos)
  Future<List<String>> extractMentions(
    String text,
    List<UserModel> availableUsers,
  ) async {
    final mentionedIds = <String>[];

    // Verificar @todos
    final todosRegex = RegExp(r'@todos\b', caseSensitive: false);
    if (todosRegex.hasMatch(text)) {
      // Retornar todos os IDs dos usuários disponíveis
      return availableUsers.map((u) => u.id).toList();
    }

    // Extrair menções individuais @nomeUsuario
    // Regex melhorado que captura até encontrar espaço ou fim da string
    final mentionRegex = RegExp(r'@([^\s@]+)', caseSensitive: false);
    final matches = mentionRegex.allMatches(text);

    for (final match in matches) {
      final mentionedNameRaw = match.group(1) ?? '';
      final mentionedNameNormalized = _normalize(mentionedNameRaw);

      // Tentar encontrar usuário que corresponde
      UserModel? matchedUser;

      for (final user in availableUsers) {
        final userNameNormalized = _normalize(user.name);

        // Comparar se o nome mencionado está no início do nome do usuário
        // ou se o nome completo do usuário está no texto mencionado
        if (userNameNormalized == mentionedNameNormalized ||
            userNameNormalized.startsWith(mentionedNameNormalized) ||
            mentionedNameNormalized == _normalize(user.name.split(' ').first)) {
          matchedUser = user;
          break;
        }
      }

      if (matchedUser != null && matchedUser.id.isNotEmpty && !mentionedIds.contains(matchedUser.id)) {
        mentionedIds.add(matchedUser.id);
      }
    }

    return mentionedIds;
  }

  /// Busca mensagens por texto
  Future<List<ChatMessageModel>> searchMessages(
    String societyId,
    String query,
  ) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final queryLower = query.toLowerCase().trim();

      final snapshot = await _firestore
          .collection('societies')
          .doc(societyId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      final allMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ChatMessageModel.fromJson(data);
      }).toList();

      // Filtrar mensagens que contêm o texto de busca
      return allMessages.where((message) {
        if (message.isDeleted) return false;
        final textLower = message.text.toLowerCase();
        final userNameLower = message.userName.toLowerCase();
        return textLower.contains(queryLower) ||
            userNameLower.contains(queryLower);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtém uma mensagem específica por ID (útil para citações)
  Future<ChatMessageModel?> getMessageById(
    String societyId,
    String messageId,
  ) async {
    try {
      final doc = await _firestore
          .collection('societies')
          .doc(societyId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      return ChatMessageModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Marca mensagens como visualizadas pelo usuário atual
  Future<void> markMessagesAsViewed(
    String societyId,
    List<String> messageIds,
  ) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final batch = _firestore.batch();
      
      for (final messageId in messageIds) {
        final messageRef = _firestore
            .collection('societies')
            .doc(societyId)
            .collection('messages')
            .doc(messageId);
        
        // Usar FieldValue.arrayUnion para adicionar o userId sem duplicatas
        batch.update(messageRef, {
          'viewedBy': FieldValue.arrayUnion([userId]),
        });
      }
      
      await batch.commit();
    } catch (e) {
      // Ignorar erros silenciosamente
    }
  }

  /// Marca todas as mensagens visíveis como visualizadas
  Future<void> markAllMessagesAsViewed(String societyId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      // Buscar todas as mensagens não deletadas
      final snapshot = await _firestore
          .collection('societies')
          .doc(societyId)
          .collection('messages')
          .where('isDeleted', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        final viewedBy = (doc.data()['viewedBy'] as List<dynamic>?) ?? [];
        if (!viewedBy.contains(userId)) {
          batch.update(doc.reference, {
            'viewedBy': FieldValue.arrayUnion([userId]),
          });
        }
      }
      
      await batch.commit();
    } catch (e) {
      // Ignorar erros silenciosamente
    }
  }

  /// Obtém a última mensagem lida pelo usuário na sociedade
  Future<String?> getLastReadMessageId(String societyId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return null;

      final userReadDoc = await _firestore
          .collection('societies')
          .doc(societyId)
          .collection('user_reads')
          .doc(userId)
          .get();

      if (!userReadDoc.exists) return null;
      
      return userReadDoc.data()?['lastMessageId']?.toString();
    } catch (e) {
      return null;
    }
  }

  /// Salva a última mensagem lida pelo usuário na sociedade
  Future<void> setLastReadMessageId(String societyId, String messageId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      await _firestore
          .collection('societies')
          .doc(societyId)
          .collection('user_reads')
          .doc(userId)
          .set({
        'lastMessageId': messageId,
        'lastReadAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Ignorar erros silenciosamente
    }
  }

  /// Conta mensagens não lidas para o usuário atual na sociedade
  Stream<int> getUnreadMessageCount(String societyId) {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('societies')
        .doc(societyId)
        .collection('messages')
        .where('isDeleted', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((messagesSnapshot) async {
      if (messagesSnapshot.docs.isEmpty) {
        return 0;
      }

      // Buscar última mensagem lida
      final lastReadDoc = await _firestore
          .collection('societies')
          .doc(societyId)
          .collection('user_reads')
          .doc(userId)
          .get();

      final lastReadMessageId = lastReadDoc.data()?['lastMessageId']?.toString();
      
      if (lastReadMessageId == null) {
        // Se nunca leu, todas as mensagens são não lidas
        return messagesSnapshot.docs.length;
      }

      // Encontrar índice da última mensagem lida (ordenado por timestamp descendente)
      int lastReadIndex = -1;
      for (int i = 0; i < messagesSnapshot.docs.length; i++) {
        if (messagesSnapshot.docs[i].id == lastReadMessageId) {
          lastReadIndex = i;
          break;
        }
      }

      // Se não encontrou a mensagem lida, todas são não lidas
      if (lastReadIndex == -1) {
        return messagesSnapshot.docs.length;
      }

      // Como está ordenado descendente, o índice representa quantas mensagens
      // são mais recentes (não lidas) que a última lida
      return lastReadIndex;
    });
  }
}
