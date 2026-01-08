import 'dart:convert';

class EventPeople {
  const EventPeople({
    this.elo = const [],
    this.preacher = const [],
    this.lead = const [],
    this.soundImage = const [],
    this.eloWithInstruments = const {},
  });

  final List<String> elo;
  final List<String> preacher;
  final List<String> lead;
  final List<String> soundImage;
  // Map<userId, Map<instrument, talkBack>>
  final Map<String, Map<String, bool>> eloWithInstruments;

  factory EventPeople.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EventPeople();
    
    // Parse eloWithInstruments
    Map<String, Map<String, bool>> eloWithInstruments = {};
    if (json['eloWithInstruments'] is Map) {
      final eloMap = json['eloWithInstruments'] as Map;
      eloMap.forEach((userId, value) {
        if (value is Map) {
          final instrumentMap = <String, bool>{};
          value.forEach((instrument, talkBack) {
            instrumentMap[instrument.toString()] = talkBack == true;
          });
          eloWithInstruments[userId.toString()] = instrumentMap;
        }
      });
    }
    
    return EventPeople(
      elo: _parsePeopleList(json['elo']),
      preacher: _parsePeopleList(json['preacher']),
      lead: _parsePeopleList(json['lead']),
      soundImage: _parsePeopleList(json['soundImage']),
      eloWithInstruments: eloWithInstruments,
    );
  }

  static List<String> _parsePeopleList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
    'elo': elo,
    'preacher': preacher,
    'lead': lead,
    'soundImage': soundImage,
    'eloWithInstruments': eloWithInstruments,
  };

  EventPeople copyWith({
    List<String>? elo,
    List<String>? preacher,
    List<String>? lead,
    List<String>? soundImage,
    Map<String, Map<String, bool>>? eloWithInstruments,
  }) {
    return EventPeople(
      elo: elo ?? this.elo,
      preacher: preacher ?? this.preacher,
      lead: lead ?? this.lead,
      soundImage: soundImage ?? this.soundImage,
      eloWithInstruments: eloWithInstruments ?? this.eloWithInstruments,
    );
  }

  List<String> get allPeopleIds => [
        ...elo,
        ...preacher,
        ...lead,
        ...soundImage,
        ...eloWithInstruments.keys,
      ];
}

class EventModel {
  const EventModel({
    required this.id,
    required this.name,
    required this.date,
    required this.start,
    this.steps = const [],
    this.people = const EventPeople(),
  });

  final String id;
  final String name;
  final DateTime date;
  final String start;
  final List<EventStepModel> steps;
  final EventPeople people;

  // Mantido para compatibilidade com código antigo
  List<String> get peopleIds => people.allPeopleIds;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Tentar primeiro a nova estrutura (people como objeto)
    if (json['people'] is Map) {
      return EventModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        date: _parseDate(json['date']),
        start: json['start']?.toString() ?? '',
        steps: _parseSteps(json['steps']),
        people: EventPeople.fromJson(json['people'] as Map<String, dynamic>),
      );
    }
    // Fallback para estrutura antiga (people como array)
    final oldPeopleIds = _parsePeople(json['people']);
    return EventModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      date: _parseDate(json['date']),
      start: json['start']?.toString() ?? '',
      steps: _parseSteps(json['steps']),
      people: EventPeople(
        elo: oldPeopleIds, // Migração: coloca todos no elo por padrão
      ),
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
    'people': people.toJson(),
  };

  EventModel copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? start,
    List<EventStepModel>? steps,
    EventPeople? people,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      start: start ?? this.start,
      steps: steps ?? this.steps,
      people: people ?? this.people,
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
