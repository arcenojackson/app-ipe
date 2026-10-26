import 'package:cloud_firestore/cloud_firestore.dart';

const forumMaxDepth = 3;

/// Citação de um documento da Biblioteca ou de uma aula do Plano.
class ForumRef {
  const ForumRef({required this.kind, required this.id, required this.label});

  final String kind;
  final String id;
  final String label;

  static ForumRef? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'];
    final id = raw['id'];
    final label = raw['label'];
    if ((kind != 'library' && kind != 'plan') ||
        id is! String ||
        id.isEmpty ||
        label is! String) {
      return null;
    }
    return ForumRef(kind: kind as String, id: id, label: label);
  }

  Map<String, dynamic> toMap() => {'kind': kind, 'id': id, 'label': label};
}

DateTime _date(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _optDate(Object? raw) =>
    (raw is Timestamp || raw is DateTime) ? _date(raw) : null;

List<ForumRef> _refs(Object? raw) => raw is List
    ? raw.map(ForumRef.fromMap).whereType<ForumRef>().toList()
    : <ForumRef>[];

class ForumTopic {
  const ForumTopic({
    required this.id,
    required this.title,
    required this.body,
    required this.authorUid,
    required this.authorName,
    required this.tagIds,
    required this.refs,
    required this.pinned,
    required this.locked,
    required this.deleted,
    required this.commentCount,
    required this.createdAt,
    required this.lastActivityAt,
    this.editedAt,
  });

  final String id;
  final String title;
  final String body;
  final String authorUid;
  final String authorName;
  final List<String> tagIds;
  final List<ForumRef> refs;
  final bool pinned;
  final bool locked;
  final bool deleted;
  final int commentCount;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  final DateTime? editedAt;

  /// Documento incompleto resulta em `null` (é ignorado pela tela).
  static ForumTopic? fromMap(String id, Map<String, dynamic> data) {
    final title = data['title'];
    final body = data['body'];
    final authorUid = data['authorUid'];
    if (title is! String || body is! String || authorUid is! String) {
      return null;
    }
    final tags = data['tagIds'];
    final count = data['commentCount'];
    return ForumTopic(
      id: id,
      title: title,
      body: body,
      authorUid: authorUid,
      authorName: data['authorName'] is String ? data['authorName'] as String : '',
      tagIds: tags is List ? tags.whereType<String>().toList() : <String>[],
      refs: _refs(data['refs']),
      pinned: data['pinned'] == true,
      locked: data['locked'] == true,
      deleted: data['deleted'] == true,
      commentCount: count is num ? count.toInt() : 0,
      createdAt: _date(data['createdAt']),
      lastActivityAt: _date(data['lastActivityAt'] ?? data['createdAt']),
      editedAt: _optDate(data['editedAt']),
    );
  }
}

class ForumComment {
  const ForumComment({
    required this.id,
    required this.topicId,
    required this.body,
    required this.authorUid,
    required this.authorName,
    required this.parentId,
    required this.depth,
    required this.refs,
    required this.score,
    required this.deleted,
    required this.createdAt,
    this.editedAt,
  });

  final String id;
  final String topicId;
  final String body;
  final String authorUid;
  final String authorName;
  final String? parentId;
  final int depth;
  final List<ForumRef> refs;
  final int score;
  final bool deleted;
  final DateTime createdAt;
  final DateTime? editedAt;

  ForumComment copyWith({int? score}) => ForumComment(
        id: id,
        topicId: topicId,
        body: body,
        authorUid: authorUid,
        authorName: authorName,
        parentId: parentId,
        depth: depth,
        refs: refs,
        score: score ?? this.score,
        deleted: deleted,
        createdAt: createdAt,
        editedAt: editedAt,
      );

  static ForumComment? fromMap(
    String topicId,
    String id,
    Map<String, dynamic> data,
  ) {
    final body = data['body'];
    final authorUid = data['authorUid'];
    final depth = data['depth'];
    if (body is! String ||
        authorUid is! String ||
        depth is! num ||
        depth < 1 ||
        depth > forumMaxDepth) {
      return null;
    }
    final score = data['score'];
    final parent = data['parentId'];
    return ForumComment(
      id: id,
      topicId: topicId,
      body: body,
      authorUid: authorUid,
      authorName: data['authorName'] is String ? data['authorName'] as String : '',
      parentId: parent is String ? parent : null,
      depth: depth.toInt(),
      refs: _refs(data['refs']),
      score: score is num ? score.toInt() : 0,
      deleted: data['deleted'] == true,
      createdAt: _date(data['createdAt']),
      editedAt: _optDate(data['editedAt']),
    );
  }
}

class ForumAuthor {
  const ForumAuthor({required this.uid, required this.name});
  final String uid;
  final String name;
}

class ForumTopicInput {
  const ForumTopicInput({
    required this.title,
    required this.body,
    this.tagIds = const [],
    this.refs = const [],
  });
  final String title;
  final String body;
  final List<String> tagIds;
  final List<ForumRef> refs;
}

class ForumCommentInput {
  const ForumCommentInput({required this.body, this.refs = const []});
  final String body;
  final List<ForumRef> refs;
}

class SubjectTag {
  const SubjectTag({required this.id, required this.name});
  final String id;
  final String name;
}
