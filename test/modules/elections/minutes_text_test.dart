import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/models/minutes_text.dart';

void main() {
  final election = Election(
    id: 'e1',
    societyId: 's1',
    societyName: 'UMP',
    title: 'Eleição 2026',
    scheduledAt: DateTime(2026, 10, 20, 19, 5),
    status: ElectionStatus.closed,
    positions: const ['presidente', 'vice'],
  );
  const ana = Candidate(id: 'ana', name: 'Ana');
  const bia = Candidate(id: 'bia', name: 'Bia');

  const voters = [
    ElectionVoter(id: '1', name: 'Ana', email: '', kind: VoterKind.member, status: VoterStatus.approved),
    ElectionVoter(id: '2', name: 'Maria', email: 'm@x', kind: VoterKind.guest, status: VoterStatus.approved),
    ElectionVoter(id: '3', name: 'Intruso', email: '', kind: VoterKind.guest, status: VoterStatus.rejected),
    ElectionVoter(id: '4', name: 'Pendente', email: '', kind: VoterKind.guest, status: VoterStatus.pending),
  ];

  const rounds = [
    ElectionRound(
      id: 'r1',
      position: 'presidente',
      candidates: [ana, bia],
      type: RoundType.normal,
      status: RoundStatus.closed,
      votedCount: 3,
      result: RoundResult(
        counts: {'ana': 2, 'bia': 1, 'blank': 0},
        total: 3,
        votedCount: 3,
        winnerId: 'ana',
        tie: [],
        divergence: false,
      ),
    ),
    ElectionRound(
      id: 'r2',
      position: 'vice',
      candidates: [ana, bia],
      type: RoundType.normal,
      status: RoundStatus.closed,
      votedCount: 3,
      result: RoundResult(
        counts: {'ana': 1, 'bia': 1, 'blank': 0},
        total: 2,
        votedCount: 3,
        winnerId: null,
        tie: ['ana', 'bia'],
        divergence: true,
      ),
    ),
  ];

  final events = [
    ElectionEvent(id: '2', type: 'round_opened', at: DateTime(2026, 10, 20, 19, 40), data: const {'position': 'presidente'}),
    ElectionEvent(id: '1', type: 'election_opened', at: DateTime(2026, 10, 20, 19, 10), data: const {}),
  ];

  final text = buildMinutesText(
    election: election,
    voters: voters,
    rounds: rounds,
    events: events,
  );

  test('cabeçalho', () {
    expect(text, contains('ATA DA ELEIÇÃO — Eleição 2026'));
    expect(text, contains('Sociedade: UMP'));
    expect(text, contains('20/10/2026 19:05'));
    expect(text, contains('Encerrada'));
  });

  test('presentes: só aprovados, com o tipo', () {
    expect(text, contains('PRESENTES (2)'));
    expect(text, contains('- Ana (membro)'));
    expect(text, contains('- Maria (convidado)'));
    expect(text, isNot(contains('Intruso')));
    expect(text, isNot(contains('Pendente')));
  });

  test('votações com contagem, vencedor, empate e divergência', () {
    expect(text, contains('Presidente'));
    expect(text, contains('Ana: 2'));
    expect(text, contains('Eleito(a): Ana'));
    expect(text, contains('Empate entre: Ana, Bia'));
    expect(text, contains('ATENÇÃO'));
  });

  test('linha do tempo ordenada por horário', () {
    final i1 = text.indexOf('19:10');
    final i2 = text.indexOf('19:40');
    expect(i1, greaterThan(-1));
    expect(i2, greaterThan(i1));
    expect(text, contains('Votação aberta — Presidente'));
    expect(text, contains('Eleição aberta'));
  });
}
