import 'package:flutter/material.dart';

import '../../../shared/widgets/glass_container.dart';
import 'forum_list_page.dart';
import 'widgets/forum_scaffold.dart';

/// Área da Plataforma pedagógica no app. Hoje só tem o Fórum; a Biblioteca
/// entra aqui no futuro.
class TeachingHomePage extends StatelessWidget {
  const TeachingHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ForumScaffold(
      title: 'Plataforma pedagógica',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassContainer(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.forum_outlined, color: Colors.white70),
              title: const Text(
                'Fórum',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Converse com outros professores',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ForumListPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
