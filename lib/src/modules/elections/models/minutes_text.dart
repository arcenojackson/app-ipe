import 'election.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _dateTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

const _positionLabels = {
  'presidente': 'Presidente',
  'vice': 'Vice',
  'secretario': '1º Secretário(a)',
  'secretario2': '2º Secretário(a)',
  'tesoureiro': 'Tesoureiro(a)',
};

String positionLabel(String position) => _positionLabels[position] ?? position;

String _statusLabel(ElectionStatus s) => switch (s) {
      ElectionStatus.draft => 'Rascunho',
      ElectionStatus.open => 'Em andamento',
      ElectionStatus.closed => 'Encerrada',
    };

String _nameOf(ElectionCargo? cargo, List<ElectionRound> rounds, String id) {
  for (final c in cargo?.candidates ?? const <CandidateVotes>[]) {
    if (c.id == id) return c.name;
  }
  for (final r in rounds) {
    for (final o in r.options) {
      if (o.id == id) return o.name;
    }
  }
  return id;
}

String _eventLine(ElectionEvent e) {
  final cargo = positionLabel((e.data['position'] ?? '').toString());
  final number = e.data['number'];
  final label = switch (e.type) {
    'election_opened' => 'Eleição aberta',
    'election_closed' => 'Eleição encerrada',
    'scrutiny_started' => 'Escrutínio iniciado — $cargo ($numberº)',
    'scrutiny_closed' => 'Escrutínio encerrado — $cargo ($numberº)',
    'board_applied' => 'Diretoria aplicada na sociedade',
    _ => null,
  };
  if (label == null || e.at == null) return '';
  return '- ${_time(e.at!)} $label';
}

/// Ata da eleição em texto puro, gerada do que está gravado: presentes,
/// escrutínios de cada cargo e o log de eventos.
String buildMinutesText({
  required Election election,
  required List<ElectionCargo> cargos,
  required List<ElectionVoter> voters,
  required List<ElectionRound> rounds,
  required List<ElectionEvent> events,
}) {
  final b = StringBuffer()
    ..writeln('ATA DA ELEIÇÃO — ${election.title}')
    ..writeln('Sociedade: ${election.societyName}')
    ..writeln('Data: ${_dateTime(election.scheduledAt)}')
    ..writeln('Situação: ${_statusLabel(election.status)}')
    ..writeln();

  final present =
      voters.where((v) => v.status == VoterStatus.approved).toList();
  b.writeln('PRESENTES (${present.length})');
  for (final v in present) {
    b.writeln(
      '- ${v.name} (${v.kind == VoterKind.member ? 'membro' : 'convidado'})',
    );
  }
  b.writeln();

  b.writeln('CARGOS');
  for (final position in election.positions) {
    final cargo = cargos.where((c) => c.position == position).firstOrNull;
    final list = rounds
        .where((r) => r.position == position && r.status == RoundStatus.closed)
        .toList()
      ..sort((a, c) => a.cycle != c.cycle
          ? a.cycle.compareTo(c.cycle)
          : a.number.compareTo(c.number));
    b.writeln(positionLabel(position));
    if (list.isEmpty) {
      b.writeln('  Não votado');
      continue;
    }
    for (final r in list) {
      final res = r.result;
      if (res == null) continue;
      final parts = [
        for (final o in r.options) '${o.name}: ${res.counts[o.id] ?? 0}',
        'Branco: ${res.blank}',
      ];
      final prefix = r.cycle > 1 ? 'Ciclo ${r.cycle} · ' : '';
      final goal = r.number > 1
          ? ' — ${res.threshold} de ${res.presentCount} necessários'
          : '';
      b.writeln(
        '  $prefix${r.number}º escrutínio — ${parts.join(' · ')} '
        '(total ${res.total})$goal',
      );
      if (res.tie.isNotEmpty) {
        b.writeln(
          '  Empate entre: ${res.tie.map((id) => _nameOf(cargo, list, id)).join(', ')}',
        );
      }
      if (res.divergence) {
        b.writeln(
          '  ATENÇÃO: a contagem diverge do número de votantes '
          '(${res.total} votos contados).',
        );
      }
    }
    for (final e in events.where((e) =>
        e.data['position'] == position && e.type == 'candidate_removed')) {
      b.writeln('  Removido(a) como candidato(a): ${e.data['candidateName']}');
    }
    for (final e in events.where(
        (e) => e.data['position'] == position && e.type == 'oldest_picked')) {
      b.writeln('  Mais velho(a) escolhido(a): ${e.data['candidateName']}');
    }
    if (cargo?.stage == CargoStage.decided && cargo?.winnerId != null) {
      b.writeln('  Eleito(a): ${_nameOf(cargo, list, cargo!.winnerId!)}');
    } else {
      b.writeln('  Sem eleito(a) até agora');
    }
  }
  b.writeln();

  final timeline = events.where((e) => e.at != null).toList()
    ..sort((a, c) => a.at!.compareTo(c.at!));
  final lines = timeline.map(_eventLine).where((l) => l.isNotEmpty).toList();
  if (lines.isNotEmpty) {
    b.writeln('LINHA DO TEMPO');
    for (final l in lines) {
      b.writeln(l);
    }
  }
  return b.toString().trimRight();
}
