import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../musics/data/musics_repository.dart';
import '../../../musics/models/youtube_search_result.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../models/evaluation_music.dart';

class MusicItemFormSheet extends StatefulWidget {
  const MusicItemFormSheet({
    super.key,
    this.music,
    this.order = 0,
  });

  final EvaluationMusicModel? music;
  final int order;

  @override
  State<MusicItemFormSheet> createState() => _MusicItemFormSheetState();
}

class _MusicItemFormSheetState extends State<MusicItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isSearchingYoutube = false;
  List<YoutubeSearchResult> _youtubeResults = [];

  @override
  void initState() {
    super.initState();
    if (widget.music != null) {
      _titleController.text = widget.music!.title;
      _artistController.text = widget.music!.artist ?? '';
      _youtubeController.text = widget.music!.youtubeUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _youtubeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? _validateYoutubeUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'URL do YouTube é obrigatória';
    }

    // Validar formatos de URL do YouTube
    final youtubePatterns = [
      RegExp(r'^https?://(www\.)?youtube\.com/watch\?v=[\w-]+'),
      RegExp(r'^https?://(www\.)?youtube\.com/embed/[\w-]+'),
      RegExp(r'^https?://youtu\.be/[\w-]+'),
    ];

    final isValid = youtubePatterns.any((pattern) => pattern.hasMatch(value));
    if (!isValid) {
      return 'URL do YouTube inválida';
    }

    return null;
  }

  Future<void> _searchYoutube() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearchingYoutube = true;
    });

    try {
      final musicsRepository = context.read<MusicsRepository>();
      final results = await musicsRepository.searchYoutube(query);
      setState(() {
        _youtubeResults = results;
      });
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao buscar no YouTube: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingYoutube = false;
        });
      }
    }
  }

  void _selectYoutubeResult(YoutubeSearchResult result) {
    setState(() {
      _youtubeController.text = 'https://www.youtube.com/watch?v=${result.id}';
      _titleController.text = result.title;
      _youtubeResults = [];
      _searchController.clear();
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final music = EvaluationMusicModel(
      id: widget.music?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      artist: _artistController.text.trim().isEmpty
          ? null
          : _artistController.text.trim(),
      youtubeUrl: _youtubeController.text.trim(),
      order: widget.order,
    );

    Navigator.of(context).pop(music);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111828), // surface color do tema
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.music == null ? 'Adicionar música' : 'Editar música',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título da música *',
                hintText: 'Digite o título da música',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Título é obrigatório';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _artistController,
              decoration: const InputDecoration(
                labelText: 'Artista/Banda',
                hintText: 'Digite o nome do artista ou banda',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _youtubeController,
              decoration: const InputDecoration(
                labelText: 'Link do YouTube *',
                hintText: 'https://www.youtube.com/watch?v=...',
              ),
              validator: _validateYoutubeUrl,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar no YouTube',
                hintText: 'Digite o nome da música para buscar',
                suffixIcon: IconButton(
                  icon: _isSearchingYoutube
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  onPressed: _isSearchingYoutube ? null : _searchYoutube,
                ),
              ),
              onSubmitted: (_) => _searchYoutube(),
            ),
            if (_youtubeResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  itemCount: _youtubeResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _youtubeResults[index];
                    return ListTile(
                      leading: const Icon(Icons.play_circle),
                      title: Text(result.title),
                      subtitle: Text(result.id),
                      onTap: () => _selectYoutubeResult(result),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Salvar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
        ),
      ),
    );
  }
}
