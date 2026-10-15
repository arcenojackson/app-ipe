import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/app_exception.dart';
import '../models/election.dart';

class ElectionsRepository {
  ElectionsRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _election(String id) =>
      _db.collection('elections').doc(id);

  Stream<List<Election>> watchElections() => _db
      .collection('elections')
      .orderBy('scheduledAt', descending: true)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => Election.fromJson(d.id, d.data())).toList(),
      );

  Stream<Election?> watchElection(String id) => _election(id)
      .snapshots()
      .map((d) => d.exists ? Election.fromJson(d.id, d.data()!) : null);

  Stream<List<ElectionRound>> watchRounds(String electionId) =>
      _election(electionId)
          .collection('rounds')
          .orderBy('createdAt')
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => ElectionRound.fromJson(d.id, d.data()))
                .toList(),
          );

  Stream<List<ElectionVoter>> watchVoters(String electionId) =>
      _election(electionId)
          .collection('voters')
          .orderBy('createdAt')
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => ElectionVoter.fromJson(d.id, d.data()))
                .toList(),
          );

  Stream<List<ElectionEvent>> watchEvents(String electionId) =>
      _election(electionId)
          .collection('events')
          .orderBy('at')
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => ElectionEvent.fromJson(d.id, d.data()))
                .toList(),
          );

  Future<String> createElection({
    required String societyId,
    required String societyName,
    required String title,
    required DateTime scheduledAt,
    required List<String> positions,
  }) async {
    try {
      final ref = await _db.collection('elections').add({
        'societyId': societyId,
        'societyName': societyName,
        'title': title,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'status': 'draft',
        'positions': positions,
        'createdBy': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      throw AppException(message: 'Erro ao criar eleição: $e');
    }
  }

  /// Cria a rodada pendente do cargo ou, com [roundId], troca os candidatos.
  Future<void> saveRoundCandidates({
    required String electionId,
    required String position,
    required List<Candidate> candidates,
    String? roundId,
    RoundType type = RoundType.normal,
  }) async {
    try {
      final rounds = _election(electionId).collection('rounds');
      if (roundId == null) {
        await rounds.add({
          'position': position,
          'candidates': candidates.map((c) => c.toJson()).toList(),
          'type': type.name,
          'status': 'pending',
          'votedCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await rounds.doc(roundId).update({
          'candidates': candidates.map((c) => c.toJson()).toList(),
        });
      }
    } catch (e) {
      throw AppException(message: 'Erro ao salvar candidatos: $e');
    }
  }

  Future<void> deleteRound(String electionId, String roundId) async {
    try {
      await _election(electionId).collection('rounds').doc(roundId).delete();
    } catch (e) {
      throw AppException(message: 'Erro ao remover votação: $e');
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _functions.httpsCallable(name).call<dynamic>(data);
      final body = res.data;
      return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw AppException(message: e.message ?? 'Erro ao falar com o servidor.');
    } catch (e) {
      throw AppException(message: 'Erro ao falar com o servidor: $e');
    }
  }

  Future<void> setStatus(String electionId, ElectionStatus target) async {
    await _call('electionSetStatus', {
      'electionId': electionId,
      'status': target.name,
    });
  }

  Future<void> reviewVoter(
    String electionId,
    String voterId,
    VoterStatus decision,
  ) async {
    await _call('electionReviewVoter', {
      'electionId': electionId,
      'voterId': voterId,
      'decision': decision.name,
    });
  }

  Future<void> openRound(String electionId, String roundId) async {
    await _call('electionOpenRound', {
      'electionId': electionId,
      'roundId': roundId,
    });
  }

  Future<RoundResult> closeRound(String electionId, String roundId) async {
    final data = await _call('electionCloseRound', {
      'electionId': electionId,
      'roundId': roundId,
    });
    return RoundResult.fromJson(data);
  }

  Future<void> applyBoard(String electionId) async {
    await _call('electionApplyBoard', {'electionId': electionId});
  }
}
