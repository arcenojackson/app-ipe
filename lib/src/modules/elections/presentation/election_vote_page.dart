import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/app_exception.dart';
import '../../../shared/state/app_state.dart';
import '../data/elections_repository.dart';
import '../models/election.dart';
import '../models/election_logic.dart';
import '../models/minutes_text.dart';
import 'election_scan_page.dart';
import 'widgets/election_ballot.dart';

const String _membersOnlyMessage = 'A votação é só para membros da sociedade.';

/// Votação do membro dentro do app: do check-in (QR do condutor) até o
/// comprovante de cada escrutínio. Tudo reage sozinho às mudanças do Firestore.
class ElectionVotePage extends StatefulWidget {
  const ElectionVotePage({super.key, required this.electionId});

  final String electionId;

  @override
  State<ElectionVotePage> createState() => _ElectionVotePageState();
}

class _ElectionVotePageState extends State<ElectionVotePage> {
  late final ElectionsRepository _repo;
  String? _uid;

  Loadable<Election?> _election = const Loadable.loading();
  Loadable<ElectionVoter?> _voter = const Loadable.loading();
  Loadable<ElectionRound?> _openRound = const Loadable.loading();
  Loadable<bool> _hasVoted = const Loadable.loading();

  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<ElectionRound?>? _roundSub;
  StreamSubscription<bool>? _votedSub;
  String? _votedRoundId;

  /// Código do comprovante por rodada, só enquanto a tela está aberta.
  final Map<String, String> _receipts = {};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = context.read<ElectionsRepository>();
    _uid = context.read<AppState>().currentUser?.id;
    final uid = _uid;
    if (uid == null) return;

    _subs.add(
      _repo
          .watchElection(widget.electionId)
          .listen(
            (e) => setState(() => _election = Loadable(e)),
            onError: _onStreamError,
          ),
    );
    _subs.add(
      _repo.watchMyVoter(widget.electionId, uid).listen((v) {
        setState(() => _voter = Loadable(v));
        _syncRound(v);
      }, onError: _onStreamError),
    );
  }

  bool _isApprovedMember(ElectionVoter? v) =>
      v != null &&
      v.status == VoterStatus.approved &&
      v.kind == VoterKind.member;

  /// A rodada só é observada depois que o membro entrou na votação.
  void _syncRound(ElectionVoter? voter) {
    if (!_isApprovedMember(voter) || _roundSub != null) return;
    _roundSub = _repo.watchOpenRound(widget.electionId).listen((round) {
      setState(() => _openRound = Loadable(round));
      _syncVoted(round?.id);
    }, onError: _onStreamError);
  }

  void _syncVoted(String? roundId) {
    if (roundId == _votedRoundId) return;
    _votedSub?.cancel();
    _votedSub = null;
    _votedRoundId = roundId;
    final uid = _uid;
    if (roundId == null || uid == null) return;
    setState(() => _hasVoted = const Loadable.loading());
    _votedSub = _repo
        .watchHasVoted(widget.electionId, roundId, uid)
        .listen(
          (voted) => setState(() => _hasVoted = Loadable(voted)),
          onError: _onStreamError,
        );
  }

  void _onStreamError(Object error) {
    if (!mounted) return;
    setState(() => _error = 'Não foi possível atualizar a votação.');
  }

  /// Abre o leitor de QR. Se a pessoa entrou em outra eleição (leu o QR de
  /// outra), segue para a votação dessa.
  Future<void> _scan() async {
    final enteredId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ElectionScanPage()),
    );
    if (!mounted || enteredId == null || enteredId == widget.electionId) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ElectionVotePage(electionId: enteredId),
      ),
    );
  }

  Future<void> _submit(ElectionRound round, String choice) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await _repo.castVote(widget.electionId, round.id, choice);
      if (mounted) setState(() => _receipts[round.id] = receipt);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Algo deu errado.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _roundSub?.cancel();
    _votedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final election = _election.isLoaded ? _election.value : null;
    final view = deriveVoteView(
      election: _election,
      voter: _voter,
      openRound: _openRound,
      hasVoted: _hasVoted,
    );

    return Scaffold(
      appBar: AppBar(title: Text(election?.title ?? 'Votação')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (election != null) ...[
            Text(
              election.societyName,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
          if (_uid == null)
            const Text('Entre na sua conta para votar.')
          else
            ..._body(view),
          if (_error != null && view.kind != VoteViewKind.ballot) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _body(VoteView view) {
    switch (view.kind) {
      case VoteViewKind.loading:
        return const [Center(child: CircularProgressIndicator())];
      case VoteViewKind.notFound:
        return const [Text('Eleição não encontrada.')];
      case VoteViewKind.notOpen:
        return const [
          Text('Esta eleição ainda não foi aberta. Aguarde o início.'),
        ];
      case VoteViewKind.closed:
        return const [Text('Esta eleição foi encerrada.')];
      case VoteViewKind.notMember:
        return const [Text(_membersOnlyMessage)];
      case VoteViewKind.needsCheckIn:
        return [
          const Text(
            'Para votar, leia o QR code mostrado por quem está conduzindo '
            'a eleição.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Ler QR do condutor'),
          ),
        ];
      case VoteViewKind.waitingRound:
        return const [
          Text('Aguardando a próxima votação. Esta tela atualiza sozinha.'),
        ];
      case VoteViewKind.ballot:
        final round = view.round!;
        return [
          ElectionBallot(
            key: ValueKey(round.id),
            round: round,
            busy: _busy,
            error: _error,
            onSubmit: (choice) => _submit(round, choice),
          ),
        ];
      case VoteViewKind.voted:
        final round = view.round!;
        final receipt = _receipts[round.id];
        return [
          Text(
            'Seu voto foi registrado para ${positionLabel(round.position)}. '
            'Aguarde a próxima votação.',
          ),
          if (receipt != null && receipt.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Código do seu comprovante:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SelectableText(
              receipt,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ];
    }
  }
}
