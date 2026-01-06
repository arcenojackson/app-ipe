import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEventModel {
  const CalendarEventModel({
    required this.id,
    required this.name,
    required this.date,
    required this.category,
    this.start = '00:00',
  });

  final String id;
  final String name;
  final DateTime date;
  final String category;
  final String start;

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      date: _parseDate(json['date']),
      category: json['category']?.toString() ?? 'Geral',
      start: json['start']?.toString() ?? '00:00',
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
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      category: category ?? this.category,
      start: start ?? this.start,
    );
  }
}

