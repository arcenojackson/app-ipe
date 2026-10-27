import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_logic.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/forum_list_controller.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/forum_topic_controller.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_models.dart';

import 'fake_forum_repository.dart';

const me = ForumViewer(uid: 'me');
const author = ForumAuthor(uid: 'me', name: 'Eu');

void main() {
  group('lista: puxar para atualizar', () {
    test('recarrega a primeira página mantendo o filtro, sem duplicar', () async {
      final repo = FakeForumRepository()..pages = [fakeTopic('a'), fakeTopic('b')];
      final c = ForumListController(repository: repo);
      await c.load();
      await c.setTagId('fe');
      repo.pages = [fakeTopic('a'), fakeTopic('b'), fakeTopic('c')];
      expect(await c.refresh(), true);
      expect(c.tagId, 'fe');
      expect(repo.specs.last.tagId, 'fe');
      expect(c.topics.map((t) => t.id), ['a', 'b', 'c']);
      expect(c.error, false);
    });

    test('mantém a busca atual', () async {
      final repo = FakeForumRepository()..pages = [fakeTopic('a')];
      final c = ForumListController(repository: repo);
      await c.setSearch('Graça');
      expect(await c.refresh(), true);
      expect(c.search, 'Graça');
      expect(repo.specs.last.token, 'graca');
    });

    test('erro de rede mantém o conteúdo já exibido e devolve false', () async {
      final repo = FakeForumRepository()..pages = [fakeTopic('a'), fakeTopic('b')];
      final c = ForumListController(repository: repo);
      await c.load();
      repo.failLoad = true;
      expect(await c.refresh(), false);
      expect(c.topics.map((t) => t.id), ['a', 'b']);
      expect(c.error, false);
      expect(c.loading, false);
    });
  });

  group('tópico: puxar para atualizar', () {
    ForumTopicController make(FakeForumRepository repo) => ForumTopicController(
        repository: repo, topicId: 't', viewer: me, author: author);

    test('relê tópico, comentários e meus votos', () async {
      final repo = FakeForumRepository()
        ..topic = fakeTopic('t')
        ..comments = [fakeComment('c1')]
        ..votes = {'c1': 1};
      final c = make(repo);
      await c.load();
      repo.comments = [fakeComment('c1'), fakeComment('c2')];
      repo.votes = {'c1': -1, 'c2': 1};
      expect(await c.refresh(), true);
      expect(c.comments.map((x) => x.id), ['c1', 'c2']);
      expect(c.myVotes, {'c1': -1, 'c2': 1});
    });

    test('erro mantém o conteúdo e avisa por actionError', () async {
      final repo = _FailingRepo()
        ..topic = fakeTopic('t')
        ..comments = [fakeComment('c1')];
      final c = make(repo);
      await c.load();
      repo.fail = true;
      expect(await c.refresh(), false);
      expect(c.comments.map((x) => x.id), ['c1']);
      expect(c.topic, isNotNull);
      expect(c.error, false);
      expect(c.actionError, isNotNull);
    });
  });
}

class _FailingRepo extends FakeForumRepository {
  bool fail = false;

  @override
  Future<List<ForumComment>> loadComments(String topicId) async {
    if (fail) throw Exception('rede');
    return super.loadComments(topicId);
  }
}
