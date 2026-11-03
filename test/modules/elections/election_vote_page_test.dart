import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/core/utils/app_exception.dart';
import 'package:ipe_flutter/src/modules/elections/data/elections_repository.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/presentation/election_vote_page.dart';
import 'package:ipe_flutter/src/shared/state/app_state.dart';
import 'package:provider/provider.dart';

import 'election_test_fakes.dart';

class FakeRepo extends Fake implements ElectionsRepository {
  final election = StreamController<Election?>.broadcast();
  final voter = StreamController<ElectionVoter?>.broadcast();
  final round = StreamController<ElectionRound?>.broadcast();
  final voted = StreamController<bool>.broadcast();
  Object? castError;
  int voterListens = 0;

  @override
  Stream<Election?> watchElection(String id) => election.stream;

  @override
  Stream<ElectionVoter?> watchMyVoter(String electionId, String uid) {
    voterListens++;
    return voter.stream;
  }

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

  group('depois de ler o QR', () {
    Future<FakeRepo> pumpNeedingCheckIn(WidgetTester tester) async {
      final repo = FakeRepo();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ElectionsRepository>.value(value: repo),
            ChangeNotifierProvider<AppState>.value(value: FakeAppState()),
          ],
          child: MaterialApp(
            home: ElectionVotePage(
              electionId: 'e1',
              // No lugar da câmera: um botão que "entra" na eleição.
              scanPageBuilder: () => Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).pop('e1'),
                    child: const Text('entrar'),
                  ),
                ),
              ),
            ),
          ),
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
      repo.voter.add(null);
      await tester.pump();
      await tester.tap(find.text('Ler QR do condutor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('entrar'));
      // Sem pumpAndSettle: o spinner anima sem parar e adiantaria o relógio.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return repo;
    }

    testWidgets('não volta a mostrar o botão enquanto o registro não chega', (
      tester,
    ) async {
      await pumpNeedingCheckIn(tester);

      expect(find.text('Ler QR do condutor'), findsNothing);
      expect(find.textContaining('Entrando na votação'), findsOneWidget);
    });

    testWidgets('volta a ouvir o registro do eleitor ao entrar', (
      tester,
    ) async {
      final repo = await pumpNeedingCheckIn(tester);

      expect(repo.voterListens, 2);
    });

    testWidgets('se o registro nunca chega, o botão volta', (tester) async {
      await pumpNeedingCheckIn(tester);

      await tester.pump(const Duration(seconds: 11));

      expect(find.text('Ler QR do condutor'), findsOneWidget);
    });

    testWidgets('quando o registro chega, a votação segue', (tester) async {
      final repo = await pumpNeedingCheckIn(tester);

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
      repo.round.add(null);
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Entrando na votação'), findsNothing);
      expect(
        find.textContaining('Aguardando a próxima votação'),
        findsOneWidget,
      );
    });
  });
}
