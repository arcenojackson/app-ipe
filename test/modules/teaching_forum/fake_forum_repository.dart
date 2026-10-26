import 'package:ipe_flutter/src/modules/teaching_forum/data/forum_repository.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_logic.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_models.dart';

ForumTopic fakeTopic(String id, {bool locked = false, bool pinned = false, String author = 'u1'}) =>
    ForumTopic(
      id: id, title: 'Tópico $id', body: 'Corpo', authorUid: author,
      authorName: 'Ana', tagIds: const [], refs: const [], pinned: pinned,
      locked: locked, deleted: false, commentCount: 0,
      createdAt: DateTime(2026), lastActivityAt: DateTime(2026),
    );

ForumComment fakeComment(String id, {String author = 'u2', int score = 0, int depth = 1, String? parent}) =>
    ForumComment(
      id: id, topicId: 't', body: 'Oi', authorUid: author, authorName: 'Bia',
      parentId: parent, depth: depth, refs: const [], score: score,
      deleted: false, createdAt: DateTime.fromMillisecondsSinceEpoch(1),
    );

class FakeForumRepository extends ForumRepository {
  List<ForumTopic> pinned = [];
  List<ForumTopic> pages = [];
  bool pageDone = true;
  ForumTopic? topic;
  List<ForumComment> comments = [];
  Map<String, int> votes = {};
  bool failVote = false;
  bool failWrite = false;
  bool failLoad = false;
  final created = <ForumTopicInput>[];
  final createdComments = <String>[];
  final specs = <TopicQuerySpec>[];
  final voteWrites = <int?>[];

  @override
  Future<List<ForumTopic>> loadPinned(TopicQuerySpec spec) async {
    specs.add(spec);
    if (failLoad) throw Exception('rede');
    return pinned;
  }

  @override
  Future<TopicPage> loadPage(TopicQuerySpec spec, {TopicCursor? after}) async {
    if (failLoad) throw Exception('rede');
    return TopicPage(topics: pages, cursor: null, done: pageDone);
  }

  @override
  Future<List<SubjectTag>> loadSubjectTags() async =>
      const [SubjectTag(id: 'fe', name: 'Fé')];

  @override
  Future<ForumTopic?> loadTopic(String id) async => topic;

  @override
  Future<List<ForumComment>> loadComments(String topicId) async => comments;

  @override
  Future<int?> loadMyVote(String topicId, String commentId, String uid) async =>
      votes[commentId];

  @override
  Future<void> setVote(String topicId, String commentId, String uid, int? value) async {
    if (failVote) throw Exception('permission-denied');
    voteWrites.add(value);
  }

  @override
  Future<String> createTopic(ForumTopicInput input, ForumAuthor author) async {
    if (failWrite) throw Exception('rede');
    created.add(input);
    return 'novo';
  }

  @override
  Future<void> updateTopic(String id, ForumTopicInput input) async {
    if (failWrite) throw Exception('rede');
  }

  @override
  Future<void> createComment(String topicId, ForumCommentInput input,
      ForumAuthor author, ForumComment? parent) async {
    if (failWrite) throw Exception('rede');
    createdComments.add(input.body);
  }
}
