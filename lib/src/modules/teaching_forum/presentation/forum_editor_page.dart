import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/state/app_state.dart';
import '../data/forum_repository.dart';
import '../models/forum_logic.dart';
import '../models/forum_models.dart';
import 'forum_editor_controller.dart';
import 'widgets/forum_scaffold.dart';
import 'widgets/ref_picker.dart';
import 'widgets/subject_filter.dart';
import 'widgets/subject_multi_sheet.dart';

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
            const Text('Assuntos (opcional, até 3)',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final id in c.selectedTags)
                  SubjectChip(
                    label: c.tags.where((t) => t.id == id).map((t) => t.name).firstOrNull ?? id,
                    onRemove: () => c.toggleTag(id),
                  ),
                SubjectFilterButton(
                  activeCount: c.selectedTags.length,
                  label: 'Escolher assuntos',
                  onPressed: () async {
                    final picked = await showSubjectMultiSheet(
                      context,
                      tags: c.tags,
                      selected: c.selectedTags,
                      max: forumMaxTags,
                    );
                    if (picked != null) c.setTags(picked);
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          RefPickerField(value: c.refs, onChanged: c.setRefs),
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
