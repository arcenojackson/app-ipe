import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/data/forum_repository.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_models.dart';

const ts = 'AGORA';
const ana = ForumAuthor(uid: 'u1', name: 'Ana');

ForumComment parent(int depth) => ForumComment(
      id: 'p', topicId: 't', body: 'x', authorUid: 'u', authorName: '',
      parentId: null, depth: depth, refs: const [], score: 0, deleted: false,
      createdAt: DateTime(2026),
    );

void main() {
  test('tópico novo: moderação desligada, contador zero e tokens do título', () {
    final p = newTopicPayload(
        const ForumTopicInput(title: ' Aula três ', body: ' B ', tagIds: ['a']), ana, ts);
    expect(p['title'], 'Aula três');
    expect(p['body'], 'B');
    expect([p['pinned'], p['locked'], p['deleted'], p['commentCount']], [false, false, false, 0]);
    expect([p['createdAt'], p['updatedAt'], p['lastActivityAt']], [ts, ts, ts]);
    expect(p['searchTokens'], containsAll(['au', 'tres']));
  });

  test('comentário novo calcula profundidade e zera score', () {
    const input = ForumCommentInput(body: ' x ');
    final root = newCommentPayload(input, ana, null, ts);
    expect([root['parentId'], root['depth'], root['score'], root['body']], [null, 1, 0, 'x']);
    expect(newCommentPayload(input, ana, parent(2), ts)['depth'], 3);
    expect(() => newCommentPayload(input, ana, parent(3), ts), throwsArgumentError);
  });

  test('edição só carrega os campos editáveis', () {
    expect(
        topicEditPatch(const ForumTopicInput(title: 'abc', body: 'b'), ts).keys.toSet(),
        {'title', 'body', 'tagIds', 'refs', 'searchTokens', 'updatedAt', 'editedAt'});
    expect(commentEditPatch(const ForumCommentInput(body: ' x '), ts),
        {'body': 'x', 'refs': <Map<String, dynamic>>[], 'editedAt': ts});
  });
}
