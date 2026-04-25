import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../auth/models/user.dart';
import '../data/music_evaluations_repository.dart';
import '../models/evaluation_form.dart';
import '../models/evaluation_response.dart';
import 'music_decision_page.dart';

class EvaluationResponsesViewerPage extends StatefulWidget {
  const EvaluationResponsesViewerPage({super.key, required this.formId});

  final String formId;

  @override
  State<EvaluationResponsesViewerPage> createState() =>
      _EvaluationResponsesViewerPageState();
}

class _EvaluationResponsesViewerPageState
    extends State<EvaluationResponsesViewerPage> {
  bool _isLoading = true;
  EvaluationFormModel? _form;
  List<EvaluationResponseModel> _allResponses = [];
  UserModel? _currentUser;
  bool _isBoardMember = false;

  @override
  void initState() {
    super.initState();
    _loadData();
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

      // Verificar se pode visualizar respostas
      final canView = await repository.canViewResponses(user);
      if (!canView) {
        if (mounted) {
          showErrorToast(
            context,
            'Você não tem permissão para visualizar respostas.',
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Carregar formulário
      final form = await repository.fetchFormById(widget.formId);

      // Carregar todas as respostas
      final allResponses = await repository.fetchAllResponsesForForm(
        widget.formId,
      );

      final isBoardMember = await repository.isELOBoardMember(user);

      setState(() {
        _form = form;
        _allResponses = allResponses;
        _currentUser = user;
        _isBoardMember = isBoardMember;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar respostas: ${e.toString()}');
      }
      setState(() => _isLoading = false);
    }
  }

  Map<String, List<EvaluationResponseModel>> get _responsesByMusic {
    final map = <String, List<EvaluationResponseModel>>{};
    for (final response in _allResponses) {
      map.putIfAbsent(response.musicId, () => []).add(response);
    }
    return map;
  }

  double _getAverageRating(String musicId) {
    final responses = _responsesByMusic[musicId] ?? [];
    if (responses.isEmpty) return 0.0;
    final sum = responses.fold<int>(
      0,
      (acc, response) => acc + response.rating,
    );
    return sum / responses.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _form == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Respostas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Respostas - ${_form!.title}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Chip "Ver decisão final" para diretoria quando form fechado e vinculado à biblioteca
          if (_isBoardMember &&
              _form!.status == EvaluationFormStatus.closed &&
              _form!.musicLibraryId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MusicDecisionPage(),
                  ),
                ),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pending_actions,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ver decisão final desta música',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.amber,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Total de respostas
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.rate_review, size: 24, color: Colors.white70),
                const SizedBox(width: 12),
                Text(
                  'Total de respostas: ${_allResponses.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Respostas por música
          ..._form!.musics.map((music) {
            final responses = _responsesByMusic[music.id] ?? [];
            final averageRating = _getAverageRating(music.id);

            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              music.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (music.artist != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                music.artist!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (responses.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue, width: 1),
                          ),
                          child: Column(
                            children: [
                              Text(
                                averageRating.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'Média',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (responses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Nenhuma resposta ainda',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white60,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...responses.map((response) {
                      return Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  child: Text(
                                    response.userName.isNotEmpty
                                        ? response.userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        response.userName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        'Nota: ${response.rating}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (response.comment != null &&
                                response.comment!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Comentário:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white60,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      response.comment!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
