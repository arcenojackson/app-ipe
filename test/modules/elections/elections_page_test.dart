import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/core/utils/app_exception.dart';
import 'package:ipe_flutter/src/modules/elections/data/elections_repository.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/presentation/elections_page.dart';
import 'package:ipe_flutter/src/modules/societies/data/societies_repository.dart';
import 'package:ipe_flutter/src/modules/societies/models/society.dart';
import 'package:ipe_flutter/src/shared/state/app_state.dart';
import 'package:provider/provider.dart';

import 'election_test_fakes.dart';

class FakeSocieties extends Fake implements SocietiesRepository {
  @override
  Future<List<SocietyModel>> fetchAll() async => const [
    SocietyModel(
      id: 's1',
      name: 'UMP',
      description: '',
      color: 0xFF000000,
      userId: 'u1',
      boardIds: ['u1'],
    ),
  ];
}

class FakeElections extends Fake implements ElectionsRepository {
  final deleted = <String>[];
  Object? deleteError;

  @override
  Stream<List<Election>> watchElections(String userId) => Stream.value([
    election('d1', ElectionStatus.draft),
    election('o1', ElectionStatus.open),
    election('c1', ElectionStatus.closed),
    election('k1', ElectionStatus.completed),
  ]);

  @override
  Future<void> deleteElection(String electionId) async {
    final error = deleteError;
    if (error != null) throw error;
    deleted.add(electionId);
  }
}

Election election(String id, ElectionStatus status) => Election(
  id: id,
  societyId: 's1',
  societyName: 'UMP',
  title: 'Eleição $id',
  scheduledAt: DateTime(2026, 11, 8),
  status: status,
  positions: const ['presidente', 'vice'],
  directorIds: const ['u1'],
);

Future<FakeElections> openList(WidgetTester tester) async {
  // Tela alta: a lista é preguiçosa e as 4 eleições precisam caber.
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeElections();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SocietiesRepository>.value(value: FakeSocieties()),
        Provider<ElectionsRepository>.value(value: repo),
        ChangeNotifierProvider<AppState>.value(value: FakeAppState()),
      ],
      child: const MaterialApp(home: ElectionsPage()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

final trash = find.byIcon(Icons.delete_outline);

void main() {
  testWidgets('todas têm lixeira, menos a concluída', (tester) async {
    await openList(tester);

    for (final id in ['d1', 'o1', 'c1', 'k1']) {
      expect(find.text('Eleição $id'), findsOneWidget);
    }
    expect(trash, findsNWidgets(3));
    for (final id in ['d1', 'o1', 'c1']) {
      final card = find.ancestor(
        of: find.text('Eleição $id'),
        matching: find.byType(InkWell),
      );
      expect(find.descendant(of: card.first, matching: trash), findsOneWidget);
    }
    final concluded = find.ancestor(
      of: find.text('Eleição k1'),
      matching: find.byType(InkWell),
    );
    expect(find.descendant(of: concluded.first, matching: trash), findsNothing);
    expect(find.text('Concluída'), findsOneWidget);
  });

  testWidgets('cancelar a confirmação não exclui', (tester) async {
    final repo = await openList(tester);

    await tester.tap(trash.first);
    await tester.pumpAndSettle();
    expect(find.text('Excluir a eleição?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.deleted, isEmpty);
  });

  testWidgets('confirmar exclui a eleição escolhida', (tester) async {
    final repo = await openList(tester);

    await tester.tap(trash.first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['d1']);
  });

  testWidgets('erro do servidor aparece e a tela continua', (tester) async {
    final repo = await openList(tester);
    repo.deleteError = AppException(message: 'Só diretores podem excluir.');

    await tester.tap(trash.first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pump();

    expect(find.text('Só diretores podem excluir.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
    expect(find.text('Eleição d1'), findsOneWidget);
  });
}
