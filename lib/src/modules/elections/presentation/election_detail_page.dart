import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_exception.dart';
import '../../../shared/state/app_state.dart';
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
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _stream = context.read<ElectionsRepository>().watchElection(
      widget.electionId,
    );
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

  /// Abre a eleição para os membros entrarem. Pede confirmação: depois de
  /// aberta não volta a rascunho.
  Future<void> _startVoting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar a votação?'),
        content: const Text(
          'Os membros da sociedade poderão entrar na votação lendo o QR '
          'code. Os escrutínios são conduzidos pela tela web.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _starting = true);
    try {
      await context.read<ElectionsRepository>().openElection(widget.electionId);
      if (mounted) showSuccessToast(context, 'Votação iniciada.');
    } on AppException catch (e) {
      if (mounted) showErrorToast(context, e.message);
    } catch (_) {
      if (mounted) showErrorToast(context, 'Algo deu errado.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Para o condutor mandar a si mesmo (ex.: WhatsApp) e abrir no computador,
  /// onde fica mais fácil projetar o QR code.
  Future<void> _copyConductLink() async {
    await Clipboard.setData(
      ClipboardData(text: buildConductLink(widget.electionId)),
    );
    if (mounted) showSuccessToast(context, 'Link da condução copiado.');
  }

  Future<void> _copyVoteLink() async {
    await Clipboard.setData(
      ClipboardData(text: buildVoteLink(widget.electionId)),
    );
    if (mounted) showSuccessToast(context, 'Link da votação copiado.');
  }

  /// Só o diretor da eleição, e só enquanto ela é rascunho.
  bool _canStart(Election election) {
    final uid = context.read<AppState>().currentUser?.id;
    return election.status == ElectionStatus.draft &&
        uid != null &&
        election.directorIds.contains(uid);
  }

  String _statusLabel(ElectionStatus s) => switch (s) {
    ElectionStatus.draft => 'Rascunho',
    ElectionStatus.open => 'Em andamento',
    ElectionStatus.closed => 'Encerrada',
  };

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
        final canStart = _canStart(election);
        return Scaffold(
          appBar: AppBar(title: Text(election.title)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _StatusBadge(
                  status: election.status,
                  label: _statusLabel(election.status),
                ),
              ),
              const SizedBox(height: 12),
              // Dois quadrados lado a lado. À direita: iniciar (só o diretor,
              // em rascunho) ou, nos demais casos, os links de copiar.
              Row(
                children: [
                  Expanded(
                    child: _SquareAction(
                      icon: Icons.open_in_browser,
                      label: 'Abrir na web',
                      onPressed: _openConduct,
                      filled: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: canStart
                        ? _SquareAction(
                            icon: Icons.play_arrow,
                            label: _starting
                                ? 'Iniciando...'
                                : 'Iniciar votação',
                            onPressed: _starting ? null : _startVoting,
                          )
                        : AspectRatio(
                            aspectRatio: 1,
                            child: _CompactLinks(
                              onCopyConduct: _copyConductLink,
                              onCopyVote: _copyVoteLink,
                            ),
                          ),
                  ),
                ],
              ),
              if (canStart) ...[
                const SizedBox(height: 16),
                Card(
                  key: const ValueKey('links-card'),
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _LinkTile(
                        title: 'Link da condução',
                        subtitle:
                            'Para abrir no computador e projetar o QR code',
                        onCopy: _copyConductLink,
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      _LinkTile(
                        title: 'Link da votação',
                        subtitle: 'Para os membros entrarem na votação',
                        onCopy: _copyVoteLink,
                      ),
                    ],
                  ),
                ),
              ],
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

/// Linha de link com ação de copiar: o toque na linha toda copia.
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.title,
    required this.subtitle,
    required this.onCopy,
  });

  final String title;
  final String subtitle;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.link),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: IconButton(
        tooltip: 'Copiar ${title.toLowerCase()}',
        icon: const Icon(Icons.copy),
        onPressed: onCopy,
      ),
      onTap: onCopy,
    );
  }
}

/// Botão quadrado com ícone em cima e texto embaixo.
class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 36),
        const SizedBox(height: 12),
        Text(label, textAlign: TextAlign.center),
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    const padding = EdgeInsets.all(12);
    return AspectRatio(
      aspectRatio: 1,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(shape: shape, padding: padding),
              onPressed: onPressed,
              child: child,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: shape,
                padding: padding,
                // O verde padrão do tema some sobre o fundo escuro.
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              onPressed: onPressed,
              child: child,
            ),
    );
  }
}

/// Situação da eleição: selo pequeno, com uma cor por status.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final ElectionStatus status;
  final String label;

  Color get _color => switch (status) {
    ElectionStatus.draft => const Color(0xFFFFB74D),
    ElectionStatus.open => const Color(0xFF81C784),
    ElectionStatus.closed => const Color(0xFF90A4AE),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Os dois links de copiar, no mesmo estilo do cartão de links, mas compactos
/// para ocupar um quadrado ao lado do botão "Abrir na web".
class _CompactLinks extends StatelessWidget {
  const _CompactLinks({required this.onCopyConduct, required this.onCopyVote});

  final VoidCallback onCopyConduct;
  final VoidCallback onCopyVote;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('links-card'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: _CompactLinkTile(
              title: 'Link da condução',
              onCopy: onCopyConduct,
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: _CompactLinkTile(
              title: 'Link da votação',
              onCopy: onCopyVote,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactLinkTile extends StatelessWidget {
  const _CompactLinkTile({required this.title, required this.onCopy});

  final String title;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCopy,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.link, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
            ),
            IconButton(
              tooltip: 'Copiar ${title.toLowerCase()}',
              icon: const Icon(Icons.copy, size: 20),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: onCopy,
            ),
          ],
        ),
      ),
    );
  }
}
