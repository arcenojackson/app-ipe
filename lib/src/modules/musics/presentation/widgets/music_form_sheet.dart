import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/musics_repository.dart';
import '../../models/category.dart';
import '../../models/music.dart';
import '../../models/youtube_search_result.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../shared/utils/platform_utils.dart';
import 'tone_selector_sheet.dart';

class MusicFormSheet extends StatefulWidget {
  const MusicFormSheet({super.key, this.music});

  final MusicModel? music;

  @override
  State<MusicFormSheet> createState() => _MusicFormSheetState();
}

class _MusicFormSheetState extends State<MusicFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _obsController;
  late TextEditingController _youtubeController;
  late TextEditingController _cipherController;
  late TextEditingController _lyricsController;
  late TextEditingController _bpmController;
  late TextEditingController _tempoController;
  late TextEditingController _searchController;

  bool _isSubmitting = false;
  bool _minorTone = false;
  String _tone = '0';
  List<CategoryModel> _categories = const [];
  List<String> _selectedCategories = const [];
  List<YoutubeSearchResult> _youtubeResults = const [];
  bool _isSearchingYoutube = false;

  @override
  void initState() {
    super.initState();

    final music = widget.music;
    _titleController = TextEditingController(text: music?.title ?? '');
    _artistController = TextEditingController(text: music?.artist ?? '');
    _obsController = TextEditingController(text: music?.obs ?? '');
    _youtubeController = TextEditingController(text: music?.youtube ?? '');
    _cipherController = TextEditingController(text: music?.cipher ?? '');
    _lyricsController = TextEditingController(text: music?.lyrics ?? '');
    _bpmController = TextEditingController(text: music?.bpm ?? '0');
    _tempoController = TextEditingController(text: music?.tempo ?? '4/4');
    _searchController = TextEditingController(
      text: music == null ? '' : '${music.title} - ${music.artist}',
    );

    _minorTone = music?.minorTone ?? false;
    _tone = music?.tone ?? '0';
    _selectedCategories =
        music?.category
            .split(';')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList() ??
        const [];

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _obsController.dispose();
    _youtubeController.dispose();
    _cipherController.dispose();
    _lyricsController.dispose();
    _bpmController.dispose();
    _tempoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.music == null ? 'Nova música' : 'Editar música';
    final mediaQuery = MediaQuery.of(context);
    final safeAreaTop = mediaQuery.padding.top;
    // Altura aproximada do header (nome do usuário + padding)
    final headerHeight = 100.0;
    final topPadding = safeAreaTop + headerHeight;
    // Padding extra para Android
    final androidBottomPadding = PlatformUtils.getModalBottomPadding(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom + androidBottomPadding,
        left: 16,
        right: 16,
        top: topPadding,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Nome da música',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _artistController,
                decoration: const InputDecoration(
                  labelText: 'Artista',
                  hintText: 'Nome do artista ou banda',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o artista';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildCategoriesField(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _obsController,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  hintText: 'Notas adicionais sobre a música',
                ),
              ),
              const SizedBox(height: 16),
              _buildYoutubeSearchField(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _youtubeController,
                decoration: InputDecoration(
                  labelText: 'URL do vídeo (YouTube)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    tooltip: 'Colar do clipboard',
                    onPressed: () => _pasteFromClipboard(_youtubeController),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cipherController,
                decoration: InputDecoration(
                  labelText: 'Link da cifra',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    tooltip: 'Colar do clipboard',
                    onPressed: () => _pasteFromClipboard(_cipherController),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o link da cifra';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lyricsController,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Letra',
                  alignLabelWithHint: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    tooltip: 'Colar do clipboard',
                    onPressed: () => _pasteFromClipboard(_lyricsController),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bpmController,
                      decoration: const InputDecoration(labelText: 'BPM'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _tempoController,
                      decoration: const InputDecoration(labelText: 'Tempo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _minorTone,
                onChanged: (value) => setState(() => _minorTone = value),
                title: const Text('Tom menor?'),
              ),
              ToneSelectorSheet(
                selectedTone: _tone,
                onToneSelected: (value) => setState(() => _tone = value),
                isMinor: _minorTone,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar música'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesField() {
    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Categorias', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final selected = _selectedCategories.contains(category.name);
            return FilterChip(
              label: Text(category.name),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedCategories = [
                      ..._selectedCategories,
                      category.name,
                    ];
                  } else {
                    _selectedCategories = _selectedCategories
                        .where((name) => name != category.name)
                        .toList();
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildYoutubeSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Buscar no YouTube',
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
        ),
        if (_youtubeResults.isNotEmpty)
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
                  onTap: () {
                    setState(() {
                      _youtubeController.text =
                          'https://www.youtube.com/embed/${result.id}';
                      _searchController.text = result.title;
                      _youtubeResults = const [];
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _pasteFromClipboard(TextEditingController controller) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
      controller.text = clipboardData.text!;
      if (mounted) {
        showSuccessToast(context, 'Conteúdo colado com sucesso!');
      }
    } else {
      if (mounted) {
        showErrorToast(context, 'Nenhum conteúdo encontrado no clipboard');
      }
    }
  }

  Future<void> _loadCategories() async {
    final repository = context.read<MusicsRepository>();
    final categories = await repository.fetchCategories();
    if (mounted) {
      setState(() => _categories = categories);
    }
  }

  Future<void> _searchYoutube() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearchingYoutube = true;
      _youtubeResults = const [];
    });
    try {
      final results = await context.read<MusicsRepository>().searchYoutube(
        query,
      );
      if (mounted) {
        setState(() => _youtubeResults = results);
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingYoutube = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final repository = context.read<MusicsRepository>();
      final music = MusicModel(
        id: widget.music?.id ?? '',
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        obs: _obsController.text.trim().isEmpty
            ? null
            : _obsController.text.trim(),
        youtube: _youtubeController.text.trim().isEmpty
            ? null
            : _youtubeController.text.trim(),
        cipher: _cipherController.text.trim(),
        lyrics: _lyricsController.text.trim().isEmpty
            ? null
            : _lyricsController.text.trim(),
        bpm: _bpmController.text.trim(),
        tempo: _tempoController.text.trim(),
        tone: _tone,
        minorTone: _minorTone,
        category: _selectedCategories.join('; '),
      );
      if (widget.music == null) {
        await repository.create(music);
        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessToast(context, 'Música adicionada com sucesso!');
        }
      } else {
        await repository.update(music);
        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessToast(context, 'Música atualizada com sucesso!');
        }
      }
    } catch (error) {
      if (mounted) {
        showErrorToast(context, 'Erro ao salvar música.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
