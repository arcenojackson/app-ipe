import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/utils/app_toast.dart';
import '../../data/elections_repository.dart';
import '../../models/election.dart';
import '../../models/election_logic.dart';

class ElectionVotersTab extends StatefulWidget {
  const ElectionVotersTab({super.key, required this.election});

  final Election election;

  @override
  State<ElectionVotersTab> createState() => _ElectionVotersTabState();
}

class _ElectionVotersTabState extends State<ElectionVotersTab> {
  late final Stream<List<ElectionVoter>> _stream;

  @override
  void initState() {
    super.initState();
    _stream =
        context.read<ElectionsRepository>().watchVoters(widget.election.id);
  }

  Future<void> _review(ElectionVoter voter, VoterStatus decision) async {
    try {
      await context
          .read<ElectionsRepository>()
          .reviewVoter(widget.election.id, voter.id, decision);
    } catch (e) {
      if (!mounted) return;
      showErrorToast(context, e.toString());
    }
  }

  Widget _tile(
    ElectionVoter v,
    Set<String> duplicates, {
    required bool pending,
  }) {
    return ListTile(
      title: Text(v.name),
      subtitle: Text(
        [
          v.kind == VoterKind.member ? 'Membro' : 'Convidado',
          if (v.email.isNotEmpty) v.email,
        ].join(' · '),
      ),
      leading: duplicates.contains(v.id)
          ? const Tooltip(
              message: 'Mesmo nome ou e-mail de outra pessoa na lista',
              child: Icon(Icons.warning_amber, color: Colors.amber),
            )
          : null,
      trailing: pending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Recusar',
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  onPressed: () => _review(v, VoterStatus.rejected),
                ),
                IconButton(
                  tooltip: 'Aprovar',
                  icon: const Icon(Icons.check, color: Colors.greenAccent),
                  onPressed: () => _review(v, VoterStatus.approved),
                ),
              ],
            )
          : v.status == VoterStatus.rejected
              ? TextButton(
                  onPressed: () => _review(v, VoterStatus.approved),
                  child: const Text('Aprovar'),
                )
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ElectionVoter>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final voters = snapshot.data!;
        if (voters.isEmpty) {
          return const Center(
            child: Text(
              'Ninguém entrou ainda.\nCompartilhe o link para o pessoal votar.',
              textAlign: TextAlign.center,
            ),
          );
        }
        final duplicates = duplicateVoterIds(voters);
        final pending =
            voters.where((v) => v.status == VoterStatus.pending).toList();
        final approved =
            voters.where((v) => v.status == VoterStatus.approved).toList();
        final rejected =
            voters.where((v) => v.status == VoterStatus.rejected).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            if (pending.isNotEmpty) ...[
              _Header('Aguardando aprovação (${pending.length})'),
              for (final v in pending) _tile(v, duplicates, pending: true),
            ],
            _Header('Liberados (${approved.length})'),
            for (final v in approved) _tile(v, duplicates, pending: false),
            if (rejected.isNotEmpty) ...[
              _Header('Recusados (${rejected.length})'),
              for (final v in rejected) _tile(v, duplicates, pending: false),
            ],
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Colors.white70),
        ),
      );
}
