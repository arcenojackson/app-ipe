import 'package:flutter/foundation.dart';

import '../data/forum_repository.dart';
import '../models/forum_logic.dart';
import '../models/forum_models.dart';

class ForumTopicController extends ChangeNotifier {
  ForumTopicController({
    required this.repository,
    required this.topicId,
    required this.viewer,
    required this.author,
  });

  final ForumRepository repository;
  final String topicId;
  final ForumViewer viewer;
  final ForumAuthor author;

  ForumTopic? topic;
  List<ForumComment> comments = [];
  final Map<String, int> myVotes = {};
  bool loading = true;
  bool error = false;
  bool notFound = false;
  bool sending = false;
  String? actionError;
  final Set<String> _voting = {};

  TopicPermissions? get permissions =>
      topic == null ? null : topicPermissions(topic!, viewer);

  CommentPermissions commentPerms(ForumComment c) =>
      commentPermissions(c, topic!, viewer);

  Future<void> load() async {
    loading = true;
    error = false;
    notifyListeners();
    try {
      final t = await repository.loadTopic(topicId);
      if (t == null) {
        notFound = true;
        loading = false;
        notifyListeners();
        return;
      }
      topic = t;
      final loaded = t.deleted && !topicPermissions(t, viewer).visibleBody
          ? <ForumComment>[]
          : await repository.loadComments(topicId);
      comments = loaded;
      myVotes.clear();
      final votes = await Future.wait(
        loaded
            .where((c) => c.authorUid != viewer.uid && !c.deleted)
            .map((c) async => MapEntry(
                  c.id,
                  await repository
                      .loadMyVote(topicId, c.id, viewer.uid)
                      .catchError((_) => null),
                )),
      );
      for (final v in votes) {
        if (v.value != null) myVotes[v.key] = v.value!;
      }
    } catch (_) {
      error = true;
    }
    loading = false;
    notifyListeners();
  }

  /// Voto otimista: tocar no mesmo voto remove; reverte se a gravação falhar.
  Future<void> vote(ForumComment c, int value) async {
    if (!commentPerms(c).canVote || !_voting.add(c.id)) return;
    final before = myVotes[c.id];
    final next = before == value ? null : value;
    final delta = (next ?? 0) - (before ?? 0);
    _setVote(c.id, next, delta);
    try {
      await repository.setVote(topicId, c.id, viewer.uid, next);
    } catch (e) {
      _setVote(c.id, before, -delta);
      actionError = _message(e);
      notifyListeners();
    } finally {
      _voting.remove(c.id);
    }
  }

  void _setVote(String id, int? value, int delta) {
    if (value == null) {
      myVotes.remove(id);
    } else {
      myVotes[id] = value;
    }
    comments = [
      for (final c in comments)
        if (c.id == id) c.copyWith(score: c.score + delta) else c,
    ];
    notifyListeners();
  }

  /// Devolve `true` se enviou; em erro o chamador mantém o texto digitado.
  Future<bool> submitComment(String body, ForumComment? parent) async {
    if (sending || topic == null || !permissions!.canComment) return false;
    final input = ForumCommentInput(body: body);
    final invalid = validateCommentInput(input);
    if (invalid != null) {
      actionError = invalid;
      notifyListeners();
      return false;
    }
    return _run(() async {
      await repository.createComment(topicId, input, author, parent);
      comments = await repository.loadComments(topicId);
    });
  }

  Future<bool> editComment(ForumComment c, String body) async {
    final input = ForumCommentInput(body: body, refs: c.refs);
    final invalid = validateCommentInput(input);
    if (invalid != null) {
      actionError = invalid;
      notifyListeners();
      return false;
    }
    return _run(() async {
      await repository.updateComment(topicId, c.id, input);
      comments = await repository.loadComments(topicId);
    });
  }

  Future<bool> deleteComment(ForumComment c) => _run(() async {
        await repository.setCommentDeleted(topicId, c.id);
        comments = await repository.loadComments(topicId);
      });

  Future<bool> togglePin() => _flag(pinned: !topic!.pinned);
  Future<bool> toggleLock() => _flag(locked: !topic!.locked);
  Future<bool> deleteTopic() => _flag(deleted: true);

  Future<bool> _flag({bool? pinned, bool? locked, bool? deleted}) =>
      _run(() async {
        await repository.setTopicFlags(topicId,
            pinned: pinned, locked: locked, deleted: deleted);
        topic = await repository.loadTopic(topicId) ?? topic;
      });

  Future<bool> _run(Future<void> Function() action) async {
    if (sending) return false;
    sending = true;
    actionError = null;
    notifyListeners();
    try {
      await action();
      sending = false;
      notifyListeners();
      return true;
    } catch (e) {
      actionError = _message(e);
      sending = false;
      notifyListeners();
      return false;
    }
  }

  String _message(Object e) {
    final text = e.toString();
    return text.contains('permission-denied')
        ? 'Sem permissão para esta ação.'
        : 'Não foi possível concluir. Tente de novo.';
  }

  void clearActionError() {
    actionError = null;
  }
}
