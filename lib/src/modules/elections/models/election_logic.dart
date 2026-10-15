import 'election.dart';

/// URL base do portal web (página pública de votação em /votar/{id}).
/// Fica aqui, e não em AppConfig, para a lógica continuar testável sem o
/// `app_secrets.dart` (gitignorado) que AppConfig importa.
const String portalBaseUrl = String.fromEnvironment(
  'PORTAL_BASE_URL',
  defaultValue: 'https://ipe-ensino.vercel.app',
);

/// Vencedor de cada cargo (cargo → id do candidato): vale a rodada fechada
/// mais recente do cargo; sem vencedor nela, o cargo fica sem vencedor.
/// Espelha `pickWinners` das Functions.
Map<String, String> latestWinners(List<ElectionRound> rounds) {
  final latest = <String, ElectionRound>{};
  for (final r in rounds) {
    if (r.status != RoundStatus.closed) continue;
    final current = latest[r.position];
    final ms = r.closedAt?.millisecondsSinceEpoch ?? 0;
    final currentMs = current?.closedAt?.millisecondsSinceEpoch ?? 0;
    if (current == null || ms >= currentMs) latest[r.position] = r;
  }
  return {
    for (final e in latest.entries)
      if (e.value.result?.winnerId != null) e.key: e.value.result!.winnerId!,
  };
}

/// Membros que ainda podem ser candidatos ao cargo: tira quem já foi eleito
/// em OUTRO cargo. (O servidor repete essa regra ao abrir a votação.)
List<Candidate> candidateOptions({
  required List<Candidate> members,
  required List<ElectionRound> rounds,
  required String position,
}) {
  final others = rounds.where((r) => r.position != position).toList();
  final elected = latestWinners(others).values.toSet();
  return members.where((m) => !elected.contains(m.id)).toList();
}

/// Ids de eleitores que dividem e-mail (não vazio) ou nome com outro.
Set<String> duplicateVoterIds(List<ElectionVoter> voters) {
  final byEmail = <String, List<String>>{};
  final byName = <String, List<String>>{};
  for (final v in voters) {
    final email = v.email.trim().toLowerCase();
    final name = v.name.trim().toLowerCase();
    if (email.isNotEmpty) byEmail.putIfAbsent(email, () => []).add(v.id);
    if (name.isNotEmpty) byName.putIfAbsent(name, () => []).add(v.id);
  }
  return {
    for (final ids in [...byEmail.values, ...byName.values])
      if (ids.length > 1) ...ids,
  };
}

String buildVoteLink(String electionId) =>
    '$portalBaseUrl/votar/$electionId';
