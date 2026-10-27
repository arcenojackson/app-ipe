import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_models.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/widgets/subject_filter.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/widgets/subject_multi_sheet.dart';

void main() {
  const tags = [SubjectTag(id: 'fe', name: 'Fé'), SubjectTag(id: 'graca', name: 'Graça')];

  Future<void> open(WidgetTester t, void Function(String?) onResult, {String? selected}) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(
                await showSubjectFilterSheet(context, tags: tags, selected: selected)),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
  }

  testWidgets('escolhe e aplica', (t) async {
    String? result;
    await open(t, (r) => result = r);
    await t.tap(find.text('Graça'));
    await t.tap(find.text('Aplicar'));
    await t.pumpAndSettle();
    expect(result, 'graca');
  });

  testWidgets('busca filtra a lista e Limpar devolve vazio', (t) async {
    String? result;
    await open(t, (r) => result = r, selected: 'fe');
    await t.enterText(find.byType(TextField), 'gra');
    await t.pump();
    expect(find.text('Fé'), findsNothing);
    await t.tap(find.text('Limpar'));
    await t.pumpAndSettle();
    expect(result, '');
  });

  testWidgets('multi: contador, bloqueio no limite e Concluir', (t) async {
    List<String>? result;
    const many = [
      SubjectTag(id: 'a', name: 'Alfa'),
      SubjectTag(id: 'b', name: 'Beta'),
      SubjectTag(id: 'c', name: 'Gama'),
    ];
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showSubjectMultiSheet(context,
                tags: many, selected: {'a'}, max: 2),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.text('Assuntos (1/2)'), findsOneWidget);
    await t.tap(find.text('Beta'));
    await t.pump();
    expect(find.text('Assuntos (2/2)'), findsOneWidget);
    expect(find.textContaining('Limite atingido'), findsOneWidget);
    await t.tap(find.text('Gama'));
    await t.pump();
    expect(find.text('Assuntos (2/2)'), findsOneWidget);
    await t.tap(find.text('Concluir'));
    await t.pumpAndSettle();
    expect(result, ['a', 'b']);
  });

  testWidgets('chip removível dispara onRemove', (t) async {
    var removed = false;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SubjectChip(label: 'Fé', onRemove: () => removed = true))));
    await t.tap(find.text('Fé'));
    expect(removed, true);
  });
}
