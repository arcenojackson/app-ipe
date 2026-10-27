import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/forum_logic.dart';
import '../models/forum_models.dart';

const forumPageSize = 20;
const forumMaxComments = 500;

/// Estado da paginação: o último documento lido.
typedef TopicCursor = DocumentSnapshot<Map<String, dynamic>>;

class TopicPage {
  const TopicPage({required this.topics, required this.cursor, required this.done});
  final List<ForumTopic> topics;
  final TopicCursor? cursor;
  final bool done;
}

Map<String, dynamic> newTopicPayload(
  ForumTopicInput input,
  ForumAuthor author,
  Object ts,
) =>
    {
      'title': input.title.trim(),
      'body': input.body.trim(),
      'authorUid': author.uid,
      'authorName': author.name,
      'tagIds': input.tagIds,
      'refs': input.refs.map((r) => r.toMap()).toList(),
      'searchTokens': searchTokens(input.title),
      'pinned': false,
      'locked': false,
      'deleted': false,
      'commentCount': 0,
      'createdAt': ts,
      'updatedAt': ts,
      'lastActivityAt': ts,
    };

Map<String, dynamic> topicEditPatch(ForumTopicInput input, Object ts) => {
      'title': input.title.trim(),
      'body': input.body.trim(),
      'tagIds': input.tagIds,
      'refs': input.refs.map((r) => r.toMap()).toList(),
      'searchTokens': searchTokens(input.title),
      'updatedAt': ts,
      'editedAt': ts,
    };

Map<String, dynamic> newCommentPayload(
  ForumCommentInput input,
  ForumAuthor author,
  ForumComment? parent,
  Object ts,
) {
  if (parent != null && parent.depth >= forumMaxDepth) {
    throw ArgumentError('Respostas aceitam no máximo 3 níveis.');
  }
  return {
    'body': input.body.trim(),
    'authorUid': author.uid,
    'authorName': author.name,
    'parentId': parent?.id,
    'depth': parent == null ? 1 : parent.depth + 1,
    'refs': input.refs.map((r) => r.toMap()).toList(),
    'score': 0,
    'deleted': false,
    'createdAt': ts,
  };
}

Map<String, dynamic> commentEditPatch(ForumCommentInput input, Object ts) => {
      'body': input.body.trim(),
      'refs': input.refs.map((r) => r.toMap()).toList(),
      'editedAt': ts,
    };

class ForumRepository {
  ForumRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _topics =>
      _db.collection('forum_topics');
  CollectionReference<Map<String, dynamic>> _comments(String topicId) =>
      _topics.doc(topicId).collection('comments');

  List<ForumTopic> _toTopics(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) =>
      docs
          .map((d) => ForumTopic.fromMap(d.id, d.data()))
          .whereType<ForumTopic>()
          .toList();

  Query<Map<String, dynamic>> _filtered(
    Query<Map<String, dynamic>> q,
    TopicQuerySpec spec,
  ) {
    if (spec.tagId != null) q = q.where('tagIds', arrayContains: spec.tagId);
    if (spec.token != null) q = q.where('searchTokens', arrayContains: spec.token);
    return q;
  }

  /// Fixados (poucos), respeitando assunto/busca ativos.
  Future<List<ForumTopic>> loadPinned(TopicQuerySpec spec) async {
    final snap = await _filtered(
      _topics.where('deleted', isEqualTo: false).where('pinned', isEqualTo: true),
      spec,
    ).get();
    return _toTopics(snap.docs)
        .where((t) => forumTitleMatches(t.title, spec.words))
        .toList()
      ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
  }

