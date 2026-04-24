import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../events/presentation/widgets/music_view_dialog.dart';
import '../../music_evaluations/data/music_evaluations_repository.dart';
import '../../music_evaluations/presentation/music_decision_page.dart';
import '../../societies/data/societies_repository.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/utils/app_toast.dart';
import '../data/musics_repository.dart';
import '../models/music.dart';
import '../models/music_status.dart';
import 'widgets/music_form_sheet.dart';

class MusicsSection extends StatefulWidget {
  const MusicsSection({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<MusicsSection> createState() => _MusicsSectionState();
}

class _MusicsSectionState extends State<MusicsSection> {
  bool _isLoading = true;
  List<MusicModel> _musics = const [];
  String _search = '';
  String? _error;
  bool _isBoardMember = false;
  int _pendingDecisionsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMusics();
    _checkUserRoles();
  }

  Future<void> _checkUserRoles() async {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    try {
      final eloSociety = await context
          .read<SocietiesRepository>()
          .fetchByName('ELO');
      if (!mounted) return;
      final isBoard = eloSociety?.allBoardIds.contains(user.id) ?? false;
      if (!isBoard) return;
      final count = await context
          .read<MusicEvaluationsRepository>()
          .countPendingDecisions();
      if (!mounted) return;
      setState(() {
        _isBoardMember = true;
        _pendingDecisionsCount = count;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final filteredMusics = _musics.where((music) {
      if (_search.isEmpty) return true;
      final lower = _search.toLowerCase();
      return music.title.toLowerCase().contains(lower) ||
          music.artist.toLowerCase().contains(lower) ||
          music.category.toLowerCase().contains(lower);
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final theme = Theme.of(context);

    return Column(
      children: [
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          borderRadius: 22,
          child: TextField(
            decoration: const InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por título, artista ou categoria',
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        if (_isBoardMember && _pendingDecisionsCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MusicDecisionPage(),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pending_actions,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Aguardando decisão ($_pendingDecisionsCount)',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.amber,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _loadMusics,
                color: theme.colorScheme.primary,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? ListView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.only(
                          bottom: widget.isAdmin ? 160 : 120,
                        ),
                        children: [
                          const SizedBox(height: 120),
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      )
                    : filteredMusics.isEmpty
                    ? ListView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.only(
                          bottom: widget.isAdmin ? 160 : 120,
                        ),
                        children: const [
                          SizedBox(height: 120),
                          Icon(
                            Icons.music_off,
                            size: 68,
                            color: Colors.white38,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Nada por aqui.\nExperimente adicionar uma nova música ao repertório.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: widget.isAdmin ? 160 : 120,
                        ),
                        itemCount: filteredMusics.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final music = filteredMusics[index];
                          return _MusicCard(
                            music: music,
                            canManage: widget.isAdmin,
                            onOpen: () => _openMusic(music),
                            onEdit: () => _onEditMusic(music),
                            onDelete: () => _onDeleteMusic(music),
                            onSendToEvaluation: () =>
                                _onSendToEvaluation(music),
                          );
                        },
                      ),
              ),
              if (widget.isAdmin)
                Positioned(
                  bottom: 130,
                  right: 0,
                  child: FloatingActionButton(
                    heroTag: 'add',
                    onPressed: _onCreateMusic,
                    child: const Icon(Icons.add),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadMusics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final musics = await context.read<MusicsRepository>().fetchAll();
      musics.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      setState(() => _musics = musics);
    } catch (error) {
      setState(() => _error = 'Erro ao carregar as músicas.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openMusic(MusicModel music) async {
    final fullMusic = await context.read<MusicsRepository>().fetchById(
      music.id,
    );
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => MusicViewDialog(music: fullMusic),
    );
  }

  Future<void> _onCreateMusic() async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const MusicFormSheet(),
    );
    if (result is! MusicModel) return;

    try {
      await context
          .read<MusicEvaluationsRepository>()
          .createFormsForMusic(result);
    } catch (_) {
      if (mounted) {
        showErrorToast(
          context,
          'Música salva, mas houve um erro ao criar os formulários de avaliação.',
        );
      }
    }

    await _loadMusics();
  }

  Future<void> _onEditMusic(MusicModel music) async {
    final fullMusic = await context.read<MusicsRepository>().fetchById(
      music.id,
    );
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MusicFormSheet(music: fullMusic),
    );
    if (updated == true) await _loadMusics();
  }

  Future<void> _onDeleteMusic(MusicModel music) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir música'),
        content: Text(
          'Tem certeza que deseja excluir "${music.title}"? Esta ação não poderá ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await context.read<MusicsRepository>().delete(music.id);
    if (mounted) {
      showSuccessToast(context, '"${music.title}" foi excluída.');
      await _loadMusics();
    }
  }

  Future<void> _onSendToEvaluation(MusicModel music) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar para avaliação'),
        content: Text(
          'Deseja enviar "${music.title}" para o Fórum de Avaliação?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await context.read<MusicsRepository>().sendToEvaluation(music.id);
      await context
          .read<MusicEvaluationsRepository>()
          .createFormsForMusic(music.copyWith(status: MusicStatus.emAvaliacao));
      if (mounted) {
        showSuccessToast(context, '"${music.title}" enviada para avaliação.');
        await _loadMusics();
      }
    } catch (_) {
      if (mounted) {
        showErrorToast(context, 'Erro ao enviar para avaliação.');
      }
    }
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({
    required this.music,
    required this.canManage,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onSendToEvaluation,
  });

  final MusicModel music;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSendToEvaluation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onOpen,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.music_note, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    music.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    music.artist,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                  if (music.category.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: music.category
                          .split(';')
                          .map(
                            (category) => Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                category.trim(),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _StatusBadge(status: music.status),
                ],
              ),
            ),
            if (canManage)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canManage && music.status == MusicStatus.avaliar)
                    IconButton(
                      tooltip: 'Enviar para avaliação',
                      icon: const Icon(Icons.send_outlined, size: 20),
                      onPressed: onSendToEvaluation,
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final MusicStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      MusicStatus.avaliar => (Colors.amber, Icons.star_outline),
      MusicStatus.emAvaliacao => (Colors.blue, Icons.hourglass_top),
      MusicStatus.aprovada => (Colors.green, Icons.check_circle_outline),
      MusicStatus.reprovada => (Colors.red, Icons.cancel_outlined),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          status.label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
