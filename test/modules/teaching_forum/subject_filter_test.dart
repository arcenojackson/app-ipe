import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/models/forum_models.dart';
import 'package:ipe_flutter/src/modules/teaching_forum/presentation/widgets/subject_filter.dart';

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

  testWidgets('chip removível dispara onRemove', (t) async {
    var removed = false;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SubjectChip(label: 'Fé', onRemove: () => removed = true))));
    await t.tap(find.text('Fé'));
    expect(removed, true);
  });
}
