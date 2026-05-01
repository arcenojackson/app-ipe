import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/utils/app_exception.dart';
import '../../auth/models/user.dart';
import '../../musics/models/music.dart';
import '../../musics/models/music_status.dart';
import '../../societies/data/societies_repository.dart';
import '../models/evaluation_category.dart';
import '../models/evaluation_form.dart';
import '../models/evaluation_response.dart';
import '../models/music_with_evaluations.dart';

class MusicEvaluationsRepository {
  MusicEvaluationsRepository({required SocietiesRepository societiesRepository})
    : _societiesRepository = societiesRepository;

  final SocietiesRepository _societiesRepository;
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  String? get _currentUserId => FirebaseConfig.auth.currentUser?.uid;

  /// Verificar se usuário está na diretoria da ELO
  Future<bool> isELOBoardMember(UserModel user) async {
    if (user.isAdminUser) return true;

    final eloSociety = await _societiesRepository.fetchByName('ELO');
    if (eloSociety == null) return false;

    return eloSociety.allBoardIds.contains(user.id);
  }

  /// Verificar se usuário pode acessar formulários (está no Fórum em alguma categoria)
  Future<bool> canAccessEvaluations(UserModel user) async {
    if (user.isAdminUser) return true;

    final eloSociety = await _societiesRepository.fetchByName('ELO');
    if (eloSociety == null) return false;

    // Diretoria sempre pode acessar
    if (eloSociety.allBoardIds.contains(user.id)) return true;

    // Verificar se está em alguma categoria
    final forumUsers = eloSociety.forumUsersByCategory ?? {};
    return forumUsers.values.any((userIds) => userIds.contains(user.id));
  }

  /// Verificar se usuário pode acessar categoria específica
  Future<bool> canAccessCategory(
    UserModel user,
    EvaluationCategory category,
  ) async {
    final eloSociety = await _societiesRepository.fetchByName('ELO');
    if (eloSociety == null) {
      return false;
    }

    // Diretoria ELO sempre pode acessar todas as categorias
    final isBoardMember = eloSociety.allBoardIds.contains(user.id);
    if (isBoardMember) {
      return true;
    }

    // Para todos os outros usuários (incluindo admins), verificar se estão vinculados à categoria
    final forumUsersByCategory = eloSociety.forumUsersByCategory;
    final categoryUsers = forumUsersByCategory?[category.name] ?? [];
    return categoryUsers.contains(user.id);
  }

  /// Verificar se pode criar formulário em uma categoria
  Future<bool> canCreateEvaluationInCategory(
    UserModel user,
    EvaluationCategory category,
  ) async {
    return await canAccessCategory(user, category);
  }

  /// Verificar se pode acessar formulário específico
  Future<bool> canAccessForm(String formId, String userId) async {
    final form = await fetchFormById(formId);
    return form.allowedUserIds.contains(userId);
  }

  /// Verificar se pode visualizar respostas (apenas diretoria ELO)
  Future<bool> canViewResponses(UserModel user) async {
    final eloSociety = await _societiesRepository.fetchByName('ELO');
    if (eloSociety == null) return false;

    // Apenas membros da diretoria ELO podem visualizar respostas
    return eloSociety.allBoardIds.contains(user.id);
  }

  /// Buscar formulários acessíveis ao usuário
  Future<List<EvaluationFormModel>> fetchAllForms(String userId) async {
    try {
      final user = await _getUserModel(userId);
      if (user == null) return [];

      final eloSociety = await _societiesRepository.fetchByName('ELO');
      if (eloSociety == null) return [];

      final forumUsers = eloSociety.forumUsersByCategory ?? {};
      final isBoardMember = eloSociety.allBoardIds.contains(userId);

      // Se for diretoria, buscar todos os formulários
      if (isBoardMember || user.isAdminUser) {
        final snapshot = await _firestore
            .collection('music_evaluation_forms')
            .orderBy('createdAt', descending: true)
            .get();

        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return EvaluationFormModel.fromJson(data);
        }).toList();
      }

      // Caso contrário, buscar apenas formulários das categorias permitidas
      final allowedCategories = <String>[];
      forumUsers.forEach((categoryName, userIds) {
        if (userIds.contains(userId)) {
          allowedCategories.add(categoryName);
        }
      });

