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
  const ElectionVotePage({
    super.key,
    required this.electionId,
    @visibleForTesting this.scanPageBuilder,
  });

  final String electionId;

  /// Troca o leitor de QR (que precisa de câmera) nos testes.
  final Widget Function()? scanPageBuilder;

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
  StreamSubscription<ElectionVoter?>? _voterSub;

  /// Check-in feito, mas o registro do eleitor ainda não chegou pelo
  /// Firestore: evita voltar a oferecer a leitura do QR nesse intervalo.
  bool _enteringPending = false;
  Timer? _enteringTimer;
  StreamSubscription<ElectionRound?>? _roundSub;
  StreamSubscription<bool>? _votedSub;
  String? _votedRoundId;

  /// Código do comprovante por rodada, só enquanto a tela está aberta.
  final Map<String, String> _receipts = {};
  bool _busy = false;

  /// Erro do último envio de voto; vale só para a rodada em que aconteceu.
  String? _error;

  /// Falha ao ouvir o Firestore; some assim que chegam dados de novo.
  bool _streamFailed = false;

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
            (e) => setState(() {
              _election = Loadable(e);
              _streamFailed = false;
            }),
            onError: _onStreamError,
          ),
    );
    _listenVoter(uid);
  }

  /// (Re)ouve o registro do eleitor. Refazer a escuta depois do check-in
  /// garante uma leitura nova do servidor, mesmo que a anterior tenha ficado
  /// parada (listener que falhou não volta sozinho).
  void _listenVoter(String uid) {
    _voterSub?.cancel();
    _voterSub = _repo.watchMyVoter(widget.electionId, uid).listen((v) {
      setState(() {
        _voter = Loadable(v);
        _streamFailed = false;
        if (v != null) _stopEntering();
      });
      _syncRound(v);
    }, onError: _onStreamError);
  }

  void _stopEntering() {
    _enteringTimer?.cancel();
    _enteringPending = false;
  }

  bool _isApprovedMember(ElectionVoter? v) =>
      v != null &&
      v.status == VoterStatus.approved &&
      v.kind == VoterKind.member;

  /// A rodada só é observada depois que o membro entrou na votação.
  void _syncRound(ElectionVoter? voter) {
    if (!_isApprovedMember(voter) || _roundSub != null) return;
    _roundSub = _repo.watchOpenRound(widget.electionId).listen((round) {
      setState(() {
        _openRound = Loadable(round);
        _streamFailed = false;
        // Erro de voto de uma rodada não deve aparecer na cédula da próxima.
        if (round?.id != _votedRoundId) _error = null;
      });
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
          (voted) => setState(() {
            _hasVoted = Loadable(voted);
            _streamFailed = false;
          }),
          onError: _onStreamError,
        );
  }

  void _onStreamError(Object error) {
    if (!mounted) return;
    setState(() => _streamFailed = true);
  }

  /// Abre o leitor de QR. Se a pessoa entrou em outra eleição (leu o QR de
  /// outra), segue para a votação dessa.
  Future<void> _scan() async {
    final enteredId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            widget.scanPageBuilder?.call() ?? const ElectionScanPage(),
      ),
    );
    if (!mounted || enteredId == null) return;
    if (enteredId == widget.electionId) {
      final uid = _uid;
      if (uid == null) return;
      setState(() => _enteringPending = true);
      _enteringTimer?.cancel();
      _enteringTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) setState(() => _enteringPending = false);
      });
      _listenVoter(uid);
      return;
    }
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
    _voterSub?.cancel();
    _enteringTimer?.cancel();
    _roundSub?.cancel();
    _votedSub?.cancel();
    super.dispose();
  }

  String? get _visibleError =>
      _error ??
      (_streamFailed ? 'Não foi possível atualizar a votação.' : null);

  @override
  Widget build(BuildContext context) {
    final election = _election.isLoaded ? _election.value : null;
    final view = deriveVoteView(
      election: _election,
      voter: _voter,
      openRound: _openRound,
      hasVoted: _hasVoted,
    );

    final societyName = election != null
        ? Text(
            election.societyName,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(election?.title ?? 'Votação')),
      // Cédula: a lista rola e o botão de confirmar fica fixo no rodapé.
      body: _uid != null && view.kind == VoteViewKind.ballot
          ? ElectionBallot(
              key: ValueKey(view.round!.id),
              round: view.round!,
              busy: _busy,
              error: _visibleError,
              header: societyName,
              onSubmit: (choice) => _submit(view.round!, choice),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (societyName != null) ...[
                  societyName,
                  const SizedBox(height: 16),
                ],
                if (_uid == null)
                  const Text('Entre na sua conta para votar.')
                else
                  ..._body(view),
                if (_visibleError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _visibleError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
        if (_enteringPending) {
          return const [
            Center(child: CircularProgressIndicator()),
            SizedBox(height: 16),
            Text('Entrando na votação…', textAlign: TextAlign.center),
          ];
        }
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
        // Montada em `build`, fora da lista, para o botão ficar no rodapé.
        return const [];
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
