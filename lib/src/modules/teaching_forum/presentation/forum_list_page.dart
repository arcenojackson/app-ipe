import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/state/app_state.dart';
import '../data/forum_repository.dart';
import '../models/forum_logic.dart';
import '../models/teaching_access.dart';
import 'forum_editor_page.dart';
import 'forum_list_controller.dart';
import 'forum_topic_page.dart';
import 'widgets/forum_scaffold.dart';
import 'widgets/subject_filter.dart';
import 'widgets/topic_card.dart';

class ForumListPage extends StatefulWidget {
  const ForumListPage({super.key});

  @override
  State<ForumListPage> createState() => _ForumListPageState();
}

class _ForumListPageState extends State<ForumListPage> {
  late final ForumListController _controller;
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = ForumListController(repository: context.read<ForumRepository>())
      ..addListener(() => mounted ? setState(() {}) : null)
      ..loadTags()
      ..load();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) _controller.loadMore();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ForumViewer? _viewer() => forumViewerFor(context.read<AppState>().currentUser);

  Future<void> _open(String topicId) async {
    final viewer = _viewer();
    if (viewer == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ForumTopicPage(topicId: topicId, viewer: viewer),
    ));
    if (mounted) _controller.load();
  }

  Future<void> _pickSubject() async {
    final picked = await showSubjectFilterSheet(
      context,
      tags: _controller.tags,
      selected: _controller.tagId,
    );
    if (picked == null || !mounted) return;
    final next = picked.isEmpty ? null : picked;
    if (next == _controller.tagId) return;
    _searchController.clear();
    _controller.setTagId(next);
  }

  Future<void> _create() async {
    final viewer = _viewer();
    if (viewer == null) return;
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => ForumEditorPage(viewer: viewer),
    ));
    if (id != null && mounted) {
      _controller.load();
      _open(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final names = {for (final t in c.tags) t.id: t.name};
    final all = [...c.pinned, ...c.topics];
    return ForumScaffold(
      title: 'Fórum',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Novo tópico'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por título',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (text) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  if (text.trim() != c.search.trim()) c.setSearch(text);
                });
              },
            ),
          ),
          if (c.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SubjectFilterButton(
                    activeCount: c.tagId == null ? 0 : 1,
                    onPressed: _pickSubject,
                  ),
                  if (c.tagId != null)
                    SubjectChip(
                      label: names[c.tagId] ?? c.tagId!,
                      onRemove: () => c.setTagId(null),
                    ),
                ],
              ),
            ),
          Expanded(child: _body(c, all, names)),
        ],
      ),
    );
  }

  Widget _body(ForumListController c, List all, Map<String, String> names) {
    if (c.loading && all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error && all.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível carregar o Fórum.',
                style: TextStyle(color: Colors.white70)),
            TextButton(onPressed: c.load, child: const Text('Tentar de novo')),
          ],
        ),
      );
    }
    if (all.isEmpty) {
      return const Center(
        child: Text('Nenhum tópico ainda.', style: TextStyle(color: Colors.white70)),
      );
    }
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: all.length + (c.loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= all.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final topic = all[i];
          return TopicCard(
            topic: topic,
            tagNames: names,
            onTap: () => _open(topic.id),
          );
        },
      ),
    );
  }
}
