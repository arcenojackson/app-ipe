import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/utils/app_exception.dart';
import '../models/election.dart';

/// Leitura das eleições (Firestore), criação e voto (Functions). Abrir
/// escrutínios, liberar presentes etc. é feito na tela web de condução, não
/// aqui.
class ElectionsRepository {
  ElectionsRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _election(String id) =>
      _db.collection('elections').doc(id);

  /// Eleições das sociedades em que [userId] é diretor (as regras só deixam
  /// listar com este filtro). Ordenadas aqui para não exigir índice composto.
  Stream<List<Election>> watchElections(String userId) => _db
      .collection('elections')
      .where('directorIds', arrayContains: userId)
      .snapshots()
      .map((s) {
        final list =
            s.docs.map((d) => Election.fromJson(d.id, d.data())).toList();
        list.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
        return list;
      });

  Stream<Election?> watchElection(String id) => _election(id)
      .snapshots()
      .map((d) => d.exists ? Election.fromJson(d.id, d.data()!) : null);

  Stream<List<ElectionCargo>> watchCargos(String electionId) =>
      _election(electionId).collection('cargos').snapshots().map(
            (s) => s.docs
                .map((d) => ElectionCargo.fromJson(d.id, d.data()))
                .toList(),
          );

  Stream<List<ElectionRound>> watchRounds(String electionId) =>
      _election(electionId).collection('rounds').snapshots().map(
            (s) => s.docs
                .map((d) => ElectionRound.fromJson(d.id, d.data()))
                .toList(),
          );

  Stream<List<ElectionVoter>> watchVoters(String electionId) =>
      _election(electionId).collection('voters').snapshots().map((s) {
        final list =
            s.docs.map((d) => ElectionVoter.fromJson(d.id, d.data())).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  Stream<List<ElectionEvent>> watchEvents(String electionId) =>
      _election(electionId).collection('events').orderBy('at').snapshots().map(
            (s) => s.docs
                .map((d) => ElectionEvent.fromJson(d.id, d.data()))
                .toList(),
          );

  /// Cria a eleição pela Function `electionCreate`, que confere se quem chama
  /// está na diretoria da sociedade. Devolve o id da eleição.
  Future<String> createElection({
    required String societyId,
    required String title,
    required DateTime scheduledAt,
    required List<String> positions,
  }) async {
    try {
      final res = await _functions.httpsCallable('electionCreate').call<dynamic>({
        'societyId': societyId,
        'title': title,
        'scheduledAtMs': scheduledAt.millisecondsSinceEpoch,
        'positions': positions,
      });
      final data = res.data;
      final id = data is Map ? data['electionId']?.toString() : null;
      if (id == null || id.isEmpty) {
        throw AppException(message: 'Resposta inesperada do servidor.');
      }
      return id;
    } on FirebaseFunctionsException catch (e) {
      throw AppException(message: e.message ?? 'Erro ao criar a eleição.');
    }
  }

  /// Convites do usuário (gravados pelo servidor ao abrir a eleição), os mais
  /// novos primeiro.
  Stream<List<ElectionInvite>> watchInvites(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('election_invites')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ElectionInvite.fromJson(d.id, d.data())).toList(),
      );

  /// Registro de presença do próprio usuário; `null` até fazer o check-in.
  Stream<ElectionVoter?> watchMyVoter(String electionId, String uid) =>
      _election(electionId).collection('voters').doc(uid).snapshots().map(
            (d) => d.exists ? ElectionVoter.fromJson(d.id, d.data()!) : null,
          );

  /// Escrutínio aberto no momento; `null` quando não há.
  Stream<ElectionRound?> watchOpenRound(String electionId) => _election(
        electionId,
      )
          .collection('rounds')
          .where('status', isEqualTo: 'open')
          .limit(1)
          .snapshots()
          .map(
            (s) => s.docs.isEmpty
                ? null
                : ElectionRound.fromJson(s.docs.first.id, s.docs.first.data()),
          );

  /// Se o usuário já votou nesta rodada (o servidor grava só a marca, nunca
  /// em quem).
  Stream<bool> watchHasVoted(String electionId, String roundId, String uid) =>
      _election(electionId)
          .collection('rounds')
          .doc(roundId)
          .collection('voted')
          .doc(uid)
          .snapshots()
          .map((d) => d.exists);

  /// Entra na votação (presença). Pelo app só membros da sociedade entram: o
  /// servidor recusa os demais.
  Future<void> checkIn(String electionId) async {
    try {
      await _functions.httpsCallable('electionCheckIn').call<dynamic>({
        'electionId': electionId,
        'memberOnly': true,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AppException(
        message: e.message ?? 'Não foi possível entrar na votação.',
      );
    }
  }

  /// Registra o voto (id do candidato ou `blank`) e devolve o código do
  /// comprovante.
  Future<String> castVote(
    String electionId,
    String roundId,
    String choice,
  ) async {
    try {
      final res = await _functions.httpsCallable('electionCastVote').call<dynamic>({
        'electionId': electionId,
        'roundId': roundId,
        'choice': choice,
      });
      final data = res.data;
      return data is Map ? data['receipt']?.toString() ?? '' : '';
    } on FirebaseFunctionsException catch (e) {
      throw AppException(message: e.message ?? 'Não foi possível votar.');
    }
  }
}
