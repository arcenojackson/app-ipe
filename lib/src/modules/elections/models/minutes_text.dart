import '../../societies/models/society.dart';
import 'election.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _dateTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String positionLabel(String position) =>
    BoardPosition.fromString(position)?.label ?? position;

String _statusLabel(ElectionStatus s) => switch (s) {
      ElectionStatus.draft => 'Rascunho',
      ElectionStatus.open => 'Em andamento',
      ElectionStatus.closed => 'Encerrada',
    };

String _candidateName(ElectionRound round, String id) {
  for (final c in round.candidates) {
    if (c.id == id) return c.name;
  }
  return id;
}

String _eventLine(ElectionEvent e) {
  final cargo = positionLabel((e.data['position'] ?? '').toString());
  final label = switch (e.type) {
    'election_opened' => 'Eleição aberta',
    'election_closed' => 'Eleição encerrada',
    'round_opened' => 'Votação aberta — $cargo',
    'round_closed' => 'Votação encerrada — $cargo',
    'board_applied' => 'Diretoria aplicada na sociedade',
    _ => null,
  };
  if (label == null || e.at == null) return '';
  return '- ${_time(e.at!)} $label';
}

/// Ata da eleição em texto puro, gerada do que está gravado (presentes,
/// rodadas apuradas e log de eventos).
String buildMinutesText({
  required Election election,
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

  b.writeln('VOTAÇÕES');
  for (final r in rounds) {
    final tipo = switch (r.type) {
      RoundType.single => 'candidato único',
      RoundType.runoff => 'desempate',
      RoundType.normal => 'maioria simples',
    };
    b.writeln('${positionLabel(r.position)} — $tipo');
    final res = r.result;
    if (r.status != RoundStatus.closed || res == null) {
      b.writeln(
        '  ${r.status == RoundStatus.open ? 'Em andamento' : 'Ainda não votada'}',
      );
      continue;
    }
    final parts = <String>[];
    if (r.type == RoundType.single) {
      parts.add('Sim: ${res.counts['yes'] ?? 0}');
      parts.add('Não: ${res.counts['no'] ?? 0}');
    } else {
      for (final c in r.candidates) {
        parts.add('${c.name}: ${res.counts[c.id] ?? 0}');
      }
    }
    parts.add('Branco: ${res.counts['blank'] ?? 0}');
    b.writeln('  ${parts.join(' · ')} (total ${res.total})');
    if (res.winnerId != null) {
      b.writeln('  Eleito(a): ${_candidateName(r, res.winnerId!)}');
    } else if (res.tie.isNotEmpty) {
      b.writeln(
        '  Empate entre: ${res.tie.map((id) => _candidateName(r, id)).join(', ')}',
      );
    } else {
      b.writeln('  Ninguém foi eleito(a).');
    }
    if (res.divergence) {
      b.writeln(
        '  ATENÇÃO: votos contados (${res.total}) diferem de votantes (${res.votedCount}).',
      );
    }
  }
  b.writeln();

  final timeline = events.where((e) => e.at != null).toList()
    ..sort((a, b) => a.at!.compareTo(b.at!));
  final lines = timeline.map(_eventLine).where((l) => l.isNotEmpty).toList();
  if (lines.isNotEmpty) {
    b.writeln('LINHA DO TEMPO');
    for (final l in lines) {
      b.writeln(l);
    }
  }
  return b.toString().trimRight();
}
