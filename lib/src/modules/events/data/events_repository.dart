import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_exception.dart';
import '../models/event.dart';

class EventsRepository {
  EventsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  String? get _currentUserId => FirebaseConfig.auth.currentUser?.uid;

  /// Carrega os steps padrão do arquivo steps.json
  Future<List<EventStepModel>> _loadDefaultSteps() async {
    try {
      final jsonString = await rootBundle.loadString('steps.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((item) => EventStepModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Retorna lista vazia em caso de erro
      return const [];
    }
  }

  Future<List<EventModel>> fetchUpcoming() async {
    final response = await _apiClient.get('/events');
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .map((item) => EventModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<EventModel> fetchById(String id) async {
    try {
      final doc = await _firestore.collection('services').doc(id).get();
      if (!doc.exists) {
        throw AppException(message: 'Serviço não encontrado.');
      }
      final data = doc.data()!;
      data['id'] = doc.id;
      // Converter Timestamp do Firestore para DateTime se necessário
      if (data['date'] != null && data['date'] is Timestamp) {
        data['date'] = (data['date'] as Timestamp).toDate();
      }
      
      final event = EventModel.fromJson(data);
      
      return event;
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao buscar serviço: ${e.toString()}',
      );
    }
  }

  Future<List<EventModel>> fetchForUser(String userId) async {
    final response = await _apiClient.get('/people/$userId/events');
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .map((item) => EventModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<EventModel> createEvent({
    required String name,
    required DateTime date,
    required String start,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      // Carregar steps padrão do arquivo JSON
      final defaultSteps = await _loadDefaultSteps();

      final docRef = _firestore.collection('services').doc();
      final eventData = {
        'name': name,
        'date': Timestamp.fromDate(date),
        'start': start,
        'userId': userId,
        'people': <String>[],
        'steps': defaultSteps.map((step) => step.toJson()).toList(),
      };

      await docRef.set(eventData);

      // Buscar o documento criado para converter corretamente
      final doc = await docRef.get();
      final data = doc.data()!;
      data['id'] = doc.id;
      // Converter Timestamp para DateTime
      if (data['date'] != null && data['date'] is Timestamp) {
        data['date'] = (data['date'] as Timestamp).toDate();
      }
      return EventModel.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao criar serviço: ${e.toString()}',
      );
    }
  }

  Future<EventModel> updateEvent({
    required String id,
    required String name,
    required DateTime date,
    required String start,
  }) async {
    try {
      await _firestore.collection('services').doc(id).update({
        'name': name,
        'date': Timestamp.fromDate(date),
        'start': start,
      });

      // Buscar o documento atualizado
      return await fetchById(id);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao atualizar serviço: ${e.toString()}',
      );
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await _firestore.collection('services').doc(id).delete();
    } catch (e) {
      throw AppException(
        message: 'Erro ao excluir serviço: ${e.toString()}',
      );
    }
  }

  Future<void> updateEventDetails({
    required String id,
    required List<EventStepModel> steps,
    required List<String> peopleIds,
  }) async {
    try {
      await _firestore.collection('services').doc(id).update({
        'steps': steps.map((step) => step.toJson()).toList(),
        'people': peopleIds,
      });
    } catch (e) {
      throw AppException(
        message: 'Erro ao atualizar detalhes do serviço: ${e.toString()}',
      );
    }
  }

  /// Busca services do Firestore onde o userId está na lista de people
  Future<List<EventModel>> fetchServicesForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('services')
          .where('people', arrayContains: userId)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Converter Timestamp do Firestore para DateTime se necessário
        if (data['date'] != null && data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate();
        }
        return EventModel.fromJson(data);
      }).toList();
    } catch (e, stackTrace) {
      throw AppException(
        message: 'Erro ao carregar serviços: ${e.toString()}',
      );
    }
  }

  /// Busca todos os services do Firestore
  Future<List<EventModel>> fetchAllServices() async {
    try {
      final snapshot = await _firestore.collection('services').get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Converter Timestamp do Firestore para DateTime se necessário
        if (data['date'] != null && data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate();
        }
        return EventModel.fromJson(data);
      }).toList();
    } catch (e, stackTrace) {
      throw AppException(
        message: 'Erro ao carregar serviços: ${e.toString()}',
      );
    }
  }
}
