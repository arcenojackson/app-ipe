import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEventModel {
  const CalendarEventModel({
    required this.id,
    required this.name,
    required this.date,
    required this.category,
    this.start = '00:00',
    this.sourceCollection,
  });

  final String id;
  final String name;
  final DateTime date;
  final String category;
  final String start;
  /// 'events' = collection events (calendário). 'services' = collection services (Planejar/cultos/EBD/reuniões).
  final String? sourceCollection;

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      date: _parseDate(json['date']),
      category: json['category']?.toString() ?? 'Geral',
      start: json['start']?.toString() ?? '00:00',
      sourceCollection: json['sourceCollection']?.toString(),
    );
  }

  /// Cria um evento de calendário a partir de um serviço (collection services).
  static CalendarEventModel fromService(
    dynamic service, {
    String id = '',
    String name = '',
    DateTime? date,
    String start = '00:00',
  }) {
    if (service is Map<String, dynamic>) {
      return CalendarEventModel(
        id: service['id']?.toString() ?? id,
        name: service['name']?.toString() ?? name,
        date: _parseDate(service['date']),
        category: 'Geral',
        start: service['start']?.toString() ?? start,
        sourceCollection: 'services',
      );
    }
    return CalendarEventModel(
      id: id,
      name: name,
      date: date ?? DateTime.now(),
      category: 'Geral',
      start: start,
      sourceCollection: 'services',
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Converte string "HH:mm" em minutos desde meia-noite (ex: "10:00" -> 600, "19:30" -> 1170).
  static int _startToMinutes(String start) {
    final parts = start.split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final m = int.tryParse(parts[1].trim()) ?? 0;
    return h * 60 + m;
  }

  /// Ordenação por data (só dia civil) e, no mesmo dia, estritamente pelo horário
  /// do campo [start] (ex.: 10:00, 11:00, 19:30). Ignora qualquer hora em [date].
  static int compareByDateAndTime(CalendarEventModel a, CalendarEventModel b) {
    final aDay = DateTime(a.date.year, a.date.month, a.date.day);
    final bDay = DateTime(b.date.year, b.date.month, b.date.day);
    final dateCompare = aDay.compareTo(bDay);
    if (dateCompare != 0) return dateCompare;
    return _startToMinutes(a.start).compareTo(_startToMinutes(b.start));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': Timestamp.fromDate(date),
        'category': category,
        'start': start,
      };

  CalendarEventModel copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? category,
    String? start,
    String? sourceCollection,
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      category: category ?? this.category,
      start: start ?? this.start,
      sourceCollection: sourceCollection ?? this.sourceCollection,
    );
  }
}

