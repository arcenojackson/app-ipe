import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/utils/app_toast.dart';
import '../data/elections_repository.dart';
import '../models/election.dart';
import '../models/election_logic.dart';
import 'widgets/election_minutes_tab.dart';

/// Resumo da eleição no app. A condução (abrir escrutínios, liberar presentes,
/// ver quem falta votar) é feita na tela web, aberta por aqui.
class ElectionDetailPage extends StatefulWidget {
  const ElectionDetailPage({super.key, required this.electionId});

  final String electionId;

  @override
  State<ElectionDetailPage> createState() => _ElectionDetailPageState();
}

class _ElectionDetailPageState extends State<ElectionDetailPage> {
  late final Stream<Election?> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<ElectionsRepository>().watchElection(widget.electionId);
  }

  Future<void> _openConduct() async {
    final ok = await launchUrl(
      Uri.parse(buildConductLink(widget.electionId)),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      showErrorToast(context, 'Não foi possível abrir o navegador.');
    }
  }

  Future<void> _copyVoteLink() async {
    await Clipboard.setData(
      ClipboardData(text: buildVoteLink(widget.electionId)),
    );
    if (mounted) showSuccessToast(context, 'Link da votação copiado.');
  }

  String _statusLabel(ElectionStatus s) => switch (s) {
        ElectionStatus.draft => 'Rascunho',
        ElectionStatus.open => 'Em andamento',
        ElectionStatus.closed => 'Encerrada',
      };

  String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
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
        return Scaffold(
          appBar: AppBar(title: Text(election.title)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${election.societyName} · ${_date(election.scheduledAt)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(label: Text(_statusLabel(election.status))),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Abrir condução na web'),
                onPressed: _openConduct,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('Copiar link da votação'),
                onPressed: _copyVoteLink,
              ),
              const SizedBox(height: 24),
              Text('Ata', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ElectionMinutesTab(election: election),
            ],
          ),
        );
      },
    );
  }
}
