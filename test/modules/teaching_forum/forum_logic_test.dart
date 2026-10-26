import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_logic.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_models.dart';

ForumTopic topic({
  String authorUid = 'u1',
  bool locked = false,
  bool deleted = false,
}) =>
    ForumTopic(
      id: 't', title: 'Título', body: 'Corpo', authorUid: authorUid,
      authorName: 'Ana', tagIds: const [], refs: const [], pinned: false,
      locked: locked, deleted: deleted, commentCount: 0,
      createdAt: DateTime(2026), lastActivityAt: DateTime(2026),
    );

ForumComment comment({
  String id = 'c',
  String authorUid = 'u2',
  String? parentId,
  int depth = 1,
  bool deleted = false,
  int createdAt = 1,
}) =>
    ForumComment(
      id: id, topicId: 't', body: 'Oi', authorUid: authorUid, authorName: 'Bia',
      parentId: parentId, depth: depth, refs: const [], score: 0,
      deleted: deleted, createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );

ForumViewer viewer(String uid, {bool curator = false, bool admin = false}) =>
    ForumViewer(uid: uid, isCurator: curator, isAdmin: admin);

void main() {
  group('conversores', () {
    test('fromMap ignora documentos incompletos', () {
      final t = ForumTopic.fromMap('a', {
        'title': 'T', 'body': 'B', 'authorUid': 'u', 'tagIds': ['x', 1],
        'pinned': true,
        'refs': [
          {'kind': 'library', 'id': '1', 'label': 'Doc'},
          {'kind': 'x', 'id': '1', 'label': 'L'},
        ],
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(5),
      });
      expect(t!.tagIds, ['x']);
      expect(t.pinned, true);
      expect(t.refs, hasLength(1));
      expect(t.commentCount, 0);
      expect(ForumTopic.fromMap('b', {'title': 'T'}), isNull);
    });

    test('comentário exige profundidade 1 a 3 e autor', () {
      expect(
          ForumComment.fromMap('t', 'c',
              {'body': 'B', 'authorUid': 'u', 'depth': 2, 'parentId': 'p'})!
              .depth,
          2);
      expect(ForumComment.fromMap('t', 'c', {'body': 'B', 'authorUid': 'u', 'depth': 4}), isNull);
      expect(ForumComment.fromMap('t', 'c', {'body': 'B', 'depth': 1}), isNull);
    });
  });

  group('validação', () {
    ForumTopicInput ok({String? title, String? body, List<String>? tags}) =>
        ForumTopicInput(title: title ?? 'abc', body: body ?? 'x', tagIds: tags ?? []);

    test('aceita os limites exatos', () {
      expect(validateTopicInput(ok(title: 'x' * 120, body: 'y' * 5000, tags: ['a', 'b', 'c'])), isNull);
      expect(validateTopicInput(ok()), isNull);
    });

    test('rejeita fora dos limites', () {
      expect(validateTopicInput(ok(title: 'ab')), contains('título'));
      expect(validateTopicInput(ok(title: ' a ')), contains('título'));
      expect(validateTopicInput(ok(title: 'x' * 121)), contains('título'));
      expect(validateTopicInput(ok(body: '  ')), contains('mensagem'));
      expect(validateTopicInput(ok(body: 'y' * 5001)), contains('mensagem'));
      expect(validateTopicInput(ok(tags: ['a', 'b', 'c', 'd'])), contains('assuntos'));
      const ref = ForumRef(kind: 'library', id: '1', label: 'Doc');
      expect(
          validateTopicInput(const ForumTopicInput(
              title: 'abc', body: 'x', refs: [ref, ref, ref, ref])),
          contains('Cite'));
      expect(validateCommentInput(const ForumCommentInput(body: '')), contains('mensagem'));
      expect(validateCommentInput(const ForumCommentInput(body: 'ok')), isNull);
    });
  });

  test('árvore aninha, ordena por data e põe órfãos na raiz', () {
    final tree = buildCommentTree([
      comment(id: 'b', createdAt: 3),
      comment(id: 'a', createdAt: 1),
      comment(id: 'a1', parentId: 'a', depth: 2, createdAt: 2),
      comment(id: 'a11', parentId: 'a1', depth: 3, createdAt: 4),
      comment(id: 'orf', parentId: 'sumiu', depth: 2, createdAt: 5),
    ]);
    expect(tree.map((n) => n.comment.id), ['a', 'b', 'orf']);
    expect(tree[0].children[0].comment.id, 'a1');
    expect(tree[0].children[0].children[0].comment.id, 'a11');
  });

  group('permissões', () {
    test('comentário: autor edita e apaga; moderador só apaga; outro nada', () {
      final c = comment();
      var p = commentPermissions(c, topic(), viewer('u2'));
      expect([p.canEdit, p.canDelete, p.canVote], [true, true, false]);
      p = commentPermissions(c, topic(), viewer('u3', curator: true));
      expect([p.canEdit, p.canDelete, p.canVote], [false, true, true]);
      p = commentPermissions(c, topic(), viewer('u4', admin: true));
      expect([p.canEdit, p.canDelete], [false, true]);
      p = commentPermissions(c, topic(), viewer('u5'));
      expect([p.canEdit, p.canDelete, p.canVote], [false, false, true]);
    });

    test('não responde nem vota em nível 3, removido, trancado ou removido', () {
      expect(commentPermissions(comment(depth: 3), topic(), viewer('u5')).canReply, false);
      expect(commentPermissions(comment(depth: 2), topic(), viewer('u5')).canReply, true);
      final dead = commentPermissions(comment(deleted: true), topic(), viewer('u5'));
      expect([dead.canReply, dead.canVote, dead.canEdit, dead.canDelete],
          [false, false, false, false]);
      for (final t in [topic(locked: true), topic(deleted: true)]) {
        final p = commentPermissions(comment(), t, viewer('u5'));
        expect([p.canReply, p.canVote], [false, false]);
      }
    });

    test('tópico: só moderador fixa e tranca; corpo removido só autor/moderador', () {
      var p = topicPermissions(topic(), viewer('u5'));
      expect([p.canPin, p.canLock, p.canComment], [false, false, true]);
      p = topicPermissions(topic(), viewer('u9', curator: true));
      expect([p.canPin, p.canLock, p.canDelete], [true, true, true]);
      p = topicPermissions(topic(), viewer('u1'));
      expect([p.canEdit, p.canDelete, p.canPin], [true, true, false]);
      final gone = topic(deleted: true);
      expect(topicPermissions(gone, viewer('u5')).visibleBody, false);
      expect(topicPermissions(gone, viewer('u1')).visibleBody, true);
      expect(topicPermissions(gone, viewer('u9', admin: true)).visibleBody, true);
      expect(topicPermissions(topic(locked: true), viewer('u5')).canComment, false);
    });
  });

  test('linkify: só http(s) vira link e a pontuação final fica de fora', () {
    expect(linkify('veja https://a.com/x, e <script>alert(1)</script>'), [
      const LinkSegment('veja ', isLink: false),
      const LinkSegment('https://a.com/x', isLink: true),
      const LinkSegment(', e <script>alert(1)</script>', isLink: false),
    ]);
    expect(linkify('javascript:alert(1)'),
        [const LinkSegment('javascript:alert(1)', isLink: false)]);
    expect(linkify(''), isEmpty);
  });

  group('busca', () {
    test('assunto e busca são exclusivos', () {
      expect(() => topicQueryFrom(tagId: 'assunto-fe', search: 'graça'), throwsArgumentError);
      final q = topicQueryFrom(tagId: 'assunto-fe', search: '  ');
      expect([q.tagId, q.token, q.words], ['assunto-fe', null, <String>[]]);
    });

    test('usa a palavra mais longa, sem acento, até 20 letras', () {
      final q = topicQueryFrom(search: 'A Graça de Deus');
      expect(q.token, 'graca');
      expect(q.words, ['graca', 'de', 'deus']);
      expect(topicQueryFrom(search: 'x' * 30).token, 'x' * 20);
      expect(topicQueryFrom().token, isNull);
    });

    test('searchTokens traz prefixos sem acento', () {
      final t = searchTokens('Aula três');
      expect(t, containsAll(['au', 'tres']));
      expect(t, isNot(contains('t')));
    });

    test('forumTitleMatches confere todas as palavras por prefixo', () {
      expect(forumTitleMatches('A Graça de Deus', ['gra', 'de']), true);
      expect(forumTitleMatches('A Graça de Deus', ['gra', 'xx']), false);
      expect(forumTitleMatches('Qualquer', []), true);
    });
  });
}
