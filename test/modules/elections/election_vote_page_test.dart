import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/core/utils/app_exception.dart';
import 'package:ipe_flutter/src/modules/auth/models/user.dart';
import 'package:ipe_flutter/src/modules/elections/data/elections_repository.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/presentation/election_vote_page.dart';
import 'package:ipe_flutter/src/shared/state/app_state.dart';
import 'package:provider/provider.dart';

class FakeRepo extends Fake implements ElectionsRepository {
  final election = StreamController<Election?>.broadcast();
  final voter = StreamController<ElectionVoter?>.broadcast();
  final round = StreamController<ElectionRound?>.broadcast();
  final voted = StreamController<bool>.broadcast();
  Object? castError;

  @override
  Stream<Election?> watchElection(String id) => election.stream;

  @override
  Stream<ElectionVoter?> watchMyVoter(String electionId, String uid) =>
      voter.stream;

  @override
  Stream<ElectionRound?> watchOpenRound(String electionId) => round.stream;

  @override
  Stream<bool> watchHasVoted(String electionId, String roundId, String uid) =>
      voted.stream;

  @override
  Future<String> castVote(String electionId, String roundId, String choice) {
    final error = castError;
    if (error != null) return Future.error(error);
    return Future.value('RECIBO1');
  }
}

class FakeAppState extends Fake with ChangeNotifier implements AppState {
  @override
  UserModel? get currentUser => UserModel(
    id: 'u1',
    name: 'Ana',
    email: 'ana@ipe.org',
    isAdmin: false,
    isPending: false,
  );
}

ElectionRound roundOf(String id, int number) => ElectionRound(
  id: id,
  position: 'presidente',
  cycle: 1,
  number: number,
  status: RoundStatus.open,
  options: const [Candidate(id: 'c1', name: 'Ana')],
  votedCount: 0,
);

const closedError = 'Este escrutínio não está aberto.';
const streamError = 'Não foi possível atualizar a votação.';

Future<FakeRepo> openVotePage(WidgetTester tester) async {
  final repo = FakeRepo();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ElectionsRepository>.value(value: repo),
        ChangeNotifierProvider<AppState>.value(value: FakeAppState()),
      ],
      child: const MaterialApp(home: ElectionVotePage(electionId: 'e1')),
    ),
  );
  repo.election.add(
    Election(
      id: 'e1',
      societyId: 's1',
      societyName: 'UMP',
      title: 'Eleição UMP 2026',
      scheduledAt: DateTime(2026, 11, 8),
      status: ElectionStatus.open,
      positions: const ['presidente'],
      directorIds: const ['d1'],
    ),
  );
  repo.voter.add(
    const ElectionVoter(
      id: 'u1',
      name: 'Ana',
      email: 'ana@ipe.org',
      kind: VoterKind.member,
      status: VoterStatus.approved,
    ),
  );
  await tester.pump();
  repo.round.add(roundOf('r1', 1));
  await tester.pump();
  repo.voted.add(false);
  await tester.pump();
  return repo;
}

void main() {
  testWidgets('mostra a cédula do escrutínio aberto', (tester) async {
    await openVotePage(tester);

    expect(find.textContaining('1º escrutínio'), findsOneWidget);
    expect(find.text('Confirmar voto'), findsOneWidget);
  });

  testWidgets('voto registrado mostra o comprovante', (tester) async {
    final repo = await openVotePage(tester);

    await tester.tap(find.text('Ana'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    repo.voted.add(true);
    await tester.pump();

    expect(find.textContaining('Seu voto foi registrado'), findsOneWidget);
    expect(find.text('RECIBO1'), findsOneWidget);
  });

  testWidgets('erro de voto recusado não vaza para a próxima cédula', (
    tester,
  ) async {
    final repo = await openVotePage(tester);
    repo.castError = AppException(message: closedError);

    await tester.tap(find.text('Ana'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text(closedError), findsOneWidget);

    repo.round.add(null);
    await tester.pump();
    repo.round.add(roundOf('r2', 2));
    await tester.pump();
    repo.voted.add(false);
    await tester.pump();

    expect(find.textContaining('2º escrutínio'), findsOneWidget);
    expect(find.text(closedError), findsNothing);
  });

  testWidgets('aviso de falha na atualização some quando os dados voltam', (
    tester,
  ) async {
    final repo = await openVotePage(tester);

    repo.round.addError(StateError('rede'));
    await tester.pump();
    expect(find.text(streamError), findsOneWidget);

    repo.round.add(null);
    await tester.pump();
    await tester.pump();

    expect(find.text(streamError), findsNothing);
    expect(find.textContaining('Aguardando a próxima votação'), findsOneWidget);
  });
}
