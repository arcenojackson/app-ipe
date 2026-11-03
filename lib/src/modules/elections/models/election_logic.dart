import '../../societies/models/society.dart';
import 'election.dart';

/// URL base do portal web (votação em /votar/{id}, condução em /eleicoes/{id}).
/// Fica aqui, e não em AppConfig, para a lógica continuar testável sem o
/// `app_secrets.dart` (gitignorado) que AppConfig importa.
const String portalBaseUrl = String.fromEnvironment(
  'PORTAL_BASE_URL',
  defaultValue: 'https://ipe-ensino.vercel.app',
);

/// Título sugerido ao criar uma eleição.
String defaultElectionTitle(String societyName, int year) {
  final name = societyName.trim();
  return name.isEmpty
      ? 'Eleição da diretoria $year'
      : 'Eleição da diretoria $name $year';
}

/// Link que as pessoas abrem (QR) para votar.
String buildVoteLink(String electionId) => '$portalBaseUrl/votar/$electionId';

/// Link da tela web em que os diretores conduzem a eleição.
String buildConductLink(String electionId) =>
    '$portalBaseUrl/eleicoes/$electionId';

/// Sociedades em que [userId] está na diretoria (qualquer cargo): só nelas a
/// pessoa pode criar eleição. O servidor repete essa conferência.
List<SocietyModel> directorSocieties(
  List<SocietyModel> societies,
  String userId,
) =>
    societies.where((s) => s.allBoardIds.contains(userId)).toList();

/// Eleições que [userId] pode ver na lista: só as de sociedades em que ele
/// ainda está na diretoria. `directorIds` da eleição é um snapshot da criação e
/// não encolhe, então quem saiu da diretoria continua nele; a sociedade atual é
/// a fonte de verdade para a lista.
List<Election> electionsOfCurrentDirector(
  List<Election> elections,
  List<SocietyModel> societies,
  String userId,
) {
  final ids = directorSocieties(societies, userId).map((s) => s.id).toSet();
  return elections.where((e) => ids.contains(e.societyId)).toList();
}

final RegExp _bareElectionId = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

/// Id da eleição a partir do que o QR (ou o campo manual) trouxe: só o caminho
/// `/votar/{id}` importa, o host é ignorado (produção, preview ou emulador).
/// Também aceita o id solto (campo manual); a câmera passa
/// `allowBareId: false`, para um QR qualquer (código de produto, palavra) não
/// virar tentativa de entrar numa eleição. Qualquer outra coisa devolve `null`.
String? parseElectionId(String raw, {bool allowBareId = true}) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (allowBareId && _bareElectionId.hasMatch(text)) return text;
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length < 2) return null;
  if (segments[segments.length - 2] != 'votar') return null;
  final id = segments.last;
  return _bareElectionId.hasMatch(id) ? id : null;
}

String _normalizeName(String text) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().trim().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}

/// Filtra por nome sem diferenciar maiúsculas nem acentos; mantém a ordem.
List<Candidate> filterCandidates(List<Candidate> options, String query) {
  final q = _normalizeName(query);
  if (q.isEmpty) return options;
  return options.where((c) => _normalizeName(c.name).contains(q)).toList();
}

/// Valor que ainda pode estar chegando do Firestore (`null` é um valor válido:
/// "carregou e não existe").
class Loadable<T> {
  const Loadable(T this._value) : isLoaded = true;
  const Loadable.loading() : _value = null, isLoaded = false;

  final bool isLoaded;
  final T? _value;

  T get value => _value as T;
}

enum VoteViewKind {
  loading,
  notFound,
  notOpen,
  closed,
  needsCheckIn,
  notMember,
  waitingRound,
  ballot,
  voted,
}

class VoteView {
  const VoteView(this.kind, [this.round]);

  final VoteViewKind kind;

  /// Só nos estados `ballot` e `voted`.
  final ElectionRound? round;
}

/// Em que ponto da votação o membro está. Mesma ordem de decisão do portal web
/// (`web-portal/src/modules/elections/voteState.ts`).
VoteView deriveVoteView({
  required Loadable<Election?> election,
  required Loadable<ElectionVoter?> voter,
  required Loadable<ElectionRound?> openRound,
  required Loadable<bool> hasVoted,
}) {
  if (!election.isLoaded) return const VoteView(VoteViewKind.loading);
  final e = election.value;
  if (e == null) return const VoteView(VoteViewKind.notFound);
  if (e.status == ElectionStatus.draft) {
    return const VoteView(VoteViewKind.notOpen);
  }
  if (e.status == ElectionStatus.closed) {
    return const VoteView(VoteViewKind.closed);
  }

  if (!voter.isLoaded) return const VoteView(VoteViewKind.loading);
  final v = voter.value;
  if (v == null) return const VoteView(VoteViewKind.needsCheckIn);
  if (v.status != VoterStatus.approved || v.kind != VoterKind.member) {
    return const VoteView(VoteViewKind.notMember);
  }

  if (!openRound.isLoaded) return const VoteView(VoteViewKind.loading);
  final round = openRound.value;
  if (round == null) return const VoteView(VoteViewKind.waitingRound);
  if (!hasVoted.isLoaded) return const VoteView(VoteViewKind.loading);
  return VoteView(
    hasVoted.value ? VoteViewKind.voted : VoteViewKind.ballot,
    round,
  );
}

/// Convites que ainda valem: só os de eleição aberta. [statusById] traz o
/// status atual de cada eleição; id sem status conhecido fica de fora.
List<ElectionInvite> invitesToShow(
  List<ElectionInvite> invites,
  Map<String, ElectionStatus> statusById,
) => invites.where((i) => statusById[i.id] == ElectionStatus.open).toList();

/// Id da eleição num push `election_open`; `null` para qualquer outro push.
String? electionIdFromPush(Map<String, dynamic> data) {
  if (data['type'] != 'election_open') return null;
  final id = data['electionId']?.toString().trim() ?? '';
  return id.isEmpty ? null : id;
}
