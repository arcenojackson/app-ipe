import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/utils/app_exception.dart';
import '../models/election.dart';

/// Leitura das eleições (Firestore) e criação (Function). Abrir escrutínios,
/// liberar presentes etc. é feito na tela web de condução, não aqui.
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
}
