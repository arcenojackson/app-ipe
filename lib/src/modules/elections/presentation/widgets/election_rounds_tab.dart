import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/state/app_state.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../people/data/people_repository.dart';
import '../../../societies/data/societies_repository.dart';
import '../../data/elections_repository.dart';
import '../../models/election.dart';
import '../../models/election_logic.dart';
import '../../models/minutes_text.dart' show positionLabel;
import 'candidate_picker_sheet.dart';

class ElectionRoundsTab extends StatefulWidget {
  const ElectionRoundsTab({super.key, required this.election});

  final Election election;

  @override
  State<ElectionRoundsTab> createState() => _ElectionRoundsTabState();
}

class _ElectionRoundsTabState extends State<ElectionRoundsTab> {
  late final Stream<List<ElectionRound>> _rounds;
  late final Stream<List<ElectionVoter>> _voters;
  List<Candidate>? _members;

  ElectionsRepository get _repo => context.read<ElectionsRepository>();

  @override
  void initState() {
    super.initState();
    _rounds = _repo.watchRounds(widget.election.id);
    _voters = _repo.watchVoters(widget.election.id);
  }

  Future<List<Candidate>> _loadMembers() async {
    final cached = _members;
    if (cached != null) return cached;
    final society = await context
        .read<SocietiesRepository>()
        .fetchById(widget.election.societyId);
    if (!mounted) return const [];
    final people = await context
        .read<PeopleRepository>()
        .fetchAll(currentUser: context.read<AppState>().currentUser);
    final members = [
      for (final u in people)
        if (society.membersIds.contains(u.id))
          Candidate(id: u.id, name: u.name),
    ]..sort((a, b) => a.name.compareTo(b.name));
    _members = members;
    return members;
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      showErrorToast(context, e.toString());
    }
  }

  Future<void> _editCandidates(
    String position,
    List<ElectionRound> rounds, {
    ElectionRound? round,
  }) {
    return _guard(() async {
      final members = await _loadMembers();
      if (!mounted) return;
      final options = candidateOptions(
        members: members,
        rounds: rounds,
        position: position,
      );
      final picked = await showModalBottomSheet<List<Candidate>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CandidatePickerSheet(
          options: options,
          initial: round?.candidates ?? const [],
        ),
      );
      if (picked == null || !mounted) return;
      await _repo.saveRoundCandidates(
        electionId: widget.election.id,
        position: position,
        candidates: picked,
        roundId: round?.id,
      );
    });
  }

  Future<void> _createRunoff(
    String position,
    RoundResult result,
    ElectionRound from,
  ) {
    return _guard(() async {
      final tied = [
        for (final c in from.candidates)
          if (result.tie.contains(c.id)) c,
      ];
      await _repo.saveRoundCandidates(
        electionId: widget.election.id,
        position: position,
        candidates: tied,
        type: RoundType.runoff,
      );
    });
  }

  Future<void> _closeRound(ElectionRound round) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar votação?'),
        content: Text(
          'Nenhum voto novo será aceito para ${positionLabel(round.position)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(() async {
      await _repo.closeRound(widget.election.id, round.id);
    });
  }

  Widget _card({
    required String title,
    String? subtitle,
    List<Widget> actions = const [],
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roundCard(
    String position,
    ElectionRound round,
    List<ElectionRound> all,
    int approved,
  ) {
    final election = widget.election;
    final canOperate = election.status == ElectionStatus.open;
    String nameOf(String id) =>
        round.candidates
            .where((c) => c.id == id)
            .map((c) => c.name)
            .firstOrNull ??
        id;

    switch (round.status) {
      case RoundStatus.pending:
        return _card(
          title: round.type == RoundType.runoff ? 'Desempate' : 'Candidatos',
          subtitle: round.candidates.map((c) => c.name).join(', '),
          actions: [
            OutlinedButton(
              onPressed: () => _editCandidates(position, all, round: round),
              child: const Text('Editar candidatos'),
            ),
            OutlinedButton(
              onPressed: () =>
                  _guard(() => _repo.deleteRound(election.id, round.id)),
              child: const Text('Remover'),
            ),
            FilledButton(
              onPressed: canOperate
                  ? () => _guard(() => _repo.openRound(election.id, round.id))
                  : null,
              child: const Text('Abrir votação'),
            ),
          ],
        );
      case RoundStatus.open:
        return _card(
          title: 'Votação em andamento',
          subtitle: '${round.votedCount} de $approved votaram · '
              '${round.candidates.map((c) => c.name).join(', ')}',
          actions: [
            FilledButton(
              onPressed: () => _closeRound(round),
              child: const Text('Encerrar votação'),
            ),
          ],
        );
      case RoundStatus.closed:
        final result = round.result;
        final String text;
        if (result == null) {
          text = 'Encerrada';
        } else if (result.winnerId != null) {
          text = 'Eleito(a): ${nameOf(result.winnerId!)}';
        } else if (result.tie.isNotEmpty) {
          text = 'Empate: ${result.tie.map(nameOf).join(', ')}';
        } else {
          text = 'Ninguém foi eleito(a)';
        }
        return _card(
          title: text,
          subtitle: result == null
              ? null
              : '${result.total} votos'
                  '${result.divergence ? ' · ATENÇÃO: contagem divergente' : ''}',
          actions: [
            if (result != null && result.tie.isNotEmpty)
              OutlinedButton(
                onPressed: () => _createRunoff(position, result, round),
                child: const Text('Criar desempate'),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ElectionRound>>(
      stream: _rounds,
      builder: (context, roundsSnap) {
        return StreamBuilder<List<ElectionVoter>>(
          stream: _voters,
          builder: (context, votersSnap) {
            if (roundsSnap.hasError) {
              return Center(child: Text('Erro: ${roundsSnap.error}'));
            }
            if (!roundsSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rounds = roundsSnap.data!;
            final approved = (votersSnap.data ?? const <ElectionVoter>[])
                .where((v) => v.status == VoterStatus.approved)
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                for (final position in widget.election.positions) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(
                      positionLabel(position),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final r in rounds.where((r) => r.position == position))
                    _roundCard(position, r, rounds, approved),
                  if (!rounds.any(
                    (r) =>
                        r.position == position &&
                        (r.status == RoundStatus.pending ||
                            r.status == RoundStatus.open),
                  ))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.person_add_alt),
                        label: Text(
                          rounds.any((r) => r.position == position)
                              ? 'Nova votação para este cargo'
                              : 'Definir candidatos',
                        ),
                        onPressed: () => _editCandidates(position, rounds),
                      ),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
