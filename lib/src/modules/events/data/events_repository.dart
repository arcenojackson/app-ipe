import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_exception.dart';
import '../models/event.dart';
import '../models/event_template.dart';
import '../models/calendar_event.dart';

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
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao buscar serviço: ${e.toString()}');
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
    String? templateId,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      List<EventStepModel> steps = const [];

      // Se um template foi selecionado, usar as etapas do template
      if (templateId != null) {
        try {
          final template = await fetchTemplateById(templateId);
          steps = template.steps;
        } catch (e) {
          // Se não conseguir carregar o template, criar sem etapas
          steps = const [];
        }
      }
      // Se nenhum template foi selecionado, criar sem etapas (conforme solicitado)

      final docRef = _firestore.collection('services').doc();
      final eventData = {
        'name': name,
        'date': Timestamp.fromDate(date),
        'start': start,
        'userId': userId,
        'people': <String>[],
        'steps': steps.map((step) => step.toJson()).toList(),
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
      throw AppException(message: 'Erro ao criar serviço: ${e.toString()}');
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
      throw AppException(message: 'Erro ao atualizar serviço: ${e.toString()}');
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await _firestore.collection('services').doc(id).delete();
    } catch (e) {
      throw AppException(message: 'Erro ao excluir serviço: ${e.toString()}');
    }
  }

  Future<void> updateEventDetails({
    required String id,
    required List<EventStepModel> steps,
    required EventPeople people,
  }) async {
    try {
      await _firestore.collection('services').doc(id).update({
        'steps': steps.map((step) => step.toJson()).toList(),
        'people': people.toJson(),
      });
    } catch (e) {
      throw AppException(
        message: 'Erro ao atualizar detalhes do serviço: ${e.toString()}',
      );
    }
  }

  /// Busca services do Firestore onde o userId está na lista de people
  /// Suporta tanto a estrutura antiga (array simples) quanto a nova (objeto com elo, preacher, lead)
  Future<List<EventModel>> fetchServicesForUser(String userId) async {
    try {
      // Buscar todos os serviços e filtrar no código, pois Firestore não suporta
      // consultas complexas em estruturas aninhadas
      final snapshot = await _firestore.collection('services').get();

      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            final people = data['people'];

            // Nova estrutura: objeto com elo, preacher, lead
            if (people is Map) {
              final elo = people['elo'] as List<dynamic>? ?? [];
              final preacher = people['preacher'] as List<dynamic>? ?? [];
              final lead = people['lead'] as List<dynamic>? ?? [];
              return elo.contains(userId) ||
                  preacher.contains(userId) ||
                  lead.contains(userId);
            }

            // Estrutura antiga: array simples (compatibilidade)
            if (people is List) {
              return people.contains(userId);
            }

            return false;
          })
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            // Converter Timestamp do Firestore para DateTime se necessário
            if (data['date'] != null && data['date'] is Timestamp) {
              data['date'] = (data['date'] as Timestamp).toDate();
            }
            return EventModel.fromJson(data);
          })
          .toList();
    } catch (e) {
      throw AppException(message: 'Erro ao carregar serviços: ${e.toString()}');
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
    } catch (e) {
      throw AppException(message: 'Erro ao carregar serviços: ${e.toString()}');
    }
  }

  // ========== MÉTODOS PARA TEMPLATES ==========

  /// Busca todos os templates do Firestore
  Future<List<EventTemplateModel>> fetchAllTemplates() async {
    try {
      final snapshot = await _firestore.collection('services_templates').get();

      // Se não houver documentos, retornar lista vazia (não é um erro)
      if (snapshot.docs.isEmpty) {
        return const [];
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Converter Timestamp do Firestore para DateTime se necessário
        if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
        }
        return EventTemplateModel.fromJson(data);
      }).toList();
    } catch (e) {
      // Se a collection não existir, retornar lista vazia ao invés de erro
      if (e.toString().contains('permission') ||
          e.toString().contains('not-found') ||
          e.toString().contains('NOT_FOUND')) {
        return const [];
      }
      throw AppException(
        message: 'Erro ao carregar templates: ${e.toString()}',
      );
    }
  }

  /// Busca um template por ID
  Future<EventTemplateModel> fetchTemplateById(String id) async {
    try {
      final doc = await _firestore
          .collection('services_templates')
          .doc(id)
          .get();
      if (!doc.exists) {
        throw AppException(message: 'Template não encontrado.');
      }
      final data = doc.data()!;
      data['id'] = doc.id;
      // Converter Timestamp do Firestore para DateTime se necessário
      if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
      }
      return EventTemplateModel.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao buscar template: ${e.toString()}');
    }
  }

  /// Cria um template padrão baseado no steps.json
  Future<EventTemplateModel> createDefaultTemplate() async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      final defaultSteps = await _loadDefaultSteps();
      // Filtrar apenas etapas (sem músicas)
      final stepsOnly = defaultSteps
          .where((step) => step.type == EventStepType.step)
          .toList();

      final docRef = _firestore.collection('services_templates').doc();
      final templateData = {
        'name': 'Template Padrão',
        'steps': stepsOnly.map((step) => step.toJson()).toList(),
        'userId': userId,
        'createdAt': Timestamp.now(),
      };

      await docRef.set(templateData);

      // Buscar o documento criado
      final doc = await docRef.get();
      final data = doc.data()!;
      data['id'] = doc.id;
      if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
      }
      return EventTemplateModel.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao criar template padrão: ${e.toString()}',
      );
    }
  }

  /// Cria um novo template
  Future<EventTemplateModel> createTemplate({
    required String name,
    required List<EventStepModel> steps,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      // Filtrar apenas etapas (sem músicas)
      final stepsOnly = steps
          .where((step) => step.type == EventStepType.step)
          .toList();

      final docRef = _firestore.collection('services_templates').doc();
      final templateData = {
        'name': name,
        'steps': stepsOnly.map((step) => step.toJson()).toList(),
        'userId': userId,
        'createdAt': Timestamp.now(),
      };

      await docRef.set(templateData);

      // Buscar o documento criado
      final doc = await docRef.get();
      final data = doc.data()!;
      data['id'] = doc.id;
      if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
      }
      return EventTemplateModel.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao criar template: ${e.toString()}');
    }
  }

  /// Atualiza um template
  Future<EventTemplateModel> updateTemplate({
    required String id,
    required String name,
    required List<EventStepModel> steps,
  }) async {
    try {
      // Filtrar apenas etapas (sem músicas)
      final stepsOnly = steps
          .where((step) => step.type == EventStepType.step)
          .toList();

      await _firestore.collection('services_templates').doc(id).update({
        'name': name,
        'steps': stepsOnly.map((step) => step.toJson()).toList(),
      });

      // Buscar o template atualizado
      return await fetchTemplateById(id);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Erro ao atualizar template: ${e.toString()}',
      );
    }
  }

  /// Exclui um template
  Future<void> deleteTemplate(String id) async {
    try {
      await _firestore.collection('services_templates').doc(id).delete();
    } catch (e) {
      throw AppException(message: 'Erro ao excluir template: ${e.toString()}');
    }
  }

  // ========== MÉTODOS PARA CALENDÁRIO (COLLECTION 'events') ==========

  /// Busca eventos do calendário por categoria
  Future<List<CalendarEventModel>> fetchCalendarEventsByCategory(
    String category,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('category', isEqualTo: category)
          .get();

      final events = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['date'] != null && data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate();
        }
        return CalendarEventModel.fromJson(data);
      }).toList();

      // Ordenar por data após buscar (evita necessidade de índice composto)
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    } catch (e) {
      throw AppException(
        message: 'Erro ao carregar eventos do calendário: ${e.toString()}',
      );
    }
  }

  /// Busca eventos do calendário por múltiplas categorias
  Future<List<CalendarEventModel>> fetchCalendarEventsByCategories(
    List<String> categories,
  ) async {
    try {
      if (categories.isEmpty) {
        return await fetchAllCalendarEvents();
      }

      // Buscar todos os eventos e filtrar por categoria
      // (Firestore não suporta OR diretamente, então fazemos no código)
      final snapshot = await _firestore.collection('events').get();

      final events = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            if (data['date'] != null && data['date'] is Timestamp) {
              data['date'] = (data['date'] as Timestamp).toDate();
            }
            return CalendarEventModel.fromJson(data);
          })
          .where((event) => categories.contains(event.category))
          .toList();

      // Ordenar por data após buscar
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    } catch (e) {
      throw AppException(
        message: 'Erro ao carregar eventos do calendário: ${e.toString()}',
      );
    }
  }

  /// Busca eventos do calendário em um intervalo de datas
  Future<List<CalendarEventModel>> fetchCalendarEventsByDateRange(
    DateTime start,
    DateTime end, {
    String? category,
  }) async {
    try {
      Query query = _firestore.collection('events');

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      final snapshot = await query.get();

      // Normalizar datas para comparar apenas ano/mês/dia (meia-noite)
      final startDateNormalized = DateTime(start.year, start.month, start.day);
      final endDateNormalized = DateTime(end.year, end.month, end.day);

      // Filtrar eventos por intervalo de datas após buscar
      final events = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            if (data['date'] != null && data['date'] is Timestamp) {
              data['date'] = (data['date'] as Timestamp).toDate();
            }
            return CalendarEventModel.fromJson(data);
          })
          .where((event) {
            final eventDateNormalized = DateTime(
              event.date.year,
              event.date.month,
              event.date.day,
            );
            // Comparar usando compareTo para incluir os limites
            return eventDateNormalized.compareTo(startDateNormalized) >= 0 &&
                eventDateNormalized.compareTo(endDateNormalized) <= 0;
          })
          .toList();

      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    } catch (e) {
      throw AppException(
        message: 'Erro ao carregar eventos do calendário: ${e.toString()}',
      );
    }
  }

  /// Busca eventos do calendário para uma data específica
  Future<List<CalendarEventModel>> fetchCalendarEventsByDate(
    DateTime date, {
    String? category,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      return await fetchCalendarEventsByDateRange(
        startOfDay,
        endOfDay,
        category: category,
      );
    } catch (e) {
      throw AppException(
        message: 'Erro ao carregar eventos do calendário: ${e.toString()}',
      );
    }
  }

  /// Busca todos os eventos do calendário
  Future<List<CalendarEventModel>> fetchAllCalendarEvents() async {
    try {
      final snapshot = await _firestore.collection('events').get();

      final events = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['date'] != null && data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate();
        }
        return CalendarEventModel.fromJson(data);
      }).toList();

      // Ordenar por data após buscar (evita necessidade de índice)
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    } catch (e) {
      throw AppException(
        message: 'Erro ao carregar eventos do calendário: ${e.toString()}',
      );
    }
  }

  /// Cria um novo evento no calendário
  Future<CalendarEventModel> createCalendarEvent({
    required String name,
    required DateTime date,
    required String category,
    String start = '00:00',
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AppException(message: 'Usuário não autenticado.');
      }

      final docRef = _firestore.collection('events').doc();
      final eventData = {
        'name': name,
        'date': Timestamp.fromDate(date),
        'category': category,
        'userId': userId,
        'start': start,
      };

      await docRef.set(eventData);

      final doc = await docRef.get();
      final data = doc.data()!;
      data['id'] = doc.id;
      if (data['date'] != null && data['date'] is Timestamp) {
        data['date'] = (data['date'] as Timestamp).toDate();
      }
      return CalendarEventModel.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao criar evento: ${e.toString()}');
    }
  }

  /// Atualiza um evento do calendário
  Future<CalendarEventModel> updateCalendarEvent({
    required String id,
    required String name,
    required DateTime date,
    required String category,
    String start = '00:00',
  }) async {
    try {
      await _firestore.collection('events').doc(id).update({
        'name': name,
        'date': Timestamp.fromDate(date),
        'category': category,
        'start': start,
      });

      final doc = await _firestore.collection('events').doc(id).get();
      final data = doc.data()!;
      data['id'] = doc.id;
      if (data['date'] != null && data['date'] is Timestamp) {
        data['date'] = (data['date'] as Timestamp).toDate();
      }
      return CalendarEventModel.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Erro ao atualizar evento: ${e.toString()}');
    }
  }

  /// Exclui um evento do calendário
  Future<void> deleteCalendarEvent(String id) async {
    try {
      await _firestore.collection('events').doc(id).delete();
    } catch (e) {
      throw AppException(message: 'Erro ao excluir evento: ${e.toString()}');
    }
  }

  // ========== MÉTODOS PARA DISPONIBILIDADE DA EQUIPE DE LOUVOR ==========

  /// Salva a disponibilidade do usuário para a equipe de louvor
  /// Armazena os domingos selecionados do mês seguinte
  /// Remove todas as disponibilidades antigas e mantém apenas as do mês seguinte
  Future<void> saveWorshipTeamAvailability(
    String userId,
    List<DateTime> selectedSundays,
  ) async {
    try {
      // Normalizar as datas para remover horas/minutos/segundos
      final normalizedDates = selectedSundays
          .map((date) => DateTime(date.year, date.month, date.day))
          .toList();

      // Determinar o mês seguinte à data corrente
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1, 1);

      // Filtrar apenas as datas do mês seguinte (caso haja alguma data fora do período)
      final nextMonthDates = normalizedDates.where((date) {
        return date.year == nextMonth.year &&
            date.month == nextMonth.month &&
            date.isAfter(DateTime(nextMonth.year, nextMonth.month, 0)) &&
            date.isBefore(DateTime(nextMonth.year, nextMonth.month + 1, 1));
      }).toList();

      // Converter as datas selecionadas para Timestamps
      final timestamps = nextMonthDates
          .map((date) => Timestamp.fromDate(date))
          .toList();

      // Atualizar o documento do usuário na collection 'users'
      // Substituir completamente o array 'availability' com apenas as datas do mês seguinte
      // Isso remove automaticamente todas as disponibilidades antigas
      await _firestore.collection('users').doc(userId).update({
        'availability': timestamps,
      });
    } catch (e) {
      throw AppException(
        message: 'Erro ao salvar disponibilidade: ${e.toString()}',
      );
    }
  }

  /// Busca a disponibilidade do usuário para a equipe de louvor
  /// Retorna uma lista de DateTime com os domingos selecionados
  /// Busca apenas as disponibilidades do mês seguinte
  Future<List<DateTime>> fetchWorshipTeamAvailability(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return [];
      }

      final data = doc.data()!;
      final timestamps = data['availability'] as List<dynamic>?;

      if (timestamps == null) {
        return [];
      }

      // Determinar o mês seguinte à data corrente
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1, 1);

      // Converter timestamps e filtrar apenas os do mês seguinte
      final allDates = timestamps
          .map((timestamp) {
            if (timestamp is Timestamp) {
              final date = timestamp.toDate();
              // Normalizar para remover horas/minutos/segundos
              return DateTime(date.year, date.month, date.day);
            }
            return null;
          })
          .whereType<DateTime>()
          .toList();

      // Filtrar apenas as datas do mês seguinte
      return allDates.where((date) {
        return date.year == nextMonth.year && date.month == nextMonth.month;
      }).toList();
    } catch (e) {
      throw AppException(
        message: 'Erro ao buscar disponibilidade: ${e.toString()}',
      );
    }
  }

  /// Verifica se um usuário tem disponibilidade confirmada para uma data específica
  Future<bool> hasAvailabilityForDate(String userId, DateTime date) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data()!;
      final timestamps = data['availability'] as List<dynamic>?;

      if (timestamps == null || timestamps.isEmpty) {
        return false;
      }

      // Normalizar a data fornecida (remover horas/minutos/segundos)
      final normalizedDate = DateTime(date.year, date.month, date.day);

      // Verificar se a data está na lista de disponibilidades
      for (final timestamp in timestamps) {
        if (timestamp is Timestamp) {
          final availableDate = timestamp.toDate();
          final normalizedAvailableDate = DateTime(
            availableDate.year,
            availableDate.month,
            availableDate.day,
          );
          if (normalizedAvailableDate.year == normalizedDate.year &&
              normalizedAvailableDate.month == normalizedDate.month &&
              normalizedAvailableDate.day == normalizedDate.day) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      throw AppException(
        message: 'Erro ao verificar disponibilidade: ${e.toString()}',
      );
    }
  }
}