      if (allowedCategories.isEmpty) return [];

      final snapshot = await _firestore
          .collection('music_evaluation_forms')
          .where('category', whereIn: allowedCategories)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return EvaluationFormModel.fromJson(data);
      }).toList();
    } catch (e) {
      // Exibir erro completo no console para facilitar cópia do link do índice
      print('❌ Erro ao carregar formulários (fetchFormsByCategory):');
      print(e.toString());
      print('');

      throw AppException(
        message: 'Erro ao carregar formulários: ${e.toString()}',
      );
    }
  }

  /// Buscar formulários de uma categoria específica
  Future<List<EvaluationFormModel>> fetchFormsByCategory(
    String userId,
    EvaluationCategory category,
  ) async {
    try {
      final user = await _getUserModel(userId);
      if (user == null) return [];

      // Verificar se pode acessar a categoria
      final canAccess = await canAccessCategory(user, category);
      if (!canAccess) {
        // Se não pode acessar a categoria, retornar lista vazia
        return [];
      }

      final eloSociety = await _societiesRepository.fetchByName('ELO');
      if (eloSociety == null) return [];

      final isBoardMember = eloSociety.allBoardIds.contains(userId);

      // Se for diretoria ou admin, buscar todos os formulários da categoria
      if (isBoardMember || user.isAdminUser) {
        final snapshot = await _firestore
            .collection('music_evaluation_forms')
            .where('category', isEqualTo: category.name)
            .orderBy('createdAt', descending: true)
            .get();

        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return EvaluationFormModel.fromJson(data);
        }).toList();
      }

      // Para usuários não-diretoria: buscar apenas formulários onde o usuário está em allowedUserIds
      // Primeiro, buscar todos os formulários da categoria
      final snapshot = await _firestore
          .collection('music_evaluation_forms')
          .where('category', isEqualTo: category.name)
          .orderBy('createdAt', descending: true)
          .get();

      final allForms = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return EvaluationFormModel.fromJson(data);
      }).toList();

      // Filtrar APENAS formulários onde o usuário está explicitamente em allowedUserIds
      // Isso garante que mesmo que o usuário tenha acesso à categoria, ele só vê formulários
      // onde foi explicitamente adicionado à lista de permissões
      final filteredForms = allForms
          .where((form) => form.allowedUserIds.contains(userId))
          .toList();

      return filteredForms;
    } catch (e) {
      // Exibir erro completo no console para facilitar cópia do link do índice
      print('❌ Erro ao carregar formulários (fetchFormsByCategory):');
      print(e.toString());
      print('');

      throw AppException(
        message: 'Erro ao carregar formulários: ${e.toString()}',
      );
    }
  }

  /// Buscar formulário específico
  Future<EvaluationFormModel> fetchFormById(String id) async {
    try {
      final doc = await _firestore
          .collection('music_evaluation_forms')
          .doc(id)
          .get();
      if (!doc.exists) {
        throw AppException(message: 'Formulário não encontrado.');
      }
      final data = doc.data()!;
      data['id'] = doc.id;
      return EvaluationFormModel.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao buscar formulário: ${e.toString()}');
    }
  }

  /// Criar novo formulário
  Future<EvaluationFormModel> createForm(EvaluationFormModel form) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      // Validar que usuário pode criar na categoria
      final user = await _getUserModel(userId);
      if (user == null) {
        throw AppException(message: 'Usuário não encontrado.');
      }

      final canCreate = await canCreateEvaluationInCategory(
        user,
        form.category,
      );
      if (!canCreate) {
        throw AppException(
          message:
              'Você não tem permissão para criar formulários nesta categoria.',
        );
      }

      final docRef = await _firestore
          .collection('music_evaluation_forms')
          .add(
            form
                .copyWith(
                  id: '', // Será definido pelo Firestore
                  createdBy: userId,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                )
                .toJson(),
          );

      return await fetchFormById(docRef.id);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao criar formulário: ${e.toString()}');
    }
  }

  /// Atualizar formulário
  Future<EvaluationFormModel> updateForm(EvaluationFormModel form) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      // Verificar se é o criador ou admin
      final existingForm = await fetchFormById(form.id);
      final user = await _getUserModel(userId);
      if (user == null) {
        throw AppException(message: 'Usuário não encontrado.');
      }

      if (existingForm.createdBy != userId && !user.isAdminUser) {
        throw AppException(
          message: 'Você não tem permissão para editar este formulário.',
        );
      }

      await _firestore
          .collection('music_evaluation_forms')
          .doc(form.id)
          .update(form.copyWith(updatedAt: DateTime.now()).toJson());

      return await fetchFormById(form.id);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao atualizar formulário: ${e.toString()}',
      );
    }
  }

  /// Deletar formulário
  Future<void> deleteForm(String id) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      // Verificar se é o criador, admin ou diretoria ELO
      final form = await fetchFormById(id);
      final user = await _getUserModel(userId);
      if (user == null) {
        throw AppException(message: 'Usuário não encontrado.');
      }

      // Verificar se é criador ou admin
      final isCreator = form.createdBy == userId;
      final isAdmin = user.isAdminUser;

      // Verificar se é da diretoria ELO
      bool isELOBoardMember = false;
      final eloSociety = await _societiesRepository.fetchByName('ELO');
      if (eloSociety != null) {
        isELOBoardMember = eloSociety.allBoardIds.contains(userId);
      }

      if (!isCreator && !isAdmin && !isELOBoardMember) {
        throw AppException(
          message: 'Você não tem permissão para deletar este formulário.',
        );
      }

      // Deletar respostas primeiro
      final responsesSnapshot = await _firestore
          .collection('music_evaluation_forms')
          .doc(id)
          .collection('responses')
          .get();

      final batch = _firestore.batch();
      for (final doc in responsesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Deletar formulário
      await _firestore.collection('music_evaluation_forms').doc(id).delete();
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao deletar formulário: ${e.toString()}',
      );
    }
  }

  /// Atualizar permissões do formulário
  Future<EvaluationFormModel> updateFormPermissions(
    String formId,
    List<String> userIds,
  ) async {
    try {
      final form = await fetchFormById(formId);

      // Validar que todos os usuários estão na categoria do formulário
      final eloSociety = await _societiesRepository.fetchByName('ELO');
      if (eloSociety == null) {
        throw AppException(message: 'Sociedade ELO não encontrada.');
      }

      final categoryUsers =
          eloSociety.forumUsersByCategory?[form.category.name] ?? [];
      final boardIds = eloSociety.allBoardIds;

      // Verificar se todos os usuários estão na categoria ou são da diretoria
      for (final userId in userIds) {
        if (!categoryUsers.contains(userId) && !boardIds.contains(userId)) {
          throw AppException(
            message:
                'Usuário $userId não está na categoria ${form.category.label}.',
          );
        }
      }

      return await updateForm(form.copyWith(allowedUserIds: userIds));
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao atualizar permissões: ${e.toString()}',
      );
    }
  }

  /// Salvar resposta
  Future<EvaluationResponseModel> submitResponse(
    EvaluationResponseModel response,
  ) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      // Verificar se pode acessar o formulário
      final canAccess = await canAccessForm(response.formId, userId);
      if (!canAccess) {
        throw AppException(
          message: 'Você não tem permissão para responder este formulário.',
        );
      }

      // Verificar se já existe resposta para esta música
      final existingResponse = await fetchUserResponseForMusic(
        response.formId,
        response.musicId,
        userId,
      );

      final now = DateTime.now();
      final responseData = response.copyWith(
        userId: userId,
        updatedAt: now,
        createdAt: existingResponse?.createdAt ?? now,
      );

      if (existingResponse != null) {
        // Atualizar resposta existente
        await _firestore
            .collection('music_evaluation_forms')
            .doc(response.formId)
            .collection('responses')
            .doc(existingResponse.id)
            .update(responseData.toJson());

        // Verificar e atualizar status do formulário se necessário
        await updateFormStatusIfNeeded(response.formId);

        return responseData.copyWith(id: existingResponse.id);
      } else {
        // Criar nova resposta
        final docRef = await _firestore
            .collection('music_evaluation_forms')
            .doc(response.formId)
            .collection('responses')
            .add(responseData.toJson());

        // Verificar e atualizar status do formulário se necessário
        await updateFormStatusIfNeeded(response.formId);

        return responseData.copyWith(id: docRef.id);
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao salvar resposta: ${e.toString()}');
    }
  }

  /// Buscar resposta específica do usuário para uma música
  Future<EvaluationResponseModel?> fetchUserResponseForMusic(
    String formId,
    String musicId,
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('music_evaluation_forms')
          .doc(formId)
          .collection('responses')
          .where('userId', isEqualTo: userId)
          .where('musicId', isEqualTo: musicId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return EvaluationResponseModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Buscar todas as respostas de um formulário (apenas diretoria)
  Future<List<EvaluationResponseModel>> fetchAllResponsesForForm(
    String formId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('music_evaluation_forms')
          .doc(formId)
          .collection('responses')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return EvaluationResponseModel.fromJson(data);
      }).toList();
    } catch (e) {
      throw AppException(
        message: 'Erro ao carregar respostas: ${e.toString()}',
      );
    }
  }

  /// Buscar respostas do usuário para um formulário
  Future<List<EvaluationResponseModel>> fetchUserResponsesForForm(
    String formId,
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('music_evaluation_forms')
          .doc(formId)
          .collection('responses')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return EvaluationResponseModel.fromJson(data);
      }).toList();
    } catch (e) {
      // Exibir erro completo no console para facilitar cópia do link do índice
      print(
        '❌ Erro ao carregar respostas do usuário (fetchUserResponsesForForm):',
      );
      print(e.toString());
      print('');

      throw AppException(
        message: 'Erro ao carregar respostas: ${e.toString()}',
      );
    }
  }

  /// Verificar se todos os usuários permitidos responderam
  Future<bool> checkIfAllUsersResponded(
    String formId,
    List<String> allowedUserIds,
  ) async {
    try {
      if (allowedUserIds.isEmpty) return false;

      for (final userId in allowedUserIds) {
        final userResponses = await fetchUserResponsesForForm(formId, userId);
        if (userResponses.isEmpty) return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Atualizar status do formulário automaticamente baseado nas respostas
  Future<void> updateFormStatusIfNeeded(String formId) async {
    try {
      final form = await fetchFormById(formId);

      // Se já estiver fechado, não precisa atualizar
      if (form.status == EvaluationFormStatus.closed) return;

      // Buscar apenas os usuários vinculados à categoria (não membros da diretoria)
      // O formulário só deve ser fechado quando todos os usuários vinculados responderem
      final categoryLinkedUserIds = await _getCategoryLinkedUserIds(form);

      if (categoryLinkedUserIds.isEmpty) return;

      // Verificar se todos os usuários vinculados à categoria responderam
      final allResponded = await checkIfAllUsersResponded(
        formId,
        categoryLinkedUserIds,
      );

      // Se todos responderam, atualizar para fechado
      if (allResponded) {
        await _firestore
            .collection('music_evaluation_forms')
            .doc(formId)
            .update({
              'status': EvaluationFormStatus.closed.name,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      // Silenciosamente falhar - não é crítico
    }
  }

  /// Buscar apenas os usuários vinculados à categoria (excluindo membros da diretoria)
  Future<List<String>> _getCategoryLinkedUserIds(
    EvaluationFormModel form,
  ) async {
    try {
      final eloSociety = await _societiesRepository.fetchByName('ELO');
      if (eloSociety == null) return form.allowedUserIds;

      // Buscar usuários vinculados à categoria específica
      final categoryUsers =
          eloSociety.forumUsersByCategory?[form.category.name] ?? [];

      // Retornar apenas os usuários vinculados à categoria (não incluir diretoria)
      return categoryUsers;
    } catch (e) {
      // Em caso de erro, retornar allowedUserIds original
      return form.allowedUserIds;
    }
  }

  /// Helper para buscar UserModel
  Future<UserModel?> _getUserModel(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return UserModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Cria 3 formulários (um por categoria) vinculados a uma música da biblioteca.
  Future<void> createFormsForMusic(MusicModel music) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final eloSociety = await _societiesRepository.fetchByName('ELO');
    if (eloSociety == null) return;

    try {
      final forumUsers = eloSociety.forumUsersByCategory ?? {};
      final now = DateTime.now();

      for (final category in EvaluationCategory.values) {
        final allowedUserIds = List<String>.from(forumUsers[category.name] ?? []);
        final docRef = _firestore.collection('music_evaluation_forms').doc();
        final form = EvaluationFormModel(
          id: docRef.id,
          title: '${music.title} – ${category.label}',
          category: category,
          createdBy: currentUserId,
          createdAt: now,
          updatedAt: now,
          allowedUserIds: allowedUserIds,
          status: EvaluationFormStatus.active,
          musicLibraryId: music.id,
        );
        await docRef.set(form.toJson());
      }
    } catch (e) {
      throw AppException(message: 'Erro ao criar formulários de avaliação: $e');
    }
  }

  /// Retorna músicas com todos os 3 forms fechados, prontas para decisão da diretoria.
  Future<List<MusicWithEvaluations>> fetchPendingDecisions() async {
    try {
      final snapshot = await _firestore
          .collection('music_evaluation_forms')
          .where('status', isEqualTo: EvaluationFormStatus.closed.name)
          .get();

      // ignore: avoid_print
      print('[fetchPendingDecisions] forms com status=closed: ${snapshot.docs.length}');
      final formsByMusicId = <String, List<EvaluationFormModel>>{};
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        final form = EvaluationFormModel.fromJson(data);
        // ignore: avoid_print
        print('[fetchPendingDecisions] form ${doc.id} | musicLibraryId=${form.musicLibraryId} | title=${form.title}');
        if (form.musicLibraryId == null) continue;
        formsByMusicId.putIfAbsent(form.musicLibraryId!, () => []).add(form);
      }

      // ignore: avoid_print
      print('[fetchPendingDecisions] musicIds com 3 forms fechados: ${formsByMusicId.entries.where((e) => e.value.length >= EvaluationCategory.values.length).map((e) => e.key).toList()}');
      final eligibleMusicIds = formsByMusicId.entries
          .where((e) => e.value.length >= EvaluationCategory.values.length)
          .map((e) => e.key)
          .toList();

      if (eligibleMusicIds.isEmpty) return [];

      final results = <MusicWithEvaluations>[];
      for (final musicId in eligibleMusicIds) {
        final musicDoc = await _firestore.collection('musics').doc(musicId).get();
        if (!musicDoc.exists) continue;
        final musicData = Map<String, dynamic>.from(musicDoc.data()!);
        musicData['id'] = musicDoc.id;
        final music = MusicModel.fromJson(musicData);
        if (music.status != MusicStatus.emAvaliacao) continue;

        final forms = formsByMusicId[musicId]!;
        final allResponses = <EvaluationResponseModel>[];
        for (final form in forms) {
          final responseSnap = await _firestore
              .collection('music_evaluation_forms')
              .doc(form.id)
              .collection('responses')
              .get();
          allResponses.addAll(responseSnap.docs.map((d) {
            final rData = Map<String, dynamic>.from(d.data());
            rData['id'] = d.id;
            return EvaluationResponseModel.fromJson(rData);
          }));
        }

        results.add(MusicWithEvaluations(
          music: music,
          forms: forms,
          responses: allResponses,
        ));
      }

      return results;
    } catch (e) {
      throw AppException(message: 'Erro ao buscar músicas pendentes de decisão: $e');
    }
  }

  /// Conta músicas prontas para decisão (para badge na tela Músicas).
  Future<int> countPendingDecisions() async {
    final list = await fetchPendingDecisions();
    return list.length;
  }

  /// Busca todas as avaliações encerradas de uma música da biblioteca.
  Future<MusicWithEvaluations?> fetchEvaluationsForMusic(MusicModel music) async {
    try {
      final snapshot = await _firestore
          .collection('music_evaluation_forms')
          .where('musicLibraryId', isEqualTo: music.id)
          .where('status', isEqualTo: EvaluationFormStatus.closed.name)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final forms = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return EvaluationFormModel.fromJson(data);
      }).toList();

      final allResponses = <EvaluationResponseModel>[];
      for (final form in forms) {
        final responseSnap = await _firestore
            .collection('music_evaluation_forms')
            .doc(form.id)
            .collection('responses')
            .get();
        allResponses.addAll(responseSnap.docs.map((d) {
          final rData = Map<String, dynamic>.from(d.data());
          rData['id'] = d.id;
          return EvaluationResponseModel.fromJson(rData);
        }));
      }

      return MusicWithEvaluations(music: music, forms: forms, responses: allResponses);
    } catch (e) {
      throw AppException(message: 'Erro ao buscar avaliações da música: $e');
    }
  }
}
