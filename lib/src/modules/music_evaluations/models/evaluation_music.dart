class EvaluationMusicModel {
  const EvaluationMusicModel({
    required this.id,
    required this.title,
    required this.youtubeUrl,
    required this.order,
    this.artist,
  });

  final String id;
  final String title;
  final String? artist;
  final String youtubeUrl;
  final int order;

  factory EvaluationMusicModel.fromJson(Map<String, dynamic> json) {
    return EvaluationMusicModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString(),
      youtubeUrl: json['youtubeUrl']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (artist != null) 'artist': artist,
        'youtubeUrl': youtubeUrl,
        'order': order,
      };

  EvaluationMusicModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? youtubeUrl,
    int? order,
  }) {
    return EvaluationMusicModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      order: order ?? this.order,
    );
  }
}
