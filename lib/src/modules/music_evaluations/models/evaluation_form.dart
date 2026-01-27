import 'package:cloud_firestore/cloud_firestore.dart';

import 'evaluation_category.dart';
import 'evaluation_music.dart';

enum EvaluationFormStatus {
  draft('draft', 'Rascunho'),
  active('active', 'Ativo'),
  closed('closed', 'Fechado');

  const EvaluationFormStatus(this.name, this.label);
  final String name;
  final String label;

  static EvaluationFormStatus? fromString(String? value) {
    if (value == null) return null;
    try {
      return EvaluationFormStatus.values.firstWhere(
        (e) => e.name == value,
      );
    } catch (e) {
      return null;
    }
  }
}

class EvaluationFormModel {
  const EvaluationFormModel({
    required this.id,
    required this.title,
    required this.category,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.allowedUserIds,
    required this.status,
    required this.musics,
    this.description,
  });

  final String id;
  final String title;
  final String? description;
  final EvaluationCategory category;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> allowedUserIds;
  final EvaluationFormStatus status;
  final List<EvaluationMusicModel> musics;

  factory EvaluationFormModel.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['category']?.toString() ?? '';
    final category = EvaluationCategory.fromString(categoryStr) ??
        EvaluationCategory.theological;

    final statusStr = json['status']?.toString() ?? 'draft';
    final status = EvaluationFormStatus.fromString(statusStr) ??
        EvaluationFormStatus.draft;

    final musicsData = json['musics'] as List<dynamic>? ?? [];
    final musics = musicsData
        .map((m) => EvaluationMusicModel.fromJson(m as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return EvaluationFormModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      category: category,
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      allowedUserIds: (json['allowedUserIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: status,
      musics: musics,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null && description!.isNotEmpty) 'description': description,
        'category': category.name,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'allowedUserIds': allowedUserIds,
        'status': status.name,
        'musics': musics.map((m) => m.toJson()).toList(),
      };

  EvaluationFormModel copyWith({
    String? id,
    String? title,
    String? description,
    EvaluationCategory? category,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? allowedUserIds,
    EvaluationFormStatus? status,
    List<EvaluationMusicModel>? musics,
  }) {
    return EvaluationFormModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      allowedUserIds: allowedUserIds ?? this.allowedUserIds,
      status: status ?? this.status,
      musics: musics ?? this.musics,
    );
  }
}
