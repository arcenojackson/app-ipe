import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../shared/utils/app_toast.dart';
import '../../models/evaluation_category.dart';
import '../../models/evaluation_music.dart';
import '../../models/evaluation_response.dart';
import 'category_description_card.dart';
import 'rating_selector.dart';

class EvaluationResponseForm extends StatefulWidget {
  const EvaluationResponseForm({
    super.key,
    required this.music,
    required this.category,
    this.existingResponse,
    required this.onSave,
  });

  final EvaluationMusicModel music;
  final EvaluationCategory category;
  final EvaluationResponseModel? existingResponse;
  final Future<void> Function(EvaluationResponseModel) onSave;

  @override
  State<EvaluationResponseForm> createState() => _EvaluationResponseFormState();
}

class _EvaluationResponseFormState extends State<EvaluationResponseForm> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  int _selectedRating = 0;
  bool _isSaving = false;
  WebViewController? _webViewController;
  String? _embedUrl;

  @override
  void initState() {
    super.initState();
    if (widget.existingResponse != null) {
      _selectedRating = widget.existingResponse!.rating;
      _commentController.text = widget.existingResponse!.comment ?? '';
    }
    _initializeYoutubePlayer();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _initializeYoutubePlayer() {
    final youtubeUrl = widget.music.youtubeUrl;

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

    final htmlContent = '''
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
      ..loadHtmlString(htmlContent, baseUrl: 'https://www.youtube-nocookie.com');

    _embedUrl = embedUrl;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRating == 0 && widget.existingResponse == null) {
      showErrorToast(context, 'Por favor, selecione uma nota');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response = EvaluationResponseModel(
        id: widget.existingResponse?.id ?? '',
        formId: '', // Será preenchido pela tela pai
        userId: '', // Será preenchido pela tela pai
        userName: '', // Será preenchido pela tela pai
        musicId: widget.music.id,
        rating: _selectedRating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        createdAt: widget.existingResponse?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await widget.onSave(response);
      if (mounted) {
        Navigator.of(context).pop();
        showSuccessToast(context, 'Resposta salva com sucesso!');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliar música'),
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
            TextButton(
              onPressed: _save,
              child: const Text('Salvar'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Informações da música
              Card(
                color: Colors.white.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.music.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (widget.music.artist != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.music.artist!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
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
              const SizedBox(height: 24),

              // Texto descritivo da categoria
              CategoryDescriptionCard(category: widget.category),
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
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    Text(
                  '$currentLength / $maxLength',
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 24),

              // Botões
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
