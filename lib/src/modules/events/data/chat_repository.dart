import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/utils/app_exception.dart';
import '../../auth/models/user.dart';
import '../models/chat_message.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  String? get _currentUserId => FirebaseConfig.auth.currentUser?.uid;

  /// Escuta mensagens em tempo real do evento
  Stream<List<ChatMessageModel>> listenMessages(String eventId) {
    return _firestore
        .collection('services')
        .doc(eventId)
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
    String eventId,
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
            .collection('services')
            .doc(eventId)
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
          .collection('services')
          .doc(eventId)
          .collection('messages')
          .add(messageData);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao enviar mensagem: ${e.toString()}');
    }
  }

  /// Deleta uma mensagem (marca como deletada)
  Future<void> deleteMessage(String eventId, String messageId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      // Verificar se o usuário é o autor ou admin
      final messageDoc = await _firestore
          .collection('services')
          .doc(eventId)
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
          .collection('services')
          .doc(eventId)
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

  /// Obtém todos os IDs de usuários vinculados ao evento
  Future<List<String>> getAllEventUserIds(String eventId) async {
    try {
      final eventDoc =
          await _firestore.collection('services').doc(eventId).get();

      if (!eventDoc.exists) {
        return [];
      }

      final eventData = eventDoc.data()!;
      final people = eventData['people'];

      if (people == null) {
        return [];
      }

      // Nova estrutura: objeto com elo, preacher, lead, soundImage, eloWithInstruments
      if (people is Map) {
        final allIds = <String>[];

        // Adicionar IDs das listas simples
        final elo = people['elo'] as List<dynamic>? ?? [];
        final preacher = people['preacher'] as List<dynamic>? ?? [];
        final lead = people['lead'] as List<dynamic>? ?? [];
        final soundImage = people['soundImage'] as List<dynamic>? ?? [];
        final diaconia = people['diaconia'] as List<dynamic>? ?? [];

        allIds.addAll(elo.map((e) => e.toString()));
        allIds.addAll(preacher.map((e) => e.toString()));
        allIds.addAll(lead.map((e) => e.toString()));
        allIds.addAll(soundImage.map((e) => e.toString()));
        allIds.addAll(diaconia.map((e) => e.toString()));

        // Adicionar IDs de eloWithInstruments
        final eloWithInstruments = people['eloWithInstruments'];
        if (eloWithInstruments is Map) {
          allIds.addAll(eloWithInstruments.keys.map((e) => e.toString()));
        }

        // Remover duplicatas
        return allIds.toSet().toList();
      }

      // Estrutura antiga: array simples
      if (people is List) {
        return people.map((e) => e.toString()).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Busca mensagens por texto
  Future<List<ChatMessageModel>> searchMessages(
    String eventId,
    String query,
  ) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final queryLower = query.toLowerCase().trim();

      final snapshot = await _firestore
          .collection('services')
          .doc(eventId)
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
    String eventId,
    String messageId,
  ) async {
    try {
      final doc = await _firestore
          .collection('services')
          .doc(eventId)
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
}
