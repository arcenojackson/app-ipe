/// URLs das imagens em diferentes tamanhos (resposta Pexels).
class PexelsPhotoSrc {
  const PexelsPhotoSrc({
    this.original,
    this.large,
    this.large2x,
    this.medium,
    this.small,
    this.portrait,
    this.landscape,
    this.tiny,
  });

  final String? original;
  final String? large;
  final String? large2x;
  final String? medium;
  final String? small;
  final String? portrait;
  final String? landscape;
  final String? tiny;

  factory PexelsPhotoSrc.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PexelsPhotoSrc();
    return PexelsPhotoSrc(
      original: json['original']?.toString(),
      large: json['large']?.toString(),
      large2x: json['large2x']?.toString(),
      medium: json['medium']?.toString(),
      small: json['small']?.toString(),
      portrait: json['portrait']?.toString(),
      landscape: json['landscape']?.toString(),
      tiny: json['tiny']?.toString(),
    );
  }

  /// URL portrait (800x1200) para arte vertical; fallback para medium/large.
  String get displayUrl => portrait ?? medium ?? large ?? original ?? '';
}

/// Foto retornada pela API Pexels (recurso Photo).
class PexelsPhoto {
  const PexelsPhoto({
    required this.id,
    required this.src,
    this.url = '',
    this.photographer,
    this.alt,
  });

  final int id;
  final PexelsPhotoSrc src;
  final String url;
  final String? photographer;
  final String? alt;

  factory PexelsPhoto.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PexelsPhoto(id: 0, src: PexelsPhotoSrc());
    }
    return PexelsPhoto(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      src: PexelsPhotoSrc.fromJson(json['src'] as Map<String, dynamic>?),
      url: json['url']?.toString() ?? '',
      photographer: json['photographer']?.toString(),
      alt: json['alt']?.toString(),
    );
  }

  /// URL adequada para fundo (portrait para arte vertical).
  String get imageUrl => src.displayUrl;
}

/// Resposta paginada da busca de fotos (GET /v1/search).
class PexelsSearchResponse {
  const PexelsSearchResponse({
    this.page = 1,
    this.perPage = 30,
    this.photos = const [],
    this.nextPage,
  });

  final int page;
  final int perPage;
  final List<PexelsPhoto> photos;
  final String? nextPage;

  factory PexelsSearchResponse.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PexelsSearchResponse();
    final photosList = json['photos'];
    final list = <PexelsPhoto>[];
    if (photosList is List) {
      for (final e in photosList) {
        if (e is Map<String, dynamic>) list.add(PexelsPhoto.fromJson(e));
      }
    }
    return PexelsSearchResponse(
      page: json['page'] is int ? json['page'] as int : int.tryParse(json['page']?.toString() ?? '1') ?? 1,
      perPage: json['per_page'] is int ? json['per_page'] as int : int.tryParse(json['per_page']?.toString() ?? '30') ?? 30,
      photos: list,
      nextPage: json['next_page']?.toString(),
    );
  }

  bool get hasNextPage => nextPage != null && nextPage!.isNotEmpty;
}
