import 'dart:convert';

class EventModel {
  const EventModel({
    required this.id,
    required this.name,
    required this.date,
    required this.start,
    this.steps = const [],
    this.peopleIds = const [],
  });

  final String id;
  final String name;
  final DateTime date;
  final String start;
  final List<EventStepModel> steps;
  final List<String> peopleIds;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      date: _parseDate(json['date']),
      start: json['start']?.toString() ?? '',
      steps: _parseSteps(json['steps']),
      peopleIds: _parsePeople(json['people']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static List<EventStepModel> _parseSteps(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      final decoded = jsonDecode(value) as List<dynamic>;
      return decoded
          .map((e) => EventStepModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (value is List) {
      return value
          .map((e) => EventStepModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  static List<String> _parsePeople(dynamic value) {
    if (value == null) return const [];
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    }
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date': date.toIso8601String(),
    'start': start,
    'steps': steps.map((e) => e.toJson()).toList(),
    'people': peopleIds,
  };

  EventModel copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? start,
    List<EventStepModel>? steps,
    List<String>? peopleIds,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      start: start ?? this.start,
      steps: steps ?? this.steps,
      peopleIds: peopleIds ?? this.peopleIds,
    );
  }
}

enum EventStepType { step, music }

class EventStepModel {
  EventStepModel({
    required this.title,
    this.description,
    this.duration,
    required this.type,
    this.musicId,
    this.musicTone,
  });

  final String title;
  final String? description;
  final int? duration;
  final EventStepType type;
  final String? musicId;
  final String? musicTone;

  factory EventStepModel.fromJson(Map<String, dynamic> json) {
    return EventStepModel(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      duration: json['duration'] is int
          ? json['duration'] as int
          : int.tryParse(json['duration']?.toString() ?? ''),
      type: _parseType(json['type']),
      musicId: json['musicId']?.toString(),
      musicTone: json['musicTone']?.toString(),
    );
  }

  static EventStepType _parseType(dynamic value) {
    if (value == 'music') return EventStepType.music;
    return EventStepType.step;
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'duration': duration,
    'type': type.name,
    'musicId': musicId,
    'musicTone': musicTone,
  };

  EventStepModel copyWith({
    String? title,
    String? description,
    int? duration,
    EventStepType? type,
    String? musicId,
    String? musicTone,
  }) {
    return EventStepModel(
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      type: type ?? this.type,
      musicId: musicId ?? this.musicId,
      musicTone: musicTone ?? this.musicTone,
    );
  }
}
