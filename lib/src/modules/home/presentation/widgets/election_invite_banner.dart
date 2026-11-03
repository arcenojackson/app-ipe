import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../elections/data/elections_repository.dart';
import '../../../elections/models/election.dart';
import '../../../elections/presentation/election_vote_page.dart';
import 'announcement_card.dart';

/// Balão "Eleição aberta!" na home: um cartão por eleição aberta da qual o
/// usuário foi convidado. Fica até a eleição encerrar (é o caminho de volta
/// para a votação).
class ElectionInviteBanner extends StatefulWidget {
  const ElectionInviteBanner({super.key, required this.uid});

  final String uid;

  @override
  State<ElectionInviteBanner> createState() => _ElectionInviteBannerState();
}

class _ElectionInviteBannerState extends State<ElectionInviteBanner> {
  late final Stream<List<ElectionInvite>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<ElectionsRepository>().watchOpenInvites(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ElectionInvite>>(
      stream: _stream,
      builder: (context, snapshot) {
        // Erro (ex.: regras ainda não publicadas) ou sem dados: sem balão.
        final invites = snapshot.data ?? const <ElectionInvite>[];
        return Column(
          children: [
            for (final invite in invites)
              AnnouncementCard(
                key: ValueKey('election-invite-${invite.id}'),
                icon: Icons.how_to_vote_rounded,
                title: 'Eleição aberta!',
                subtitle: '${invite.title} · ${invite.societyName}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ElectionVotePage(electionId: invite.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