  Future<TopicPage> loadPage(TopicQuerySpec spec, {TopicCursor? after}) async {
    final unfiltered = spec.tagId == null && spec.token == null;
    var q = _topics.where('deleted', isEqualTo: false);
    if (unfiltered) q = q.where('pinned', isEqualTo: false);
    var query = _filtered(q, spec).orderBy('lastActivityAt', descending: true);
    if (after != null) query = query.startAfterDocument(after);
    final snap = await query.limit(forumPageSize).get();
    final topics = _toTopics(snap.docs)
        .where((t) => !t.pinned && forumTitleMatches(t.title, spec.words))
        .toList();
    return TopicPage(
      topics: topics,
      cursor: snap.docs.isEmpty ? null : snap.docs.last,
      done: snap.docs.length < forumPageSize,
    );
  }

  Future<ForumTopic?> loadTopic(String id) async {
    final doc = await _topics.doc(id).get();
    final data = doc.data();
    return data == null ? null : ForumTopic.fromMap(doc.id, data);
  }

  Future<List<ForumComment>> loadComments(String topicId) async {
    final snap = await _comments(topicId)
        .orderBy('createdAt')
        .limit(forumMaxComments)
        .get();
    return snap.docs
        .map((d) => ForumComment.fromMap(topicId, d.id, d.data()))
        .whereType<ForumComment>()
        .toList();
  }

  DocumentReference<Map<String, dynamic>> _vote(
    String topicId,
    String commentId,
    String uid,
  ) =>
      _comments(topicId).doc(commentId).collection('votes').doc(uid);

  /// 1, -1 ou `null` (sem voto).
  Future<int?> loadMyVote(String topicId, String commentId, String uid) async {
    final value = (await _vote(topicId, commentId, uid).get()).data()?['value'];
    return value == 1 || value == -1 ? value as int : null;
  }

  Future<void> setVote(String topicId, String commentId, String uid, int? value) {
    final ref = _vote(topicId, commentId, uid);
    return value == null ? ref.delete() : ref.set({'value': value});
  }

  Future<String> createTopic(ForumTopicInput input, ForumAuthor author) async {
    final ref = await _topics
        .add(newTopicPayload(input, author, FieldValue.serverTimestamp()));
    return ref.id;
  }

  Future<void> updateTopic(String id, ForumTopicInput input) =>
      _topics.doc(id).update(topicEditPatch(input, FieldValue.serverTimestamp()));

  Future<void> createComment(
    String topicId,
    ForumCommentInput input,
    ForumAuthor author,
    ForumComment? parent,
  ) async {
    await _comments(topicId).add(
      newCommentPayload(input, author, parent, FieldValue.serverTimestamp()),
    );
  }

  Future<void> updateComment(
    String topicId,
    String commentId,
    ForumCommentInput input,
  ) =>
      _comments(topicId)
          .doc(commentId)
          .update(commentEditPatch(input, FieldValue.serverTimestamp()));

  Future<void> setTopicFlags(String id, {bool? pinned, bool? locked, bool? deleted}) {
    final patch = <String, dynamic>{
      if (pinned != null) 'pinned': pinned,
      if (locked != null) 'locked': locked,
      if (deleted != null) 'deleted': deleted,
    };
    return _topics.doc(id).update(patch);
  }

  Future<void> setCommentDeleted(String topicId, String commentId) =>
      _comments(topicId).doc(commentId).update({'deleted': true});

  /// Lê `teaching_tags` inteira (poucas dezenas) e filtra no cliente, como o portal.
  Future<List<SubjectTag>> loadSubjectTags() async {
    final snap = await _db.collection('teaching_tags').get();
    final tags = <MapEntry<int, SubjectTag>>[];
    for (final d in snap.docs) {
      final data = d.data();
      if (data['kind'] != 'subject' ||
          data['name'] is! String ||
          data['active'] == false) {
        continue;
      }
      final order = data['order'];
      tags.add(MapEntry(order is num ? order.toInt() : 0,
          SubjectTag(id: d.id, name: data['name'] as String)));
    }
    tags.sort((a, b) => a.key.compareTo(b.key));
    return tags.map((e) => e.value).toList();
  }
}
