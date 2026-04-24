import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/utils/app_toast.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../musics/data/musics_repository.dart';
import '../../musics/models/music_status.dart';
import '../data/music_evaluations_repository.dart';
import '../models/evaluation_category.dart';
import '../models/music_with_evaluations.dart';

class MusicDecisionPage extends StatefulWidget {
  const MusicDecisionPage({super.key});

  @override
  State<MusicDecisionPage> createState() => _MusicDecisionPageState();
}

class _MusicDecisionPageState extends State<MusicDecisionPage> {
  bool _isLoading = true;
  List<MusicWithEvaluations> _pending = [];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final list = await context
          .read<MusicEvaluationsRepository>()
          .fetchPendingDecisions();
      if (mounted) setState(() => _pending = list);
    } catch (_) {
      if (mounted) showErrorToast(context, 'Erro ao carregar músicas pendentes.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _decide(MusicWithEvaluations item, MusicStatus status) async {
    final label = status == MusicStatus.aprovada ? 'aprovar' : 'reprovar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar decisão'),
        content: Text('Deseja $label "${item.music.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(label[0].toUpperCase() + label.substring(1)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await context
          .read<MusicsRepository>()
          .setFinalStatus(item.music.id, status);
      if (mounted) {
        final verb = status == MusicStatus.aprovada ? 'aprovada' : 'reprovada';
        showSuccessToast(context, '"${item.music.title}" $verb.');
        await _loadPending();
      }
    } catch (_) {
      if (mounted) showErrorToast(context, 'Erro ao registrar decisão.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aguardando decisão')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.white38),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma música\naguardando decisão.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _pending.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) =>
                  _MusicDecisionCard(item: _pending[index], onDecide: _decide),
            ),
    );
  }
}

class _MusicDecisionCard extends StatelessWidget {
  const _MusicDecisionCard({required this.item, required this.onDecide});

  final MusicWithEvaluations item;
  final Future<void> Function(MusicWithEvaluations, MusicStatus) onDecide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final enrichedResponses = <({
      String userName,
      EvaluationCategory category,
      int rating,
      String? comment
    })>[];
    for (final form in item.forms) {
      for (final r in item.responses.where((r) => r.formId == form.id)) {
        enrichedResponses.add((
          userName: r.userName,
          category: form.category,
          rating: r.rating,
          comment: r.comment,
        ));
      }
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.music.title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (item.music.artist.isNotEmpty)
            Text(
              item.music.artist,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
          const SizedBox(height: 16),
          if (enrichedResponses.isNotEmpty)
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: enrichedResponses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
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
                      border: Border.all(
                        color: categoryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r.category.label,
                            style: TextStyle(
                              color: categoryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r.userName,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            5,
                            (si) => Icon(
                              si < r.rating ? Icons.star : Icons.star_outline,
                              size: 14,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        if (r.comment != null && r.comment!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              r.comment!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onDecide(item, MusicStatus.reprovada),
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text(
                    'Reprovar',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onDecide(item, MusicStatus.aprovada),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Aprovar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
