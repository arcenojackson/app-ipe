import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/models/election_logic.dart';

ElectionRound round(
  String id,
  String position, {
  RoundStatus status = RoundStatus.closed,
  String? winner,
  int closedMs = 1,
}) =>
    ElectionRound(
      id: id,
      position: position,
      candidates: const [],
      type: RoundType.normal,
      status: status,
      votedCount: 0,
      closedAt: DateTime.fromMillisecondsSinceEpoch(closedMs),
      result: winner == null
          ? null
          : RoundResult(
              counts: const {},
              total: 0,
              votedCount: 0,
              winnerId: winner,
              tie: const [],
              divergence: false,
            ),
    );

ElectionVoter voter(String id, String name, String email) => ElectionVoter(
      id: id,
      name: name,
      email: email,
      kind: VoterKind.guest,
      status: VoterStatus.pending,
    );

void main() {
  group('latestWinners', () {
    test('pega o vencedor de cada cargo, ignora rodadas não fechadas', () {
      final w = latestWinners([
        round('1', 'presidente', winner: 'ana'),
        round('2', 'vice', winner: 'bia'),
        round('3', 'secretario', status: RoundStatus.open, winner: 'caio'),
      ]);
      expect(w, {'presidente': 'ana', 'vice': 'bia'});
    });

    test('a rodada fechada mais recente do cargo vale', () {
      final w = latestWinners([
        round('1', 'presidente', winner: 'ana', closedMs: 1),
        round('2', 'presidente', closedMs: 2),
      ]);
      expect(w, isEmpty);
    });
  });

  group('candidateOptions', () {
    const ana = Candidate(id: 'ana', name: 'Ana');
    const bia = Candidate(id: 'bia', name: 'Bia');

    test('remove quem foi eleito em OUTRO cargo', () {
      final options = candidateOptions(
        members: [ana, bia],
        rounds: [round('1', 'presidente', winner: 'ana')],
        position: 'vice',
      );
      expect(options, [bia]);
    });

    test('mantém o vencedor atual do próprio cargo (refazer a votação)', () {
      final options = candidateOptions(
        members: [ana, bia],
        rounds: [round('1', 'presidente', winner: 'ana')],
        position: 'presidente',
      );
      expect(options, [ana, bia]);
    });
  });

  group('duplicateVoterIds', () {
    test('marca quem divide e-mail ou nome (sem diferenciar caixa)', () {
      final ids = duplicateVoterIds([
        voter('1', 'Maria Silva', 'maria@x.org'),
        voter('2', 'maria silva', 'outro@x.org'),
        voter('3', 'João', 'MARIA@x.org'),
        voter('4', 'Pedro', 'pedro@x.org'),
      ]);
      expect(ids, {'1', '2', '3'});
    });

    test('ignora e-mail vazio', () {
      final ids = duplicateVoterIds([
        voter('1', 'Ana', ''),
        voter('2', 'Bia', ''),
      ]);
      expect(ids, isEmpty);
    });
  });

  test('buildVoteLink usa a base do portal', () {
    expect(buildVoteLink('abc'), endsWith('/votar/abc'));
    expect(buildVoteLink('abc'), startsWith('https://'));
  });
}
