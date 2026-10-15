import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../shared/utils/app_toast.dart';
import '../data/elections_repository.dart';
import '../models/election.dart';
import '../models/election_logic.dart';
import 'widgets/election_minutes_tab.dart';
import 'widgets/election_rounds_tab.dart';
import 'widgets/election_voters_tab.dart';

class ElectionDetailPage extends StatefulWidget {
  const ElectionDetailPage({super.key, required this.electionId});

  final String electionId;

  @override
  State<ElectionDetailPage> createState() => _ElectionDetailPageState();
}

class _ElectionDetailPageState extends State<ElectionDetailPage> {
  late final Stream<Election?> _stream;

  ElectionsRepository get _repo => context.read<ElectionsRepository>();

  @override
  void initState() {
    super.initState();
    _stream = _repo.watchElection(widget.electionId);
  }

  Future<void> _confirm(
    String title,
    String message,
    Future<void> Function() action, {
    String? success,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await action();
      if (mounted && success != null) showSuccessToast(context, success);
    } catch (e) {
      if (mounted) showErrorToast(context, e.toString());
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(
      ClipboardData(text: buildVoteLink(widget.electionId)),
    );
    if (mounted) {
      showSuccessToast(
        context,
        'Link copiado. Cole no computador para abrir o QR.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Election?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Erro: ${snapshot.error}')),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final election = snapshot.data;
        if (election == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Eleição não encontrada.')),
          );
        }
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(election.title),
              actions: [
                IconButton(
                  tooltip: 'Copiar link do QR',
                  icon: const Icon(Icons.link),
                  onPressed: _copyLink,
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Presentes'),
                  Tab(text: 'Cargos'),
                  Tab(text: 'Ata'),
                ],
              ),
            ),
            body: Column(
              children: [
                _ActionBar(
                  election: election,
                  onOpen: () => _confirm(
                    'Abrir eleição?',
                    'As pessoas poderão entrar pelo link e aguardar a votação.',
                    () => _repo.setStatus(election.id, ElectionStatus.open),
                  ),
                  onClose: () => _confirm(
                    'Encerrar eleição?',
                    'Ninguém mais poderá entrar ou votar.',
                    () => _repo.setStatus(election.id, ElectionStatus.closed),
                  ),
                  onApply: () => _confirm(
                    'Aplicar diretoria?',
                    'Os eleitos substituem os cargos correspondentes na '
                        'diretoria da sociedade.',
                    () => _repo.applyBoard(election.id),
                    success: 'Diretoria atualizada.',
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ElectionVotersTab(election: election),
                      ElectionRoundsTab(election: election),
                      ElectionMinutesTab(election: election),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.election,
    required this.onOpen,
    required this.onClose,
    required this.onApply,
  });

  final Election election;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final status = switch (election.status) {
      ElectionStatus.draft => 'Rascunho',
      ElectionStatus.open => 'Em andamento',
      ElectionStatus.closed => 'Encerrada',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text(status)),
          if (election.status == ElectionStatus.draft)
            FilledButton(onPressed: onOpen, child: const Text('Abrir eleição')),
          if (election.status == ElectionStatus.open)
            OutlinedButton(
              onPressed: onClose,
              child: const Text('Encerrar eleição'),
            ),
          if (election.status != ElectionStatus.draft)
            OutlinedButton(
              onPressed: onApply,
              child: Text(
                election.boardAppliedAt == null
                    ? 'Aplicar diretoria'
                    : 'Reaplicar diretoria',
              ),
            ),
        ],
      ),
    );
  }
}
