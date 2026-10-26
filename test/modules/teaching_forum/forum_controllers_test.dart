import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_logic.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_models.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/forum_editor_controller.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/forum_list_controller.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/forum_topic_controller.dart';

import 'fake_forum_repository.dart';

const me = ForumViewer(uid: 'me');
const author = ForumAuthor(uid: 'me', name: 'Eu');

void main() {
  group('lista', () {
    test('carrega fixados e a primeira página; busca limpa o assunto', () async {
      final repo = FakeForumRepository()
        ..pinned = [fakeTopic('p', pinned: true)]
        ..pages = [fakeTopic('a'), fakeTopic('b')];
      final c = ForumListController(repository: repo);
      await c.load();
      expect(c.pinned.map((t) => t.id), ['p']);
      expect(c.topics.map((t) => t.id), ['a', 'b']);
      await c.setTagId('fe');
      expect(repo.specs.last.tagId, 'fe');
      await c.setSearch('Graça');
      expect(c.tagId, isNull);
      expect(repo.specs.last.token, 'graca');
      await c.setTagId('fe');
      expect(c.search, '');
    });

    test('erro de rede vira estado de erro e tentar de novo recupera', () async {
      final repo = FakeForumRepository()..failLoad = true;
      final c = ForumListController(repository: repo);
      await c.load();
      expect(c.error, true);
      repo.failLoad = false;
      await c.load();
      expect(c.error, false);
    });

    test('loadMore não faz nada quando acabou', () async {
      final repo = FakeForumRepository()..pages = [fakeTopic('a')];
      final c = ForumListController(repository: repo);
      await c.load();
      expect(c.done, true);
      await c.loadMore();
      expect(c.topics, hasLength(1));
    });
  });

  group('tópico', () {
    ForumTopicController make(FakeForumRepository repo) => ForumTopicController(
        repository: repo, topicId: 't', viewer: me, author: author);

    test('voto otimista, trocar, remover e reverter em erro', () async {
      final repo = FakeForumRepository()
        ..topic = fakeTopic('t')
        ..comments = [fakeComment('c1', score: 2)];
      final c = make(repo);
      await c.load();
      await c.vote(c.comments.first, 1);
      expect(c.comments.first.score, 3);
      expect(c.myVotes['c1'], 1);
      await c.vote(c.comments.first, -1); // troca: 3 - 1 - 1
      expect(c.comments.first.score, 1);
      await c.vote(c.comments.first, -1); // remove
      expect(c.comments.first.score, 2);
      expect(c.myVotes.containsKey('c1'), false);
      expect(repo.voteWrites, [1, -1, null]);
      repo.failVote = true;
      await c.vote(c.comments.first, 1);
      expect(c.comments.first.score, 2);
      expect(c.actionError, isNotNull);
    });

    test('não vota no próprio comentário nem em tópico trancado', () async {
      final repo = FakeForumRepository()
        ..topic = fakeTopic('t')
        ..comments = [fakeComment('mine', author: 'me')];
      final c = make(repo);
      await c.load();
      await c.vote(c.comments.first, 1);
      expect(repo.voteWrites, isEmpty);
      repo.topic = fakeTopic('t', locked: true);
      repo.comments = [fakeComment('c2')];
      await c.load();
      await c.vote(c.comments.first, 1);
      expect(repo.voteWrites, isEmpty);
    });

    test('carrega meu voto existente', () async {
      final repo = FakeForumRepository()
        ..topic = fakeTopic('t')
        ..comments = [fakeComment('c1')]
        ..votes = {'c1': -1};
      final c = make(repo);
      await c.load();
      expect(c.myVotes['c1'], -1);
    });

    test('comentário: valida, envia e devolve falso em erro', () async {
      final repo = FakeForumRepository()..topic = fakeTopic('t');
      final c = make(repo);
      await c.load();
      expect(await c.submitComment('  ', null), false);
      expect(await c.submitComment('olá', null), true);
      expect(repo.createdComments, ['olá']);
      repo.failWrite = true;
      expect(await c.submitComment('de novo', null), false);
      expect(c.sending, false);
    });

    test('tópico inexistente marca notFound', () async {
      final c = make(FakeForumRepository());
      await c.load();
      expect(c.notFound, true);
    });
  });

  group('editor', () {
    test('valida, limita assuntos e cria uma vez', () async {
      final repo = FakeForumRepository();
      final c = ForumEditorController(repository: repo, author: author);
      expect(await c.save('ab', 'x'), isNull);
      expect(c.error, contains('título'));
      expect([c.toggleTag('a'), c.toggleTag('b'), c.toggleTag('c')], [true, true, true]);
      expect(c.toggleTag('d'), false);
      final results = await Future.wait([c.save('Título', 'Corpo'), c.save('Título', 'Corpo')]);
      expect(results.where((r) => r == 'novo'), hasLength(1));
      expect(repo.created, hasLength(1));
    });

    test('edição preserva citações e erro mantém o estado', () async {
      final repo = FakeForumRepository();
      const ref = ForumRef(kind: 'library', id: '1', label: 'Doc');
      final editing = ForumTopic(
        id: 'e', title: 'T', body: 'B', authorUid: 'me', authorName: 'Eu',
        tagIds: const ['fe'], refs: const [ref], pinned: false, locked: false,
        deleted: false, commentCount: 0, createdAt: DateTime(2026),
        lastActivityAt: DateTime(2026),
      );
      final c = ForumEditorController(repository: repo, author: author, editing: editing);
      expect(c.selectedTags, {'fe'});
      repo.failWrite = true;
      expect(await c.save('Título novo', 'Corpo'), isNull);
      expect(c.error, isNotNull);
      expect(c.saving, false);
      repo.failWrite = false;
      expect(await c.save('Título novo', 'Corpo'), 'e');
    });
  });
}
