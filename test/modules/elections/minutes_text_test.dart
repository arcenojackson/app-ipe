import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/models/minutes_text.dart';

RoundResult result({
  required Map<String, int> counts,
  int blank = 0,
  required int total,
  int presentCount = 10,
  int threshold = 6,
  String? winnerId,
  List<String> tie = const [],
  bool divergence = false,
}) =>
    RoundResult(
      counts: counts,
      blank: blank,
      total: total,
      presentCount: presentCount,
      threshold: threshold,
      winnerId: winnerId,
      tie: tie,
      divergence: divergence,
    );

ElectionRound round(
  String id,
  String position,
  int number,
  List<Candidate> options,
  RoundResult res, {
  int cycle = 1,
}) =>
    ElectionRound(
      id: id,
      position: position,
      cycle: cycle,
      number: number,
      status: RoundStatus.closed,
      options: options,
      votedCount: res.total,
      result: res,
    );

void main() {
  final election = Election(
    id: 'e1',
    societyId: 's1',
    societyName: 'UMP',
    title: 'Eleição 2026',
    scheduledAt: DateTime(2026, 10, 20, 19, 5),
    status: ElectionStatus.closed,
    positions: const ['presidente', 'vice', 'tesoureiro'],
    directorIds: const ['d1'],
  );
  const ana = Candidate(id: 'ana', name: 'Ana');
  const bia = Candidate(id: 'bia', name: 'Bia');
  const caio = Candidate(id: 'caio', name: 'Caio');

  const voters = [
    ElectionVoter(id: '1', name: 'Ana', email: '', kind: VoterKind.member, status: VoterStatus.approved),
    ElectionVoter(id: '2', name: 'Maria', email: 'm@x', kind: VoterKind.guest, status: VoterStatus.approved),
    ElectionVoter(id: '3', name: 'Intruso', email: '', kind: VoterKind.guest, status: VoterStatus.rejected),
    ElectionVoter(id: '4', name: 'Pendente', email: '', kind: VoterKind.guest, status: VoterStatus.pending),
  ];

  const cargos = [
    ElectionCargo(
      position: 'presidente', stage: CargoStage.decided, cycle: 1,
      candidates: [CandidateVotes(id: 'ana', name: 'Ana', votes: 3), CandidateVotes(id: 'bia', name: 'Bia', votes: 2)],
      tiedIds: [], winnerId: 'ana',
    ),
    ElectionCargo(
      position: 'vice', stage: CargoStage.decided, cycle: 1,
      candidates: [CandidateVotes(id: 'ana', name: 'Ana', votes: 3), CandidateVotes(id: 'bia', name: 'Bia', votes: 3)],
      tiedIds: [], winnerId: 'bia',
    ),
    ElectionCargo(
      position: 'tesoureiro', stage: CargoStage.idle, cycle: 1,
      candidates: [], tiedIds: [], winnerId: null,
    ),
  ];

  final rounds = [
    round('r1', 'presidente', 1, [ana, bia, caio],
        result(counts: {'ana': 3, 'bia': 2, 'caio': 1}, blank: 1, total: 7, threshold: 6)),
    round('r2', 'presidente', 2, [ana, bia],
        result(counts: {'ana': 6, 'bia': 2}, total: 8, winnerId: 'ana')),
    round('r3', 'vice', 3, [ana, bia],
        result(counts: {'ana': 3, 'bia': 3}, total: 6, tie: ['ana', 'bia'], divergence: true)),
  ];

  final events = [
    ElectionEvent(id: '3', type: 'candidate_removed', at: DateTime(2026, 10, 20, 19, 50),
        data: const {'position': 'presidente', 'candidateName': 'Caio'}),
    ElectionEvent(id: '4', type: 'oldest_picked', at: DateTime(2026, 10, 20, 20, 30),
        data: const {'position': 'vice', 'candidateName': 'Bia'}),
    ElectionEvent(id: '2', type: 'scrutiny_started', at: DateTime(2026, 10, 20, 19, 40),
        data: const {'position': 'presidente', 'number': 1}),
    ElectionEvent(id: '1', type: 'election_opened', at: DateTime(2026, 10, 20, 19, 10), data: const {}),
  ];

  final text = buildMinutesText(
    election: election, cargos: cargos, voters: voters, rounds: rounds, events: events,
  );

  test('cabeçalho', () {
    expect(text, contains('ATA DA ELEIÇÃO — Eleição 2026'));
    expect(text, contains('Sociedade: UMP'));
    expect(text, contains('20/10/2026 19:05'));
    expect(text, contains('Encerrada'));
  });

  test('presentes: só os liberados, com o tipo', () {
    expect(text, contains('PRESENTES (2)'));
    expect(text, contains('- Ana (membro)'));
    expect(text, contains('- Maria (convidado)'));
    expect(text, isNot(contains('Intruso')));
    expect(text, isNot(contains('Pendente')));
  });

  test('cada escrutínio com contagem por opção, branco e total', () {
    expect(text, contains('1º escrutínio'));
    expect(text, contains('Ana: 3'));
    expect(text, contains('Bia: 2'));
    expect(text, contains('Branco: 1'));
    expect(text, contains('total 7'));
  });

  test('a meta de votos aparece do 2º escrutínio em diante, não no 1º', () {
    expect(text, contains('6 de 10 necessários'));
    final firstRoundLine = text.split('\n').firstWhere((l) => l.contains('1º escrutínio'));
    expect(firstRoundLine, isNot(contains('necessários')));
  });

  test('quem declinou, empate, mais velho escolhido e eleitos', () {
    expect(text, contains('Removido(a) como candidato(a): Caio'));
    expect(text, contains('Empate entre: Ana, Bia'));
    expect(text, contains('Mais velho(a) escolhido(a): Bia'));
    expect(text, contains('Eleito(a): Ana'));
    expect(text, contains('Eleito(a): Bia'));
  });

  test('divergência de contagem é destacada', () {
    expect(text, contains('ATENÇÃO'));
  });

  test('cargo sem escrutínio aparece como não votado, com o nome do cargo', () {
    expect(text, contains('Tesoureiro(a)'));
    expect(text, contains('Não votado'));
  });

  test('linha do tempo ordenada por horário, com rótulos legíveis', () {
    final i1 = text.indexOf('19:10');
    final i2 = text.indexOf('19:40');
    expect(i1, greaterThan(-1));
    expect(i2, greaterThan(i1));
    expect(text, contains('Eleição aberta'));
    expect(text, contains('Escrutínio iniciado — Presidente (1º)'));
  });

  test('o 1º e o 2º secretários têm nomes distintos', () {
    final t = buildMinutesText(
      election: Election(
        id: 'e', societyId: 's', societyName: 'UMP', title: 'T',
        scheduledAt: DateTime(2026, 1, 1), status: ElectionStatus.open,
        positions: const ['presidente', 'vice', 'secretario', 'secretario2'],
        directorIds: const [],
      ),
      cargos: const [], voters: const [], rounds: const [], events: const [],
    );
    expect(t, contains('1º Secretário(a)'));
    expect(t, contains('2º Secretário(a)'));
  });
}
