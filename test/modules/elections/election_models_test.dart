import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';

void main() {
  test('Election.fromJson lê campos e usa defaults seguros', () {
    final e = Election.fromJson('e1', {
      'societyId': 's1',
      'societyName': 'UMP',
      'title': 'Eleição 2026',
      'scheduledAt': DateTime(2026, 10, 20, 19, 30),
      'status': 'open',
      'positions': ['presidente', 'vice'],
    });
    expect(e.id, 'e1');
    expect(e.status, ElectionStatus.open);
    expect(e.positions, ['presidente', 'vice']);
    expect(e.boardAppliedAt, isNull);
    expect(Election.fromJson('x', {}).status, ElectionStatus.draft);
  });

  test('ElectionRound.fromJson com resultado', () {
    final r = ElectionRound.fromJson('r1', {
      'position': 'presidente',
      'type': 'single',
      'status': 'closed',
      'votedCount': 3,
      'candidates': [
        {'id': 'a', 'name': 'Ana'}
      ],
      'closedAt': DateTime(2026, 10, 20, 20),
      'result': {
        'counts': {'yes': 2, 'no': 1, 'blank': 0},
        'total': 3,
        'votedCount': 3,
        'winnerId': 'a',
        'tie': [],
        'divergence': false,
      },
    });
    expect(r.type, RoundType.single);
    expect(r.status, RoundStatus.closed);
    expect(r.candidates.single.name, 'Ana');
    expect(r.result!.winnerId, 'a');
    expect(r.result!.counts['yes'], 2);
    expect(r.closedAt, DateTime(2026, 10, 20, 20));
  });

  test('ElectionRound.fromJson sem resultado nem candidatos', () {
    final r = ElectionRound.fromJson('r1', {'position': 'vice'});
    expect(r.status, RoundStatus.pending);
    expect(r.candidates, isEmpty);
    expect(r.result, isNull);
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
      'type': 'round_opened',
      'at': DateTime(2026, 10, 20, 19, 40),
      'position': 'vice',
    });
    expect(ev.type, 'round_opened');
    expect(ev.data['position'], 'vice');
  });

  test('Candidate.toJson', () {
    expect(
      const Candidate(id: 'a', name: 'Ana').toJson(),
      {'id': 'a', 'name': 'Ana'},
    );
  });
}
