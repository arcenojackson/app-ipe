import 'dart:convert';

import 'event.dart';

class EventTemplateModel {
  const EventTemplateModel({
    required this.id,
    required this.name,
    required this.steps,
    this.createdAt,
  });

  final String id;
  final String name;
  final List<EventStepModel> steps;
  final DateTime? createdAt;

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

  factory EventTemplateModel.fromJson(Map<String, dynamic> json) {
    return EventTemplateModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Template sem nome',
      steps: _parseSteps(json['steps']),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is DateTime
              ? json['createdAt'] as DateTime
              : (json['createdAt'] as dynamic).toDate())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'steps': steps.map((e) => e.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
      };

  EventTemplateModel copyWith({
    String? id,
    String? name,
    List<EventStepModel>? steps,
    DateTime? createdAt,
  }) {
    return EventTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

