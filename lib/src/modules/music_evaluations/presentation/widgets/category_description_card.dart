import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/evaluation_category.dart';

class CategoryDescriptionCard extends StatefulWidget {
  const CategoryDescriptionCard({super.key, required this.category});

  final EvaluationCategory category;

  @override
  State<CategoryDescriptionCard> createState() =>
      _CategoryDescriptionCardState();
}

class _CategoryDescriptionCardState extends State<CategoryDescriptionCard> {
  bool _isExpanded = false;
  String? _markdownContent;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    String assetPath;
    switch (widget.category) {
      case EvaluationCategory.theological:
        assetPath = 'assets/docs/coerencia_teologica.md';
        break;
      case EvaluationCategory.congregational:
        assetPath = 'assets/docs/coerencia_congregacional.md';
        break;
      case EvaluationCategory.musical:
        assetPath = 'assets/docs/coerencia_musical.md';
        break;
    }

    try {
      final content = await rootBundle.loadString(assetPath);
      if (mounted) {
        setState(() {
          _markdownContent = content;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _markdownContent = 'Erro ao carregar conteúdo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ver critérios de avaliação',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _markdownContent == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : MarkdownBody(
                      data: _markdownContent!,
                      styleSheet: MarkdownStyleSheet(
                        p: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        h1: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
