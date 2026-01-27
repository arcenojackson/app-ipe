import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';
import '../../auth/models/user.dart';
import '../data/music_evaluations_repository.dart';
import '../models/evaluation_category.dart';
import '../models/evaluation_form.dart';
import '../models/evaluation_music.dart';
import 'widgets/music_item_form_sheet.dart';
import '../../societies/data/societies_repository.dart';
import '../../musics/data/musics_repository.dart';
import '../../musics/models/youtube_search_result.dart';

class EvaluationFormEditorPage extends StatefulWidget {
  const EvaluationFormEditorPage({super.key, this.category, this.form});

  final EvaluationCategory? category; // Opcional para novo formulário
  final EvaluationFormModel? form;

  @override
  State<EvaluationFormEditorPage> createState() =>
      _EvaluationFormEditorPageState();
}

class _EvaluationFormEditorPageState extends State<EvaluationFormEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  // Campos da música (para novo formulário)
  final _musicTitleController = TextEditingController();
  final _musicArtistController = TextEditingController();
  final _musicYoutubeController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isSearchingYoutube = false;
  bool _isSaving = false;
  List<EvaluationMusicModel> _musics = [];
  List<String> _allowedUserIds = [];
  EvaluationFormStatus _status =
      EvaluationFormStatus.active; // Sempre inicia como ativo
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    if (widget.form != null) {
      _titleController.text = widget.form!.title;
      _descriptionController.text = widget.form!.description ?? '';
      _musics = List.of(widget.form!.musics);
      _allowedUserIds = List.of(widget.form!.allowedUserIds);
      // Manter o status do formulário existente (pode ser active ou closed)
      _status = widget.form!.status;
      // Se for edição e não tiver category definido, usar o category do form
      if (widget.category == null) {
        // O category será inferido do form
      }
    } else {
      // Novo formulário sempre começa como ativo
      _status = EvaluationFormStatus.active;
      _loadCurrentUser();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _musicTitleController.dispose();
    _musicArtistController.dispose();
    _musicYoutubeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user != null) {
      setState(() {
        _currentUser = user;
      });
      // Carregar automaticamente todos os usuários da categoria
      await _loadCategoryUsers();
    }
  }

  Future<void> _loadCategoryUsers() async {
    try {
      final societiesRepository = context.read<SocietiesRepository>();

      // Buscar sociedade ELO
      final eloSociety = await societiesRepository.fetchByName('ELO');
      if (eloSociety == null) return;

      final boardIds = eloSociety.allBoardIds;

      if (widget.form == null) {
        // Novo formulário: carregar usuários de TODAS as categorias
        final allCategoryUsers = <String>{};
        for (final category in EvaluationCategory.values) {
          final categoryUsers =
              eloSociety.forumUsersByCategory?[category.name] ?? [];
          allCategoryUsers.addAll(categoryUsers);
        }

        // Combinar usuários de todas as categorias com diretoria
        final allowedUserIds = <String>{...allCategoryUsers, ...boardIds};

        setState(() {
          _allowedUserIds = allowedUserIds.toList();
        });
      } else {
        // Edição: carregar usuários apenas da categoria do formulário
        if (widget.category != null) {
          final categoryUsers =
              eloSociety.forumUsersByCategory?[widget.category!.name] ?? [];

          // Combinar usuários da categoria com diretoria
          final allowedUserIds = <String>{...categoryUsers, ...boardIds};

          setState(() {
            _allowedUserIds = allowedUserIds.toList();
          });
        }
      }
    } catch (e) {
      // Se houver erro, pelo menos adicionar o usuário atual
      if (_currentUser != null && !_allowedUserIds.contains(_currentUser!.id)) {
        setState(() {
          _allowedUserIds.add(_currentUser!.id);
        });
      }
    }
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
    if (query.isEmpty) {
      showErrorToast(context, 'Digite algo para buscar');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSearchingYoutube = true;
    });

    try {
      final musicsRepository = context.read<MusicsRepository>();
      final results = await musicsRepository.searchYoutube(query);
      if (mounted) {
        setState(() {
          _isSearchingYoutube = false;
        });
        _showYoutubeResultsModal(results);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearchingYoutube = false;
        });
        // Exibir erro no console
        print('❌ Erro ao buscar no YouTube:');
        print(e.toString());
        print('');

        // Mostrar mensagem de erro mais amigável
        final errorMessage =
            e.toString().contains('Failed host lookup') ||
                e.toString().contains('Connection refused') ||
                e.toString().contains('localhost')
            ? 'Erro de conexão. Verifique se o servidor está rodando.'
            : 'Erro ao buscar no YouTube: ${e.toString()}';

        showErrorToast(context, errorMessage);
      }
    }
  }

  void _showYoutubeResultsModal(List<YoutubeSearchResult> results) {
    if (results.isEmpty) {
      showErrorToast(context, 'Nenhum vídeo encontrado');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111828),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Resultados da busca',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            // Lista de resultados
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final result = results[index];
                  return _buildYoutubeResultItem(result);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYoutubeResultItem(YoutubeSearchResult result) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _selectYoutubeResult(result);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: result.thumbnail.isNotEmpty
                  ? Image.network(
                      result.thumbnail,
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 120,
                        height: 90,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.video_library,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 120,
                          height: 90,
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 120,
                      height: 90,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.video_library,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
            ),
            // Informações do vídeo
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${result.id}',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  void _selectYoutubeResult(YoutubeSearchResult result) {
    setState(() {
      _musicYoutubeController.text =
          'https://www.youtube.com/watch?v=${result.id}';
      _searchController.clear();
    });
  }

  Future<void> _addMusic() async {
    final order = _musics.length;
    final result = await showModalBottomSheet<EvaluationMusicModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicItemFormSheet(order: order),
    );

    if (result != null) {
      setState(() {
        _musics.add(result);
      });
    }
  }

  Future<void> _editMusic(int index) async {
    final music = _musics[index];
    final result = await showModalBottomSheet<EvaluationMusicModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicItemFormSheet(music: music, order: music.order),
    );

    if (result != null) {
      setState(() {
        _musics[index] = result;
      });
    }
  }

  Future<void> _removeMusic(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover música'),
        content: Text(
          'Tem certeza que deseja remover "${_musics[index].title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _musics.removeAt(index);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repository = context.read<MusicEvaluationsRepository>();
      final user = _currentUser ?? context.read<AppState>().currentUser;
      if (user == null) {
        showErrorToast(context, 'Usuário não autenticado.');
        return;
      }

      // Atualizar allowedUserIds com todos os usuários antes de salvar
      await _loadCategoryUsers();

      if (widget.form == null) {
        // NOVO FORMULÁRIO: Criar 3 formulários (um para cada categoria) com a mesma música
        final musicTitle = _musicTitleController.text.trim();
        final musicArtist = _musicArtistController.text.trim().isEmpty
            ? null
            : _musicArtistController.text.trim();
        final musicYoutube = _musicYoutubeController.text.trim();

        if (musicTitle.isEmpty || musicYoutube.isEmpty) {
          showErrorToast(
            context,
            'Título da música e Link do YouTube são obrigatórios.',
          );
          setState(() => _isSaving = false);
          return;
        }

        // Criar a música única
        final music = EvaluationMusicModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: musicTitle,
          artist: musicArtist,
          youtubeUrl: musicYoutube,
          order: 0,
        );

        // Criar formulário para cada categoria
        final createdForms = <EvaluationFormModel>[];
        for (final category in EvaluationCategory.values) {
          // Carregar usuários específicos desta categoria
          final societiesRepository = context.read<SocietiesRepository>();
          final eloSociety = await societiesRepository.fetchByName('ELO');
          if (eloSociety == null) continue;

          final categoryUsers =
              eloSociety.forumUsersByCategory?[category.name] ?? [];
          final boardIds = eloSociety.allBoardIds;
          final categoryAllowedUserIds = <String>{
            ...categoryUsers,
            ...boardIds,
          }.toList();

          final form = EvaluationFormModel(
            id: '',
            title: musicTitle, // Título do formulário = título da música
            description: musicArtist, // Descrição = artista/banda
            category: category,
            createdBy: user.id,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            allowedUserIds: categoryAllowedUserIds,
            status: EvaluationFormStatus.active,
            musics: [music],
          );

          final createdForm = await repository.createForm(form);
          createdForms.add(createdForm);
        }

        if (mounted) {
          showSuccessToast(
            context,
            'Formulários criados para todas as categorias!',
          );
          Navigator.of(context).pop(createdForms.first);
        }
      } else {
        // EDIÇÃO: Atualizar formulário existente
        if (_musics.isEmpty) {
          showErrorToast(
            context,
            'É necessário adicionar pelo menos uma música.',
          );
          setState(() => _isSaving = false);
          return;
        }

        // Determinar status automaticamente: verificar se todos responderam
        EvaluationFormStatus statusToSave = _status;
        final allResponded = await repository.checkIfAllUsersResponded(
          widget.form!.id,
          _allowedUserIds,
        );
        statusToSave = allResponded
            ? EvaluationFormStatus.closed
            : EvaluationFormStatus.active;

        final form = EvaluationFormModel(
          id: widget.form!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          category:
              widget.category ??
              widget.form!.category, // Usar category do form se não fornecido
          createdBy: widget.form!.createdBy,
          createdAt: widget.form!.createdAt,
          updatedAt: DateTime.now(),
          allowedUserIds: _allowedUserIds,
          status: statusToSave,
          musics: _musics,
        );

        await repository.updateForm(form);

        if (mounted) {
          showSuccessToast(context, 'Formulário atualizado!');
          Navigator.of(context).pop(form);
        }
      }
    } catch (e) {
      // Exibir erro completo no console para facilitar cópia do link do índice
      print('❌ Erro ao salvar formulário:');
      print(e.toString());
      print('');

      if (mounted) {
        showErrorToast(context, 'Erro ao salvar: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.form == null ? 'Novo formulário' : 'Editar formulário',
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(onPressed: _save, child: const Text('Salvar')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: widget.form == null
              ? _buildNewFormFields()
              : _buildEditFormFields(),
        ),
      ),
    );
  }

  List<Widget> _buildNewFormFields() {
    return [
      // Título da música
      TextFormField(
        controller: _musicTitleController,
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

      // Artista/Banda
      TextFormField(
        controller: _musicArtistController,
        decoration: const InputDecoration(
          labelText: 'Artista/Banda',
          hintText: 'Digite o nome do artista ou banda',
        ),
      ),
      const SizedBox(height: 32),

      // Buscar no YouTube
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
      const SizedBox(height: 16),

      // Link do YouTube
      TextFormField(
        controller: _musicYoutubeController,
        decoration: const InputDecoration(
          labelText: 'Link do YouTube *',
          hintText: 'https://www.youtube.com/watch?v=...',
        ),
        validator: _validateYoutubeUrl,
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildEditFormFields() {
    return [
      // Categoria (apenas na edição)
      Card(
        color: Colors.white.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.category, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categoria',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                    ),
                    Text(
                      (widget.category ?? widget.form?.category)?.label ?? '',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Título
      TextFormField(
        controller: _titleController,
        decoration: const InputDecoration(
          labelText: 'Título *',
          hintText: 'Digite o título do formulário',
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Título é obrigatório';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),

      // Descrição
      TextFormField(
        controller: _descriptionController,
        decoration: const InputDecoration(
          labelText: 'Descrição',
          hintText: 'Digite a descrição do formulário (opcional)',
        ),
        maxLines: 2,
      ),
      const SizedBox(height: 16),

      // Músicas
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Músicas (${_musics.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Adicionar'),
            onPressed: _addMusic,
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_musics.isEmpty)
        Card(
          color: Colors.white.withOpacity(0.05),
          child: const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Nenhuma música adicionada',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ),
        )
      else
        ...List.generate(_musics.length, (index) {
          final music = _musics[index];
          return Card(
            color: Colors.white.withOpacity(0.05),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(music.title),
              subtitle: music.artist != null ? Text(music.artist!) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editMusic(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeMusic(index),
                  ),
                ],
              ),
            ),
          );
        }),
      const SizedBox(height: 24),
    ];
  }
}
