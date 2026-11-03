import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/models/election_logic.dart';

Election makeElection(ElectionStatus status) => Election(
  id: 'e1',
  societyId: 's1',
  societyName: 'UMP',
  title: 'Eleição UMP 2026',
  scheduledAt: DateTime(2026, 11, 8),
  status: status,
  positions: const ['presidente'],
  directorIds: const ['d1'],
);

ElectionVoter makeVoter({
  VoterStatus status = VoterStatus.approved,
  VoterKind kind = VoterKind.member,
}) => ElectionVoter(
  id: 'u1',
  name: 'Ana',
  email: 'ana@ipe.org',
  kind: kind,
  status: status,
);

ElectionRound makeRound() => const ElectionRound(
  id: 'r1',
  position: 'presidente',
  cycle: 1,
  number: 1,
  status: RoundStatus.open,
  options: [Candidate(id: 'c1', name: 'Ana')],
  votedCount: 0,
);

VoteView derive({
  Loadable<Election?>? election,
  Loadable<ElectionVoter?>? voter,
  Loadable<ElectionRound?>? openRound,
  Loadable<bool>? hasVoted,
}) => deriveVoteView(
  election: election ?? Loadable(makeElection(ElectionStatus.open)),
  voter: voter ?? Loadable(makeVoter()),
  openRound: openRound ?? Loadable(makeRound()),
  hasVoted: hasVoted ?? const Loadable(false),
);

void main() {
  group('parseElectionId', () {
    test('extrai o id do caminho /votar/{id}, com qualquer host', () {
      expect(
        parseElectionId('https://ipe-ensino.vercel.app/votar/abc12345XYZ'),
        'abc12345XYZ',
      );
      expect(
        parseElectionId('http://localhost:3000/votar/abc12345XYZ/'),
        'abc12345XYZ',
      );
      expect(
        parseElectionId('https://x.com/votar/abc12345XYZ?a=1#f'),
        'abc12345XYZ',
      );
    });

    test('aceita um id solto, ignorando espaços', () {
      expect(parseElectionId('  abc12345XYZ '), 'abc12345XYZ');
    });

    test('recusa o que não é link de votação', () {
      expect(parseElectionId('https://x.com/eleicoes/abc12345XYZ'), isNull);
      expect(parseElectionId('https://x.com/votar/'), isNull);
      expect(parseElectionId('oi'), isNull);
      expect(parseElectionId(''), isNull);
      expect(parseElectionId('javascript:alert(1)'), isNull);
    });
  });

  group('parseElectionId pela câmera (allowBareId: false)', () {
    test('palavra solta lida de um QR qualquer não vira id de eleição', () {
      expect(parseElectionId('HelloWorld99', allowBareId: false), isNull);
      expect(parseElectionId('7891234567890', allowBareId: false), isNull);
    });

    test('o link de votação continua valendo', () {
      expect(
        parseElectionId('https://x.com/votar/abc12345XYZ', allowBareId: false),
        'abc12345XYZ',
      );
    });
  });

  group('filterCandidates', () {
    const options = [
      Candidate(id: 'a', name: 'João Silva'),
      Candidate(id: 'b', name: 'Maria Souza'),
      Candidate(id: 'c', name: 'Joana Lima'),
    ];

    test('ignora maiúsculas e acentos', () {
      expect(filterCandidates(options, 'joao').map((c) => c.id), ['a']);
      expect(filterCandidates(options, 'JOA').map((c) => c.id), ['a', 'c']);
    });

    test('consulta vazia devolve tudo, na mesma ordem', () {
      expect(filterCandidates(options, '  ').map((c) => c.id), ['a', 'b', 'c']);
    });
  });

  group('deriveVoteView', () {
    test('carregando enquanto algo não chegou', () {
      expect(
        derive(election: const Loadable.loading()).kind,
        VoteViewKind.loading,
      );
      expect(
        derive(voter: const Loadable.loading()).kind,
        VoteViewKind.loading,
      );
      expect(
        derive(openRound: const Loadable.loading()).kind,
        VoteViewKind.loading,
      );
      expect(
        derive(hasVoted: const Loadable.loading()).kind,
        VoteViewKind.loading,
      );
    });

    test('eleição inexistente, em rascunho ou encerrada', () {
      expect(
        derive(election: const Loadable<Election?>(null)).kind,
        VoteViewKind.notFound,
      );
      expect(
        derive(election: Loadable(makeElection(ElectionStatus.draft))).kind,
        VoteViewKind.notOpen,
      );
      expect(
        derive(election: Loadable(makeElection(ElectionStatus.closed))).kind,
        VoteViewKind.closed,
      );
      expect(
        derive(election: Loadable(makeElection(ElectionStatus.completed))).kind,
        VoteViewKind.closed,
      );
    });

    test('sem registro de eleitor pede o check-in', () {
      expect(
        derive(voter: const Loadable<ElectionVoter?>(null)).kind,
        VoteViewKind.needsCheckIn,
      );
    });

    test('quem não é membro aprovado vê a recusa', () {
      expect(
        derive(voter: Loadable(makeVoter(status: VoterStatus.pending))).kind,
        VoteViewKind.notMember,
      );
      expect(
        derive(voter: Loadable(makeVoter(status: VoterStatus.rejected))).kind,
        VoteViewKind.notMember,
      );
      expect(
        derive(voter: Loadable(makeVoter(kind: VoterKind.guest))).kind,
        VoteViewKind.notMember,
      );
    });

    test('sem rodada aberta aguarda', () {
      expect(
        derive(openRound: const Loadable<ElectionRound?>(null)).kind,
        VoteViewKind.waitingRound,
      );
    });

    test('rodada aberta: cédula ou já votou', () {
      final ballot = derive();
      expect(ballot.kind, VoteViewKind.ballot);
      expect(ballot.round?.id, 'r1');

      final voted = derive(hasVoted: const Loadable(true));
      expect(voted.kind, VoteViewKind.voted);
      expect(voted.round?.id, 'r1');
    });
  });

  group('invitesToShow', () {
    const open = ElectionInvite(id: 'a', title: 'A', societyName: 'UMP');
    const closed = ElectionInvite(id: 'b', title: 'B', societyName: 'UMP');
    const unknown = ElectionInvite(id: 'c', title: 'C', societyName: 'UMP');

    test('só eleições abertas, na mesma ordem', () {
      final shown = invitesToShow(
        [closed, open, unknown],
        {'a': ElectionStatus.open, 'b': ElectionStatus.closed},
      );
      expect(shown.map((i) => i.id), ['a']);
    });

    test('convite de eleição ainda em rascunho não aparece', () {
      expect(invitesToShow([open], {'a': ElectionStatus.draft}), isEmpty);
    });
  });

  group('electionIdFromPush', () {
    test('devolve o id quando é o push de eleição aberta', () {
      expect(
        electionIdFromPush({'type': 'election_open', 'electionId': 'e1'}),
        'e1',
      );
    });

    test('ignora outros tipos e ids vazios', () {
      expect(
        electionIdFromPush({'type': 'chat_mention', 'electionId': 'e1'}),
        isNull,
      );
      expect(
        electionIdFromPush({'type': 'election_open', 'electionId': '  '}),
        isNull,
      );
      expect(electionIdFromPush({'type': 'election_open'}), isNull);
    });
  });
}
