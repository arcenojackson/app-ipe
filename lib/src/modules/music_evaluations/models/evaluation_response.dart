import 'package:cloud_firestore/cloud_firestore.dart';

class EvaluationResponseModel {
  const EvaluationResponseModel({
    required this.id,
    required this.formId,
    required this.userId,
    required this.userName,
    required this.musicId,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.comment,
  });

  final String id;
  final String formId;
  final String userId;
  final String userName;
  final String musicId;
  final int rating; // 0 a 5
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory EvaluationResponseModel.fromJson(Map<String, dynamic> json) {
    return EvaluationResponseModel(
      id: json['id']?.toString() ?? '',
      formId: json['formId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      musicId: json['musicId']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment']?.toString(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'formId': formId,
        'userId': userId,
        'userName': userName,
        'musicId': musicId,
        'rating': rating,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  EvaluationResponseModel copyWith({
    String? id,
    String? formId,
    String? userId,
    String? userName,
    String? musicId,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EvaluationResponseModel(
      id: id ?? this.id,
      formId: formId ?? this.formId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      musicId: musicId ?? this.musicId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
