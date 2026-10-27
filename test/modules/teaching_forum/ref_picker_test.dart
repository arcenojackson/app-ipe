import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_models.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/ref_options.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/forum_editor_controller.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/widgets/ref_picker.dart';

import 'fake_forum_repository.dart';

class _Repo extends FakeForumRepository {
  bool fail = false;
  @override
  Future<List<RefOption>> loadPublishedDocs(String search) async {
    if (fail) throw Exception('rede');
    return const [
      RefOption(
          ref: ForumRef(kind: 'library', id: 'd1', label: 'Catecismo.pdf'),
          tagIds: ['t1']),
    ];
  }

  @override
  Future<List<ForumRef>> loadPlanLessons() async => const [
        ForumRef(kind: 'plan', id: 'p1', label: 'Aula 1 — Deus'),
        ForumRef(kind: 'plan', id: 'p3', label: 'Aula 3 — Como interpretar a Bíblia?'),
      ];

  @override
  Future<Map<String, String>> loadAllTagNames() async => {'t1': 'Fé'};
}

void main() {
  test('libraryOptionFrom: arquivo e link entram; pasta e sem nome não', () {
    final tags = {
      'type': 'file',
      'name': 'Doc',
      'typeTags': ['a'],
      'subjectTags': ['b'],
    };
    final o = libraryOptionFrom('x', tags)!;
    expect(o.ref.toMap(), {'kind': 'library', 'id': 'x', 'label': 'Doc'});
    expect(o.tagIds, ['a', 'b']);
    expect(libraryOptionFrom('x', {'type': 'link', 'name': 'L'})!.isLink, true);
    expect(libraryOptionFrom('x', {'type': 'folder', 'name': 'P'}), isNull);
    expect(libraryOptionFrom('x', {'type': 'file', 'name': ' '}), isNull);
  });

  test('planRefFrom monta "Aula N — Tema"', () {
    expect(planRefFrom('p', {'lesson': 3, 'theme': 'Bíblia'})!.label, 'Aula 3 — Bíblia');
    expect(planRefFrom('p', {'theme': 'x'}), isNull);
  });

  test('refNameMatches ignora acento e exige todas as palavras', () {
    expect(refNameMatches('Aula 3 — Como interpretar a Bíblia?', ['biblia', 'aula']), true);
    expect(refNameMatches('Aula 3', ['biblia']), false);
  });

  test('editor: citações entram no tópico, limitadas a 3', () async {
    final repo = FakeForumRepository();
    final c = ForumEditorController(
        repository: repo, author: const ForumAuthor(uid: 'u', name: 'Ana'));
    c.setRefs([
      for (var i = 0; i < 5; i++) ForumRef(kind: 'plan', id: '$i', label: 'A$i'),
    ]);
    expect(c.refs, hasLength(3));
    await c.save('Título', 'Corpo');
    expect(repo.created.single.refs, hasLength(3));
  });

  testWidgets('escolhe documento da Biblioteca e aula do Plano', (t) async {
    var refs = <ForumRef>[];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, set) => RefPickerField(
            value: refs,
            onChanged: (v) => set(() => refs = v),
          ),
        ),
      ),
    ));
    // O sheet usa o repositório do Provider; aqui o sheet é aberto direto.
    final repo = _Repo();
    ForumRef? picked;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showModalBottomSheet<ForumRef>(
              context: context,
              isScrollControlled: true,
              builder: (_) => RefPickerSheet(repository: repo, selected: const []),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.text('Catecismo.pdf'), findsOneWidget);
    expect(find.text('Fé'), findsOneWidget);
    await t.tap(find.text('Plano pedagógico'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'biblia');
    await t.pump();
    expect(find.textContaining('Aula 1'), findsNothing);
    await t.tap(find.textContaining('Aula 3'));
    await t.pumpAndSettle();
    expect(picked!.toMap(),
        {'kind': 'plan', 'id': 'p3', 'label': 'Aula 3 — Como interpretar a Bíblia?'});
  });

  testWidgets('erro de carga mostra "Tentar de novo"', (t) async {
    final repo = _Repo()..fail = true;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: RefPickerSheet(repository: repo, selected: const [])),
    ));
    await t.pumpAndSettle();
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('campo: cartão removível e botão bloqueia no limite', (t) async {
    var refs = const [
      ForumRef(kind: 'plan', id: '1', label: 'A1'),
      ForumRef(kind: 'plan', id: '2', label: 'A2'),
      ForumRef(kind: 'plan', id: '3', label: 'A3'),
    ];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, set) => RefPickerField(
            value: refs,
            onChanged: (v) => set(() => refs = v),
          ),
        ),
      ),
    ));
    expect(find.text('3 de 3'), findsOneWidget);
    final button = find.byWidgetPredicate((w) => w is OutlinedButton);
    expect(t.widget<OutlinedButton>(button).onPressed, isNull);
    await t.tap(find.byTooltip('Remover citação A2'));
    await t.pump();
    expect(find.text('A2'), findsNothing);
    expect(find.text('2 de 3'), findsOneWidget);
  });
}
