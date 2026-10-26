import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/auth/models/user.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/data/forum_repository.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/teaching_access.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/teaching_home_page.dart';
import 'package:provider/provider.dart';

import 'fake_forum_repository.dart';

UserModel user({
  TeachingRole role = TeachingRole.none,
  bool admin = false,
  bool pending = false,
}) =>
    UserModel(
      id: 'u', name: 'N', email: 'e@e.com', isAdmin: admin, isPending: pending,
      teachingRole: role,
    );

void main() {
  test('só professor e curador não pendentes usam a plataforma', () {
    expect(canUseTeachingForum(user(role: TeachingRole.teacher)), true);
    expect(canUseTeachingForum(user(role: TeachingRole.curator)), true);
    expect(canUseTeachingForum(user(role: TeachingRole.teacher, admin: true)), true);
    expect(canUseTeachingForum(user(admin: true)), false);
    expect(canUseTeachingForum(user()), false);
    expect(canUseTeachingForum(user(role: TeachingRole.teacher, pending: true)), false);
    expect(canUseTeachingForum(null), false);
  });

  test('moderação: curador ou admin ativo', () {
    expect(forumViewerFor(user(role: TeachingRole.curator))!.isModerator, true);
    expect(forumViewerFor(user(role: TeachingRole.teacher, admin: true))!.isModerator, true);
    expect(forumViewerFor(user(role: TeachingRole.teacher))!.isModerator, false);
    expect(forumViewerFor(null), isNull);
  });

  testWidgets('a tela da plataforma tem o botão Fórum que abre a lista', (tester) async {
    final repo = FakeForumRepository()..pages = [fakeTopic('a')];
    await tester.pumpWidget(
      Provider<ForumRepository>.value(
        value: repo,
        child: const MaterialApp(home: TeachingHomePage()),
      ),
    );
    expect(find.text('Plataforma pedagógica'), findsOneWidget);
    await tester.tap(find.text('Fórum'));
    await tester.pumpAndSettle();
    expect(find.text('Tópico a'), findsOneWidget);
    expect(find.text('Novo tópico'), findsOneWidget);
  });
}
