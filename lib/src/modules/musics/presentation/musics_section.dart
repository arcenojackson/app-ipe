import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../events/presentation/widgets/music_view_dialog.dart';
import '../../music_evaluations/data/music_evaluations_repository.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/utils/app_toast.dart';
import '../data/musics_repository.dart';
import '../models/music.dart';
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

  @override
  void initState() {
    super.initState();
    _loadMusics();
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
                            isAdmin: widget.isAdmin,
                            onOpen: () => _openMusic(music),
                            onEdit: () => _onEditMusic(music),
                            onDelete: () => _onDeleteMusic(music),
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
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({
    required this.music,
    required this.isAdmin,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final MusicModel music;
  final bool isAdmin;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                ],
              ),
            ),
            if (isAdmin)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
