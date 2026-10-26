DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

List<String> _strings(Object? value) =>
    value is List ? value.map((e) => e.toString()).toList() : const [];

T _parse<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

enum ElectionStatus {
  draft,
  open,
  closed;

  static ElectionStatus parse(Object? raw) =>
      _parse(values, raw, ElectionStatus.draft);
}

enum RoundStatus {
  open,
  closed;

  static RoundStatus parse(Object? raw) => _parse(values, raw, RoundStatus.open);
}

enum VoterStatus {
  pending,
  approved,
  rejected;

  static VoterStatus parse(Object? raw) =>
      _parse(values, raw, VoterStatus.pending);
}

enum VoterKind {
  member,
  guest;

  static VoterKind parse(Object? raw) => _parse(values, raw, VoterKind.guest);
}

/// Fase de um cargo no rito dos escrutínios.
enum CargoStage {
  idle,
  scrutiny1,
  confirming,
  scrutiny2,
  awaiting3,
  scrutiny3,
  tiebreak,
  decided;

  static CargoStage parse(Object? raw) => _parse(values, raw, CargoStage.idle);
}

class Candidate {
  const Candidate({required this.id, required this.name});

  final String id;
  final String name;

  factory Candidate.fromJson(Map<String, dynamic> json) => Candidate(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Candidato que sobrou do 1º escrutínio, com os votos que recebeu nele.
class CandidateVotes {
  const CandidateVotes({
    required this.id,
    required this.name,
    required this.votes,
  });

  final String id;
  final String name;
  final int votes;

  factory CandidateVotes.fromJson(Map<String, dynamic> json) => CandidateVotes(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        votes: (json['votes'] as num?)?.toInt() ?? 0,
      );
}

class RoundResult {
  const RoundResult({
    required this.counts,
    required this.blank,
    required this.total,
    required this.presentCount,
    required this.threshold,
    required this.winnerId,
    required this.tie,
    required this.divergence,
  });

  final Map<String, int> counts;
  final int blank;
  final int total;
  final int presentCount;
  final int threshold;
  final String? winnerId;
  final List<String> tie;
  final bool divergence;

  factory RoundResult.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    return RoundResult(
      counts: rawCounts is Map
          ? rawCounts.map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
          : const {},
      blank: (json['blank'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      threshold: (json['threshold'] as num?)?.toInt() ?? 0,
      winnerId: json['winnerId']?.toString(),
      tie: _strings(json['tie']),
      divergence: json['divergence'] == true,
    );
  }
}

class Election {
  const Election({
    required this.id,
    required this.societyId,
    required this.societyName,
    required this.title,
    required this.scheduledAt,
    required this.status,
    required this.positions,
    required this.directorIds,
    this.boardAppliedAt,
  });

  final String id;
  final String societyId;
  final String societyName;
  final String title;
  final DateTime scheduledAt;
  final ElectionStatus status;
  final List<String> positions;
  final List<String> directorIds;
  final DateTime? boardAppliedAt;

  factory Election.fromJson(String id, Map<String, dynamic> json) => Election(
        id: id,
        societyId: json['societyId']?.toString() ?? '',
        societyName: json['societyName']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        scheduledAt:
            _date(json['scheduledAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        status: ElectionStatus.parse(json['status']),
        positions: _strings(json['positions']),
        directorIds: _strings(json['directorIds']),
        boardAppliedAt: _date(json['boardAppliedAt']),
      );
}

/// Estado de um cargo (documento `cargos/{position}`).
class ElectionCargo {
  const ElectionCargo({
    required this.position,
    required this.stage,
    required this.cycle,
    required this.candidates,
    required this.tiedIds,
    required this.winnerId,
  });

  final String position;
  final CargoStage stage;
  final int cycle;
  final List<CandidateVotes> candidates;
  final List<String> tiedIds;
  final String? winnerId;

  factory ElectionCargo.fromJson(String position, Map<String, dynamic> json) {
    final raw = json['candidates'];
    return ElectionCargo(
      position: position,
      stage: CargoStage.parse(json['stage']),
      cycle: (json['cycle'] as num?)?.toInt() ?? 1,
      candidates: raw is List
          ? raw
              .map((c) =>
                  CandidateVotes.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList()
          : const [],
      tiedIds: _strings(json['tiedIds']),
      winnerId: json['winnerId']?.toString(),
    );
  }
}

/// Um escrutínio (documento `rounds/{id}`).
class ElectionRound {
  const ElectionRound({
    required this.id,
    required this.position,
    required this.cycle,
    required this.number,
    required this.status,
    required this.options,
    required this.votedCount,
    this.result,
    this.closedAt,
  });

  final String id;
  final String position;
  final int cycle;
  final int number;
  final RoundStatus status;
  final List<Candidate> options;
  final int votedCount;
  final RoundResult? result;
  final DateTime? closedAt;

  factory ElectionRound.fromJson(String id, Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final rawResult = json['result'];
    return ElectionRound(
      id: id,
      position: json['position']?.toString() ?? '',
      cycle: (json['cycle'] as num?)?.toInt() ?? 1,
      number: (json['number'] as num?)?.toInt() ?? 1,
      status: RoundStatus.parse(json['status']),
      options: rawOptions is List
          ? rawOptions
              .map((c) => Candidate.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList()
          : const [],
      votedCount: (json['votedCount'] as num?)?.toInt() ?? 0,
      result: rawResult is Map
          ? RoundResult.fromJson(Map<String, dynamic>.from(rawResult))
          : null,
      closedAt: _date(json['closedAt']),
    );
  }
}

class ElectionVoter {
  const ElectionVoter({
    required this.id,
    required this.name,
    required this.email,
    required this.kind,
    required this.status,
  });

  final String id;
  final String name;
  final String email;
  final VoterKind kind;
  final VoterStatus status;

  factory ElectionVoter.fromJson(String id, Map<String, dynamic> json) =>
      ElectionVoter(
        id: id,
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        kind: VoterKind.parse(json['kind']),
        status: VoterStatus.parse(json['status']),
      );
}

class ElectionEvent {
  const ElectionEvent({
    required this.id,
    required this.type,
    required this.at,
    required this.data,
  });

  final String id;
  final String type;
  final DateTime? at;
  final Map<String, dynamic> data;

  factory ElectionEvent.fromJson(String id, Map<String, dynamic> json) =>
      ElectionEvent(
        id: id,
        type: json['type']?.toString() ?? '',
        at: _date(json['at']),
        data: Map<String, dynamic>.from(json),
      );
}
