import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';
import '../../auth/models/user.dart';
import '../../musics/data/musics_repository.dart';
import '../../musics/models/music.dart';
import '../data/music_evaluations_repository.dart';
import '../models/evaluation_form.dart';
import '../models/evaluation_response.dart';
import 'widgets/category_description_card.dart';
import 'widgets/rating_selector.dart';

class EvaluationFormViewerPage extends StatefulWidget {
  const EvaluationFormViewerPage({super.key, required this.formId});

  final String formId;

  @override
  State<EvaluationFormViewerPage> createState() =>
      _EvaluationFormViewerPageState();
}

class _EvaluationFormViewerPageState extends State<EvaluationFormViewerPage> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  EvaluationFormModel? _form;
  EvaluationResponseModel? _existingResponse;
  UserModel? _currentUser;
  int _selectedRating = 0;
  WebViewController? _webViewController;
  String? _embedUrl;
  String? _musicLyrics;
  MusicModel? _libraryMusic;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final user = appState.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final repository = context.read<MusicEvaluationsRepository>();

      // Carregar formulário
      final form = await repository.fetchFormById(widget.formId);

      // Verificar se pode acessar a categoria do formulário
      final canAccess = await repository.canAccessCategory(user, form.category);
      if (!canAccess) {
        if (mounted) {
          showErrorToast(
            context,
            'Você não tem permissão para acessar este formulário.',
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Carregar resposta do usuário para a música (só há uma música por formulário)
      final userResponses = await repository.fetchUserResponsesForForm(
        widget.formId,
        user.id,
      );

      final existingResponse = userResponses.isNotEmpty ? userResponses.first : null;

      MusicModel? libraryMusic;
      if (form.musicLibraryId != null) {
        try {
          libraryMusic = await context
              .read<MusicsRepository>()
              .fetchById(form.musicLibraryId!);
          if (libraryMusic.youtube?.isNotEmpty == true) {
            _initializeYoutubePlayer(libraryMusic.youtube!);
          }
        } catch (_) {}
      }

      setState(() {
        _form = form;
        _currentUser = user;
        _existingResponse = existingResponse;
        _libraryMusic = libraryMusic;
        _musicLyrics = libraryMusic?.lyrics?.isNotEmpty == true ? libraryMusic!.lyrics : null;
        _isLoading = false;
      });

      if (existingResponse != null) {
        _selectedRating = existingResponse.rating;
        _commentController.text = existingResponse.comment ?? '';
      }
    } catch (e) {
      // Exibir erro completo no console para facilitar cópia do link do índice
      print('❌ Erro ao carregar formulário:');
      print(e.toString());
      print('');

      if (mounted) {
        showErrorToast(context, 'Erro ao carregar formulário: ${e.toString()}');
      }
      setState(() => _isLoading = false);
    }
  }

  void _initializeYoutubePlayer(String youtubeUrl) {
    if (youtubeUrl.isEmpty) return;

    // Extrair ID do vídeo
    String? videoId;
    if (youtubeUrl.contains('/watch?v=')) {
      videoId = youtubeUrl.split('v=')[1].split('&')[0];
    } else if (youtubeUrl.contains('/embed/')) {
      videoId = youtubeUrl.split('/embed/')[1].split('?')[0];
    } else if (youtubeUrl.contains('youtu.be/')) {
      videoId = youtubeUrl.split('youtu.be/')[1].split('?')[0];
    }

    if (videoId == null || videoId.isEmpty) return;

    final embedUrl = 'https://www.youtube-nocookie.com/embed/$videoId?rel=0';

    final htmlContent =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background-color: #000; overflow: hidden; }
    iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe src="$embedUrl" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</body>
</html>
''';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..loadHtmlString(
        htmlContent,
        baseUrl: 'https://www.youtube-nocookie.com',
      );

    _embedUrl = embedUrl;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRating == 0 && _existingResponse == null) {
      showErrorToast(context, 'Por favor, selecione uma nota');
      return;
    }

    if (_form == null || _form!.musicLibraryId == null || _currentUser == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = context.read<MusicEvaluationsRepository>();

      final response = EvaluationResponseModel(
        id: _existingResponse?.id ?? '',
        formId: _form!.id,
        userId: _currentUser!.id,
        userName: _currentUser!.name,
        musicId: _form!.musicLibraryId!,
        rating: _selectedRating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        createdAt: _existingResponse?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.submitResponse(response);

      if (mounted) {
        showSuccessToast(context, 'Resposta salva com sucesso!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao salvar resposta: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showLyricsModal(BuildContext context, String title, String lyrics) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      lyrics,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _form == null || _form!.musicLibraryId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Formulário')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_form!.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Texto descritivo da categoria (movido para o início)
              CategoryDescriptionCard(category: _form!.category),
              const SizedBox(height: 24),

              // Informações da música
              Card(
                color: Colors.white.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _libraryMusic?.title ?? _form!.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_libraryMusic?.artist.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          _libraryMusic!.artist,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Player do YouTube
              if (_webViewController != null && _embedUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: WebViewWidget(controller: _webViewController!),
                  ),
                )
              else
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Vídeo não disponível',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              if (_musicLyrics != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _showLyricsModal(context, _libraryMusic?.title ?? _form!.title, _musicLyrics!),
                  icon: const Icon(Icons.music_note),
                  label: const Text('Exibir letra'),
                ),
              ],
              const SizedBox(height: 24),

              // Seleção de nota
              RatingSelector(
                initialRating: _selectedRating,
                onRatingChanged: (rating) {
                  setState(() {
                    _selectedRating = rating;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Comentário
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Comentário/Observação (opcional)',
                  hintText:
                      'Adicione comentários ou observações sobre a música ou sua nota...',
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                minLines: 4,
                maxLength: 1000,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => Text(
                      '$currentLength / $maxLength',
                      style: const TextStyle(color: Colors.white60),
                    ),
              ),
              const SizedBox(height: 24),

              // Botão de salvar
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
              // Espaço extra no final para melhor scroll, especialmente em Android
              SizedBox(
                height: MediaQuery.of(context).viewInsets.bottom > 0 ? 32 : 64,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
