import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/notifications/services/teaching_notification_url.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_models.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/widgets/ref_card.dart';

void main() {
  test('comentário gravado pela web mantém as citações', () {
    // Mesmo formato de newCommentPayload do portal.
    final c = ForumComment.fromMap('t1', 'c1', {
      'body': 'Veja a aula',
      'authorUid': 'u1',
      'authorName': 'Ana',
      'parentId': null,
      'depth': 1,
      'refs': [
        {'kind': 'plan', 'id': 'l3', 'label': 'Aula 3 — Como interpretar a Bíblia?'},
        {'kind': 'library', 'id': 'd1', 'label': 'Catecismo.pdf'},
        {'kind': 'outro', 'id': 'x', 'label': 'ignorado'},
      ],
      'score': 0,
      'deleted': false,
    });
    expect(c, isNotNull);
    expect(c!.refs.map((r) => r.label),
        ['Aula 3 — Como interpretar a Bíblia?', 'Catecismo.pdf']);
  });

  testWidgets('RefCard mostra o rótulo da citação', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RefCard(ref: const ForumRef(kind: 'plan', id: 'l3', label: 'Aula 3')),
      ),
    ));
    expect(find.text('Aula 3'), findsOneWidget);
  });

  group('teachingPortalTopicUri', () {
    test('monta o endereço do tópico no portal', () {
      expect(teachingPortalTopicUri('abc_123-X').toString(),
          'https://ipe-ensino.vercel.app/ensino/forum/abc_123-X');
    });

    test('rejeita ids inválidos', () {
      expect(teachingPortalTopicUri(''), isNull);
      expect(teachingPortalTopicUri('a/b'), isNull);
      expect(teachingPortalTopicUri('a?x=1'), isNull);
      expect(teachingPortalTopicUri('../x'), isNull);
    });
  });
}
