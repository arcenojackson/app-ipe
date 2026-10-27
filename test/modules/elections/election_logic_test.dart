import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/models/election_logic.dart';
import 'package:ipe_flutter/src/modules/societies/models/society.dart';

SocietyModel society(String id, String name, Map<String, List<String>> board) =>
    SocietyModel(
      id: id,
      name: name,
      description: '',
      color: 0,
      userId: 'criador',
      boardWithPositions: board,
    );

void main() {
  test('links apontam para a votação e para a condução no portal', () {
    expect(buildVoteLink('abc'), endsWith('/votar/abc'));
    expect(buildConductLink('abc'), endsWith('/eleicoes/abc'));
    expect(buildVoteLink('abc'), startsWith('https://'));
    expect(buildConductLink('abc'), startsWith('https://'));
  });

  test('título padrão inclui sociedade e ano', () {
    expect(defaultElectionTitle('UMP', 2026), 'Eleição da diretoria UMP 2026');
    expect(defaultElectionTitle('', 2026), 'Eleição da diretoria 2026');
  });

  group('directorSocieties', () {
    final ump = society('s1', 'UMP', {
      'presidente': ['d1'],
      'vice': ['d2']
    });
    final uph = society('s2', 'UPH', {
      'presidente': ['d3']
    });
    final semDiretoria = society('s3', 'UCP', {});

    test('só as sociedades em que a pessoa está na diretoria (qualquer cargo)', () {
      expect(directorSocieties([ump, uph, semDiretoria], 'd1'), [ump]);
      expect(directorSocieties([ump, uph, semDiretoria], 'd2'), [ump]);
      expect(directorSocieties([ump, uph, semDiretoria], 'd3'), [uph]);
    });

    test('quem não é diretor de nenhuma recebe lista vazia', () {
      expect(directorSocieties([ump, uph, semDiretoria], 'membro'), isEmpty);
    });

    test('diretor de duas sociedades vê as duas, na ordem recebida', () {
      final dupla = society('s4', 'SAF', {
        'tesoureiro(a)': ['d1']
      });
      expect(directorSocieties([ump, dupla], 'd1'), [ump, dupla]);
    });
  });

  group('electionsOfCurrentDirector', () {
    Election election(String id, String societyId) => Election(
      id: id,
      societyId: societyId,
      societyName: '',
      title: id,
      scheduledAt: DateTime(2026),
      status: ElectionStatus.draft,
      positions: const [],
      directorIds: const ['d1'],
    );
    final elo = society('s1', 'ELO', {
      'secretario(a)': ['d1'],
    });
    final ump = society('s2', 'UMP', {
      'presidente': ['d2'],
    });

    test('mantém só eleições de sociedades em que ainda é diretor', () {
      final e1 = election('e1', 's1');
      final e2 = election('e2', 's2');
      expect(electionsOfCurrentDirector([e1, e2], [elo, ump], 'd1'), [e1]);
    });

    test(
      'quem saiu da diretoria deixa de ver a eleição, mesmo no snapshot',
      () {
        final semD1 = society('s1', 'ELO', {
          'secretario(a)': ['d9'],
        });
        expect(
          electionsOfCurrentDirector(
            [election('e1', 's1')],
            [semD1, ump],
            'd1',
          ),
          isEmpty,
        );
      },
    );

    test('sociedade removida esconde a eleição', () {
      expect(
        electionsOfCurrentDirector([election('e1', 's1')], [ump], 'd1'),
        isEmpty,
      );
    });
  });
}
