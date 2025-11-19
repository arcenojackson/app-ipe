class MusicModel {
  const MusicModel({
    required this.id,
    required this.title,
    required this.artist,
    this.obs,
    this.youtube,
    required this.cipher,
    this.lyrics,
    this.bpm,
    this.tempo,
    required this.tone,
    this.minorTone = false,
    this.category = '',
  });

  final String id;
  final String title;
  final String artist;
  final String? obs;
  final String? youtube;
  final String cipher;
  final String? lyrics;
  final String? bpm;
  final String? tempo;
  final String tone;
  final bool minorTone;
  final String category;

  factory MusicModel.fromJson(Map<String, dynamic> json) {
    return MusicModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      obs: json['obs']?.toString(),
      youtube: json['youtube']?.toString(),
      cipher: json['cipher']?.toString() ?? '',
      lyrics: json['lyrics']?.toString(),
      bpm: json['bpm']?.toString(),
      tempo: json['tempo']?.toString(),
      tone: json['tone']?.toString() ?? '',
      minorTone:
          json['minorTone'] == true ||
          json['minor_tone'] == true ||
          json['minor_tone'] == 1,
      category: json['category']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'obs': obs,
    'youtube': youtube,
    'cipher': cipher,
    'lyrics': lyrics,
    'bpm': bpm,
    'tempo': tempo,
    'tone': tone,
    'minorTone': minorTone,
    'category': category,
  };

  MusicModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? obs,
    String? youtube,
    String? cipher,
    String? lyrics,
    String? bpm,
    String? tempo,
    String? tone,
    bool? minorTone,
    String? category,
  }) {
    return MusicModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      obs: obs ?? this.obs,
      youtube: youtube ?? this.youtube,
      cipher: cipher ?? this.cipher,
      lyrics: lyrics ?? this.lyrics,
      bpm: bpm ?? this.bpm,
      tempo: tempo ?? this.tempo,
      tone: tone ?? this.tone,
      minorTone: minorTone ?? this.minorTone,
      category: category ?? this.category,
    );
  }
}
