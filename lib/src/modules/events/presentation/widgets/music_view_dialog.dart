import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:provider/provider.dart';

import '../../../music_evaluations/data/music_evaluations_repository.dart';
import '../../../music_evaluations/models/evaluation_category.dart';
import '../../../music_evaluations/models/music_with_evaluations.dart';
import '../../../musics/models/music.dart';
import '../../../musics/models/music_status.dart';
import '../../../../shared/utils/app_toast.dart';

class MusicViewDialog extends StatefulWidget {
  const MusicViewDialog({super.key, required this.music, this.customTone});

  final MusicModel music;
  final String? customTone;

  @override
  State<MusicViewDialog> createState() => _MusicViewDialogState();
}

class _MusicViewDialogState extends State<MusicViewDialog> {
  WebViewController? _webViewController;
  String? _embedUrl;

  @override
  void initState() {
    super.initState();
    _initializeYoutubePlayer();
  }

  void _initializeYoutubePlayer() {
    final youtubeUrl = widget.music.youtube;
    
    if (youtubeUrl == null || youtubeUrl.isEmpty) {
      return;
    }

    // Extrai o ID do vídeo ou normaliza a URL de embed
    String embedUrl;
    if (youtubeUrl.contains('/embed/')) {
      // Extrai o ID da URL de embed e reconstrói com youtube-nocookie.com
      final videoId = _extractVideoId(youtubeUrl);
      if (videoId != null && videoId.isNotEmpty) {
        embedUrl = 'https://www.youtube-nocookie.com/embed/$videoId';
      } else {
        // Se não conseguir extrair, tenta normalizar a URL diretamente
        embedUrl = youtubeUrl.replaceAll(
          RegExp(r'https?://(www\.)?youtube\.com'),
          'https://www.youtube-nocookie.com',
        );
      }
    } else {
      // Extrai o ID e constrói a URL de embed com youtube-nocookie.com
      final videoId = _extractVideoId(youtubeUrl);
      
      if (videoId != null && videoId.isNotEmpty) {
        embedUrl = 'https://www.youtube-nocookie.com/embed/$videoId';
      } else {
        return;
      }
    }
    
    // Adiciona parâmetros necessários com origin correto
    final uri = Uri.parse(embedUrl);
    final finalEmbedUrl = uri.replace(queryParameters: {
      'rel': '0', // Não mostra vídeos relacionados
      'origin': 'https://www.youtube-nocookie.com',
    }).toString();

    // Cria uma página HTML com o iframe do YouTube
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="frame-src https://www.youtube-nocookie.com https://www.youtube.com https://youtube.com;">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      background-color: #000;
      overflow: hidden;
    }
    iframe {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      border: none;
    }
  </style>
</head>
<body>
  <iframe
    src="$finalEmbedUrl"
    frameborder="0"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    allowfullscreen
    loading="lazy"
  ></iframe>
</body>
</html>
''';

    // Inicializa o WebView com o HTML
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
          },
          onWebResourceError: (WebResourceError error) {
          },
        ),
      )
      ..loadHtmlString(htmlContent, baseUrl: 'https://www.youtube-nocookie.com');
    
    _embedUrl = finalEmbedUrl;
    
    // Atualiza o estado para renderizar o WebView
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final music = widget.music;

    return Dialog(
      child: SizedBox(
        width: 500,
        height: 520,
        child: Column(
          children: [
            ListTile(
              title: Text(music.title),
              subtitle: Text(music.artist),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: _buildViewTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTab() {
    final cipherUrl = _computeCipherUrl();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    widget.music.youtube == null || widget.music.youtube!.isEmpty
                        ? 'Nenhum vídeo disponível'
                        : 'Erro ao carregar vídeo',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  if (widget.music.youtube != null && widget.music.youtube!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        final videoId = _extractVideoId(widget.music.youtube);
                        if (videoId != null) {
                          _launchUrl('https://www.youtube.com/watch?v=$videoId');
                        } else {
                          _launchUrl(widget.music.youtube!);
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir no YouTube'),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: cipherUrl == null ? null : () => _launchUrl(cipherUrl),
            icon: const Icon(Icons.library_music),
            label: const Text('Abrir cifra'),
          ),
          if (widget.music.lyrics != null && widget.music.lyrics!.isNotEmpty) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _showLyricsModal(context),
              icon: const Icon(Icons.music_note),
              label: const Text('Exibir letra'),
            ),
          ],
          if (widget.music.obs?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text('Observações', style: Theme.of(context).textTheme.titleMedium),
            Text(widget.music.obs!),
          ],
          if (widget.music.status == MusicStatus.aprovada ||
              widget.music.status == MusicStatus.reprovada) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _showEvaluationsSheet(context),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Ver avaliações'),
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEvaluationsSheet(BuildContext context) async {
    MusicWithEvaluations? data;
    try {
      data = await context
          .read<MusicEvaluationsRepository>()
          .fetchEvaluationsForMusic(widget.music);
    } catch (_) {
      if (context.mounted) showErrorToast(context, 'Erro ao carregar avaliações.');
      return;
    }

    if (!context.mounted) return;

    if (data == null || data.responses.isEmpty) {
      showErrorToast(context, 'Nenhuma avaliação encontrada para esta música.');
      return;
    }

    final enrichedResponses = <({
      String userName,
      EvaluationCategory category,
      int rating,
      String? comment,
    })>[];
    for (final form in data.forms) {
      for (final r in data.responses.where((r) => r.formId == form.id)) {
        enrichedResponses.add((
          userName: r.userName,
          category: form.category,
          rating: r.rating,
          comment: r.comment,
        ));
      }
    }

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (ctx, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.rate_review_outlined, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text(
                      'Avaliações',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: enrichedResponses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final r = enrichedResponses[i];
                    final categoryColor = switch (r.category) {
                      EvaluationCategory.theological => Colors.purple,
                      EvaluationCategory.congregational => Colors.teal,
                      EvaluationCategory.musical => Colors.orange,
                    };
                    return Container(
                      width: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.category.label,
                              style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r.userName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(5, (si) => Icon(
                              si < r.rating ? Icons.star : Icons.star_outline,
                              size: 14,
                              color: Colors.amber,
                            )),
                          ),
                          if (r.comment != null && r.comment!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Expanded(
                              child: Text(
                                r.comment!,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showLyricsModal(BuildContext context) {
    final lyrics = widget.music.lyrics;
    if (lyrics == null || lyrics.isEmpty) {
      showErrorToast(context, 'Nenhuma letra cadastrada.');
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.music.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              widget.music.artist,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Fechar',
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

  String? _computeCipherUrl() {
    final cipher = widget.music.cipher;
    if (cipher.isEmpty) return null;
    final tone = widget.customTone ?? widget.music.tone;
    return '$cipher#key=$tone&tabs=false';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _extractVideoId(String? url) {
    if (url == null || url.isEmpty) return null;
    
    // Remove espaços e quebras de linha
    url = url.trim();
    
    // Primeiro, tenta extrair usando regex (mais robusto)
    // Caso 1: URL com /embed/ (ex: https://youtube.com/embed/VIDEO_ID ou https://www.youtube.com/embed/VIDEO_ID)
    final embedMatch = RegExp(r'(?:youtube\.com|youtu\.be)/embed/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (embedMatch != null) {
      final videoId = embedMatch.group(1);
      return videoId;
    }
    
    // Caso 2: URL curta do YouTube (ex: https://youtu.be/VIDEO_ID)
    final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (shortMatch != null) {
      final videoId = shortMatch.group(1);
      return videoId;
    }
    
    // Caso 3: URL padrão do YouTube (ex: https://youtube.com/watch?v=VIDEO_ID)
    final watchMatch = RegExp(r'(?:youtube\.com/watch\?v=|youtube\.com/v/)([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (watchMatch != null) {
      final videoId = watchMatch.group(1);
      return videoId;
    }
    
    // Caso 4: Tenta usar Uri.parse como fallback
    final uri = Uri.tryParse(url);
    if (uri != null) {
      // Verifica query parameters
      if (uri.queryParameters.containsKey('v')) {
        final videoId = uri.queryParameters['v']?.split('&').first;
        if (videoId != null && videoId.length == 11) {
          return videoId;
        }
      }
      
      // Verifica path segments para /embed/
      if (uri.pathSegments.contains('embed') && uri.pathSegments.length > 1) {
        final videoId = uri.pathSegments[uri.pathSegments.indexOf('embed') + 1];
        if (videoId.length == 11) {
          return videoId;
        }
      }
    }
    
    // Caso 5: Tenta encontrar qualquer padrão de 11 caracteres alfanuméricos após /embed/
    final fallbackMatch = RegExp(r'/embed/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (fallbackMatch != null) {
      final videoId = fallbackMatch.group(1);
      return videoId;
    }
    return null;
  }
}
