import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../elections/data/elections_repository.dart';
import '../../../elections/models/election.dart';
import '../../../elections/presentation/election_vote_page.dart';
import 'announcement_card.dart';

/// Balão "Eleição aberta!" na home: um cartão por eleição aberta da qual o
/// usuário foi convidado. Fica até a eleição encerrar (é o caminho de volta
/// para a votação).
///
/// Um listener do Firestore que falha (regras ainda sem efeito, rede caída)
/// morre e não volta sozinho; por isso o balão ouve de novo após um erro e
/// sempre que o app volta para o primeiro plano.
class ElectionInviteBanner extends StatefulWidget {
  const ElectionInviteBanner({
    super.key,
    required this.uid,
    this.retryDelay = const Duration(seconds: 10),
  });

  final String uid;
  final Duration retryDelay;

  @override
  State<ElectionInviteBanner> createState() => _ElectionInviteBannerState();
}

class _ElectionInviteBannerState extends State<ElectionInviteBanner>
    with WidgetsBindingObserver {
  StreamSubscription<List<ElectionInvite>>? _sub;
  Timer? _retry;
  List<ElectionInvite> _invites = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  void _listen() {
    _retry?.cancel();
    _sub?.cancel();
    _sub = context
        .read<ElectionsRepository>()
        .watchOpenInvites(widget.uid)
        .listen((invites) {
          if (mounted) setState(() => _invites = invites);
        }, onError: (_) => _retry = Timer(widget.retryDelay, _listen));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _listen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final invite in _invites)
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
  }
}
