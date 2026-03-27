/// Enum representing the types of items in a liturgy
enum HolyricsItemType { song, bible, text, custom }

/// Represents an item in a liturgy that can be sent to Holyrics
class HolyricsItem {
  final String id;
  final String title;
  final HolyricsItemType type;
  final Map<String, dynamic> data;

  HolyricsItem({
    required this.id,
    required this.title,
    required this.type,
    required this.data,
  });

  /// Factory method to create from JSON (if needed for future expansion)
  factory HolyricsItem.fromJson(Map<String, dynamic> json) {
    return HolyricsItem(
      id: json['id'] as String,
      title: json['title'] as String,
      type: _itemTypeFromString(json['type'] as String),
      data: json['data'] as Map<String, dynamic>,
    );
  }

  /// Convert to JSON (if needed for future expansion)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': _itemTypeToString(type),
      'data': data,
    };
  }

  static HolyricsItemType _itemTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'song':
        return HolyricsItemType.song;
      case 'bible':
        return HolyricsItemType.bible;
      case 'text':
        return HolyricsItemType.text;
      case 'custom':
        return HolyricsItemType.custom;
      default:
        throw ArgumentError('Unknown item type: $type');
    }
  }

  static String _itemTypeToString(HolyricsItemType type) {
    switch (type) {
      case HolyricsItemType.song:
        return 'song';
      case HolyricsItemType.bible:
        return 'bible';
      case HolyricsItemType.text:
        return 'text';
      case HolyricsItemType.custom:
        return 'custom';
    }
  }
}
