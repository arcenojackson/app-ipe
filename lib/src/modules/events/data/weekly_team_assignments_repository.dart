import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/utils/app_exception.dart';
import '../models/weekly_team_assignment.dart';

class WeeklyTeamAssignmentsRepository {
  WeeklyTeamAssignmentsRepository() : _firestore = FirebaseConfig.firestore;

  final FirebaseFirestore _firestore;
  static const String _collectionName = 'weeklyTeamAssignments';

  /// Carrega todas as configurações semanais
  Future<List<WeeklyTeamAssignment>> fetchAll() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['weekNumber'] = int.tryParse(doc.id) ?? 1;
        return WeeklyTeamAssignment.fromJson(data);
      }).toList()
        ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
    } catch (e) {
      throw AppException(
        message: 'Erro ao carregar configurações semanais: ${e.toString()}',
      );
    }
  }

  /// Salva ou atualiza uma configuração semanal
  Future<void> save(WeeklyTeamAssignment assignment) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(assignment.weekNumber.toString())
          .set(assignment.toJson());
    } catch (e) {
      throw AppException(
        message: 'Erro ao salvar configuração semanal: ${e.toString()}',
      );
    }
  }

  /// Salva todas as configurações semanais de uma vez
  Future<void> saveAll(List<WeeklyTeamAssignment> assignments) async {
    try {
      final batch = _firestore.batch();
      for (final assignment in assignments) {
        final docRef = _firestore
            .collection(_collectionName)
            .doc(assignment.weekNumber.toString());
        batch.set(docRef, assignment.toJson());
      }
      await batch.commit();
    } catch (e) {
      throw AppException(
        message: 'Erro ao salvar configurações semanais: ${e.toString()}',
      );
    }
  }

  /// Obtém a configuração para uma semana específica
  Future<WeeklyTeamAssignment?> fetchByWeek(int weekNumber) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(weekNumber.toString())
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      data['weekNumber'] = weekNumber;
      return WeeklyTeamAssignment.fromJson(data);
    } catch (e) {
      throw AppException(
        message: 'Erro ao carregar configuração semanal: ${e.toString()}',
      );
    }
  }
}
