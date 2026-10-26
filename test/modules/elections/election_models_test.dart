import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';

void main() {
  test('Election.fromJson lê campos, diretoria e usa defaults seguros', () {
    final e = Election.fromJson('e1', {
      'societyId': 's1',
      'societyName': 'UMP',
      'title': 'Eleição 2026',
      'scheduledAt': DateTime(2026, 10, 20, 19, 30),
      'status': 'open',
      'positions': ['presidente', 'vice'],
      'directorIds': ['d1', 'd2'],
    });
    expect(e.id, 'e1');
    expect(e.status, ElectionStatus.open);
    expect(e.positions, ['presidente', 'vice']);
    expect(e.directorIds, ['d1', 'd2']);
    expect(e.boardAppliedAt, isNull);
    final empty = Election.fromJson('x', {});
    expect(empty.status, ElectionStatus.draft);
    expect(empty.directorIds, isEmpty);
  });

  test('CargoStage.parse conhece as 8 fases e cai em idle', () {
    expect(CargoStage.values.length, 8);
    expect(CargoStage.parse('awaiting3'), CargoStage.awaiting3);
    expect(CargoStage.parse('tiebreak'), CargoStage.tiebreak);
    expect(CargoStage.parse('lixo'), CargoStage.idle);
    expect(CargoStage.parse(null), CargoStage.idle);
  });

  test('ElectionCargo.fromJson', () {
    final c = ElectionCargo.fromJson('presidente', {
      'stage': 'confirming',
      'cycle': 2,
      'candidates': [
        {'id': 'a', 'name': 'Ana', 'votes': 3}
      ],
      'tiedIds': ['a'],
      'winnerId': null,
    });
    expect(c.position, 'presidente');
    expect(c.stage, CargoStage.confirming);
    expect(c.cycle, 2);
    expect(c.candidates.single.votes, 3);
    expect(c.tiedIds, ['a']);
    expect(c.winnerId, isNull);
    expect(ElectionCargo.fromJson('vice', {}).stage, CargoStage.idle);
    expect(ElectionCargo.fromJson('vice', {}).cycle, 1);
  });

  test('ElectionRound.fromJson com opções e resultado do escrutínio', () {
    final r = ElectionRound.fromJson('r1', {
      'position': 'presidente',
      'cycle': 1,
      'number': 2,
      'status': 'closed',
      'votedCount': 8,
      'options': [
        {'id': 'a', 'name': 'Ana'},
        {'id': 'b', 'name': 'Bia'},
      ],
      'closedAt': DateTime(2026, 10, 20, 20),
      'result': {
        'counts': {'a': 6, 'b': 2},
        'blank': 0,
        'total': 8,
        'presentCount': 10,
        'threshold': 6,
        'winnerId': 'a',
        'tie': [],
        'divergence': false,
      },
    });
    expect(r.number, 2);
    expect(r.status, RoundStatus.closed);
    expect(r.options.map((o) => o.name), ['Ana', 'Bia']);
    expect(r.result!.counts['a'], 6);
    expect(r.result!.threshold, 6);
    expect(r.result!.presentCount, 10);
    expect(r.result!.winnerId, 'a');
    expect(r.closedAt, DateTime(2026, 10, 20, 20));
  });

  test('ElectionRound.fromJson mínimo (aberto, sem resultado)', () {
    final r = ElectionRound.fromJson('r1', {'position': 'vice', 'number': 1});
    expect(r.status, RoundStatus.open);
    expect(r.options, isEmpty);
    expect(r.result, isNull);
    expect(r.cycle, 1);
  });

  test('ElectionVoter e ElectionEvent', () {
    final v = ElectionVoter.fromJson('u1', {
      'name': 'Maria',
      'email': 'm@x.org',
      'kind': 'guest',
      'status': 'pending',
    });
    expect(v.kind, VoterKind.guest);
    expect(v.status, VoterStatus.pending);
    final ev = ElectionEvent.fromJson('ev1', {
      'type': 'scrutiny_started',
      'at': DateTime(2026, 10, 20, 19, 40),
      'position': 'vice',
      'number': 1,
    });
    expect(ev.type, 'scrutiny_started');
    expect(ev.data['position'], 'vice');
  });

  test('Candidate.toJson', () {
    expect(
      const Candidate(id: 'a', name: 'Ana').toJson(),
      {'id': 'a', 'name': 'Ana'},
    );
  });
}
