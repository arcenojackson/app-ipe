class YoutubeSearchResult {
  YoutubeSearchResult({
    required this.id,
    required this.title,
    required this.thumbnail,
  });

  final String id;
  final String title;
  final String thumbnail;

  factory YoutubeSearchResult.fromJson(Map<String, dynamic> json) {
    return YoutubeSearchResult(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnail: json['image']?.toString() ?? '',
    );
  }
}
