import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/core/utils/app_exception.dart';
import 'package:ipe_flutter/src/modules/elections/data/elections_repository.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/presentation/election_detail_page.dart';
import 'package:ipe_flutter/src/shared/state/app_state.dart';
import 'package:provider/provider.dart';

import 'election_test_fakes.dart';

class FakeRepo extends Fake implements ElectionsRepository {
  final election = StreamController<Election?>.broadcast();
  final opened = <String>[];
  Object? openError;

  @override
  Stream<Election?> watchElection(String id) => election.stream;

  // A ata só precisa de listas (vazias) para sair do "carregando".
  @override
  Stream<List<ElectionCargo>> watchCargos(String id) => Stream.value(const []);

  @override
  Stream<List<ElectionVoter>> watchVoters(String id) => Stream.value(const []);

  @override
  Stream<List<ElectionRound>> watchRounds(String id) => Stream.value(const []);

  @override
  Stream<List<ElectionEvent>> watchEvents(String id) => Stream.value(const []);

  @override
  Future<void> openElection(String electionId) async {
    final error = openError;
    if (error != null) throw error;
    opened.add(electionId);
  }
}

Election electionWith(
  ElectionStatus status, {
  List<String> directorIds = const ['u1'],
}) => Election(
  id: 'e1',
  societyId: 's1',
  societyName: 'UMP',
  title: 'Eleição UMP 2026',
  scheduledAt: DateTime(2026, 11, 8),
  status: status,
  positions: const ['presidente'],
  directorIds: directorIds,
);

Future<FakeRepo> openDetail(WidgetTester tester, Election election) async {
  final repo = FakeRepo();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ElectionsRepository>.value(value: repo),
        ChangeNotifierProvider<AppState>.value(value: FakeAppState()),
      ],
      child: const MaterialApp(home: ElectionDetailPage(electionId: 'e1')),
    ),
  );
  repo.election.add(election);
  await tester.pump();
  await tester.pump();
  return repo;
}

// FilledButton.icon é um subtipo: casa por predicado, não por tipo exato.
final startButton = find.ancestor(
  of: find.text('Iniciar votação'),
  matching: find.byWidgetPredicate((w) => w is FilledButton),
);

void main() {
  testWidgets('rascunho: o diretor vê o botão Iniciar votação', (tester) async {
    await openDetail(tester, electionWith(ElectionStatus.draft));

    expect(startButton, findsOneWidget);
  });

  testWidgets('eleição aberta ou encerrada não mostra o botão', (tester) async {
    final repo = await openDetail(tester, electionWith(ElectionStatus.open));
    expect(startButton, findsNothing);

    repo.election.add(electionWith(ElectionStatus.closed));
    await tester.pump();
    await tester.pump();
    expect(startButton, findsNothing);
  });

  testWidgets('quem não é diretor da eleição não vê o botão', (tester) async {
    await openDetail(
      tester,
      electionWith(ElectionStatus.draft, directorIds: const ['outro']),
    );

    expect(startButton, findsNothing);
  });

  testWidgets('cancelar a confirmação não abre a eleição', (tester) async {
    final repo = await openDetail(tester, electionWith(ElectionStatus.draft));

    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(find.text('Iniciar a votação?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.opened, isEmpty);
  });

  testWidgets('confirmar abre a eleição uma única vez', (tester) async {
    final repo = await openDetail(tester, electionWith(ElectionStatus.draft));

    await tester.tap(startButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Iniciar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(repo.opened, ['e1']);
  });

  testWidgets('erro do servidor não derruba a tela e o botão continua', (
    tester,
  ) async {
    final repo = await openDetail(tester, electionWith(ElectionStatus.draft));
    repo.openError = AppException(message: 'Só diretores podem iniciar.');

    await tester.tap(startButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Iniciar'));
    await tester.pump();
    expect(find.text('Só diretores podem iniciar.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(repo.opened, isEmpty);
    expect(startButton, findsOneWidget);
  });
}
