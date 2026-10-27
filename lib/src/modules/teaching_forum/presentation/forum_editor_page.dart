import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/state/app_state.dart';
import '../data/forum_repository.dart';
import '../models/forum_logic.dart';
import '../models/forum_models.dart';
import 'forum_editor_controller.dart';
import 'widgets/forum_scaffold.dart';

class ForumEditorPage extends StatefulWidget {
  const ForumEditorPage({super.key, required this.viewer, this.editing});
  final ForumViewer viewer;
  final ForumTopic? editing;

  @override
  State<ForumEditorPage> createState() => _ForumEditorPageState();
}

class _ForumEditorPageState extends State<ForumEditorPage> {
  late final ForumEditorController _controller;
  late final TextEditingController _title =
      TextEditingController(text: widget.editing?.title ?? '');
  late final TextEditingController _body =
      TextEditingController(text: widget.editing?.body ?? '');

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    _controller = ForumEditorController(
      repository: context.read<ForumRepository>(),
      author: ForumAuthor(uid: widget.viewer.uid, name: user?.name ?? ''),
      editing: widget.editing,
    )
      ..addListener(() => mounted ? setState(() {}) : null)
      ..loadTags();
  }

  @override
  void dispose() {
    _controller.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = await _controller.save(_title.text, _body.text);
    if (id != null && mounted) Navigator.of(context).pop(id);
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        counterStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return ForumScaffold(
      title: widget.editing == null ? 'Novo tópico' : 'Editar tópico',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            maxLength: forumTitleMax,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Título'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 6,
            maxLines: 14,
            maxLength: forumBodyMax,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Mensagem'),
          ),
          if (c.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Assuntos (até 3)', style: TextStyle(color: Colors.white70)),
            Wrap(
              spacing: 8,
              children: [
                for (final tag in c.tags)
                  FilterChip(
                    label: Text(tag.name),
                    selected: c.selectedTags.contains(tag.id),
                    onSelected: (_) {
                      if (!c.toggleTag(tag.id)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Escolha no máximo 3 assuntos.')));
                      }
                    },
                  ),
              ],
            ),
          ],
          if (widget.editing != null && widget.editing!.refs.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Citações (somente leitura no app)',
                style: TextStyle(color: Colors.white70)),
            for (final r in widget.editing!.refs)
              Text('• ${r.label}', style: const TextStyle(color: Colors.white54)),
          ],
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(c.error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: c.saving ? null : _save,
            child: Text(c.saving ? 'Salvando…' : 'Publicar'),
          ),
        ],
      ),
    );
  }
}
