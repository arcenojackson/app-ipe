import 'package:flutter/foundation.dart';

import '../data/forum_repository.dart';
import '../models/forum_logic.dart';
import '../models/forum_models.dart';

class ForumListController extends ChangeNotifier {
  ForumListController({required this.repository});

  final ForumRepository repository;

  List<ForumTopic> pinned = [];
  List<ForumTopic> topics = [];
  List<SubjectTag> tags = [];
  String? tagId;
  String search = '';
  bool loading = false;
  bool loadingMore = false;
  bool done = false;
  bool error = false;
  TopicCursor? _cursor;
  int _generation = 0;

  TopicQuerySpec get _spec => topicQueryFrom(tagId: tagId, search: search);

  Future<void> loadTags() async {
    try {
      tags = await repository.loadSubjectTags();
      notifyListeners();
    } catch (_) {
      // Sem assuntos o filtro some; a lista continua funcionando.
    }
  }

  /// Assunto e busca são exclusivos: definir um limpa o outro.
  Future<void> setTagId(String? id) {
    tagId = id;
    search = '';
    return load();
  }

  Future<void> setSearch(String text) {
    search = text;
    tagId = null;
    return load();
  }

  Future<void> load() async {
    await _reload(keepOnError: false);
  }

  /// Puxar para atualizar: recarrega a primeira página com o filtro e a busca
  /// atuais. Em erro mantém o que já está na tela e devolve `false`.
  Future<bool> refresh() => _reload(keepOnError: true);

  Future<bool> _reload({required bool keepOnError}) async {
    final generation = ++_generation;
    loading = true;
    if (!keepOnError) error = false;
    notifyListeners();
    try {
      final spec = _spec;
      final results = await Future.wait([
        repository.loadPinned(spec),
        repository.loadPage(spec),
      ]);
      if (generation != _generation) return false;
      error = false;
      loadingMore = false;
      pinned = results[0] as List<ForumTopic>;
      final page = results[1] as TopicPage;
      topics = page.topics;
      _cursor = page.cursor;
      done = page.done;
    } catch (_) {
      if (generation != _generation) return false;
      loading = false;
      if (!keepOnError) error = true;
      notifyListeners();
      return false;
    }
    loading = false;
    notifyListeners();
    return true;
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || done || _cursor == null) return;
    final generation = _generation;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await repository.loadPage(_spec, after: _cursor);
      if (generation != _generation) return;
      topics = [...topics, ...page.topics];
      _cursor = page.cursor ?? _cursor;
      done = page.done;
    } catch (_) {
      error = true;
    }
    loadingMore = false;
    notifyListeners();
  }
}
