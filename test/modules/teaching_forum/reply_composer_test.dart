import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_logic.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_models.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/widgets/comment_composer.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/widgets/comment_tile.dart';

import 'fake_forum_repository.dart';

void main() {
  testWidgets('Responder pede o composer de resposta e não abre campo no meio da lista',
      (t) async {
    ForumComment? asked;
    final comment = fakeComment('c1');
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CommentTile(
            node: CommentNode(comment),
            perms: (_) => const CommentPermissions(
                canReply: true, canVote: true, canEdit: false, canDelete: false),
            myVotes: const {},
            onVote: (_, __) {},
            onReply: (c) => asked = c,
            onEdit: (_, __) async => true,
            onDelete: (_) async {},
          ),
        ),
      ),
    ));
    await t.tap(find.text('Responder'));
    await t.pump();
    expect(asked?.id, 'c1');
    expect(find.byType(CommentComposer), findsNothing);
  });

  testWidgets('trocar de modo preserva os dois rascunhos', (t) async {
    var replying = false;
    late StateSetter set;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          set = setState;
          return Column(children: [
            Offstage(
              offstage: replying,
              child: CommentComposer(
                key: const ValueKey('topic'),
                header: const Text('Novo comentário'),
                onSubmit: (_, __) async => true,
              ),
            ),
            if (replying)
              CommentComposer(
                key: const ValueKey('reply'),
                submitLabel: 'Responder',
                header: const Text('Respondendo a Bia'),
                onCancel: () => set(() => replying = false),
                onSubmit: (_, __) async => true,
              ),
          ]);
        }),
      ),
    ));
    await t.enterText(find.byType(TextField), 'rascunho do tópico');
    set(() => replying = true);
    await t.pump();
    expect(find.text('Respondendo a Bia'), findsOneWidget);
    expect(find.text('Responder'), findsOneWidget);
    expect(find.text('Enviar'), findsNothing); // o do tópico está oculto
    await t.tap(find.text('Cancelar'));
    await t.pump();
    expect(find.text('rascunho do tópico'), findsOneWidget);
  });
}
