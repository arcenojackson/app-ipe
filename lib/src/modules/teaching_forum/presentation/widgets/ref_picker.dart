import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/forum_repository.dart';
import '../../models/forum_logic.dart';
import '../../models/forum_models.dart';
import '../../models/ref_options.dart';
import 'subject_filter.dart';

bool _same(ForumRef a, ForumRef b) => a.kind == b.kind && a.id == b.id;

/// "Citar documento ou aula": botão + cartões removíveis dos itens escolhidos.
class RefPickerField extends StatelessWidget {
  const RefPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = forumMaxRefs,
  });

  final List<ForumRef> value;
  final ValueChanged<List<ForumRef>> onChanged;
  final int max;

  @override
  Widget build(BuildContext context) {
    final full = value.length >= max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ref in value)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(ref.kind == 'plan' ? Icons.event_note : Icons.description_outlined,
                  size: 18, color: Colors.white54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ref.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white)),
              ),
              IconButton(
                tooltip: 'Remover citação ${ref.label}',
                icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                onPressed: () => onChanged(value.where((r) => !_same(r, ref)).toList()),
              ),
            ]),
          ),
        Row(children: [
          OutlinedButton.icon(
            onPressed: full
                ? null
                : () async {
                    final picked = await showRefPickerSheet(context, selected: value);
                    if (picked != null) onChanged([...value, picked]);
                  },
            icon: const Icon(Icons.attach_file, size: 18),
            label: const Text('Citar documento ou aula'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white38,
              side: BorderSide(color: full ? Colors.white12 : Colors.white38),
              shape: const StadiumBorder(),
            ),
          ),
          const SizedBox(width: 8),
          Text('${value.length} de $max',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ],
    );
  }
}

Future<ForumRef?> showRefPickerSheet(
  BuildContext context, {
  required List<ForumRef> selected,
}) {
  final repository = context.read<ForumRepository>();
  return showModalBottomSheet<ForumRef>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111828),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => RefPickerSheet(repository: repository, selected: selected),
  );
}

class RefPickerSheet extends StatefulWidget {
  const RefPickerSheet({super.key, required this.repository, required this.selected});

  final ForumRepository repository;
  final List<ForumRef> selected;

  @override
  State<RefPickerSheet> createState() => _RefPickerSheetState();
}

class _RefPickerSheetState extends State<RefPickerSheet> {
  bool _library = true;
  String _query = '';
  bool _loading = true;
  bool _error = false;
  List<RefOption> _docs = [];
  List<ForumRef> _lessons = [];
  Map<String, String> _tagNames = {};
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    widget.repository
        .loadAllTagNames()
        .then((m) => mounted ? setState(() => _tagNames = m) : null)
        .catchError((_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      if (_library) {
        final docs = await widget.repository.loadPublishedDocs(_query);
        if (!mounted) return;
        _docs = docs;
      } else if (_lessons.isEmpty) {
        final lessons = await widget.repository.loadPlanLessons();
        if (!mounted) return;
        _lessons = lessons;
      }
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _tab(bool library) {
    if (_library == library) return;
    setState(() => _library = library);
    _load();
  }

  bool _added(ForumRef r) => widget.selected.any((s) => _same(s, r));

  List<Widget> _rows() {
    if (_library) {
      return [
        for (final o in _docs)
          _row(
            ref: o.ref,
            icon: o.isLink ? Icons.link : Icons.description_outlined,
            chips: [
              for (final id in o.tagIds.take(3))
                if (_tagNames[id] != null) SubjectChip(label: _tagNames[id]!, small: true),
            ],
          ),
      ];
    }
    final words = searchWords(_query);
    return [
      for (final r in _lessons)
        if (refNameMatches(r.label, words)) _row(ref: r, icon: Icons.event_note),
    ];
  }

  Widget _row({required ForumRef ref, required IconData icon, List<Widget> chips = const []}) {
    final added = _added(ref);
    return ListTile(
      enabled: !added,
      leading: Icon(icon, color: Colors.white54),
      title: Text(ref.label, style: TextStyle(color: added ? Colors.white38 : Colors.white)),
      subtitle: chips.isEmpty
          ? (added ? const Text('já citado', style: TextStyle(color: Colors.white38)) : null)
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 6, runSpacing: 4, children: chips),
            ),
      onTap: added ? null : () => Navigator.pop(context, ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _loading || _error ? <Widget>[] : _rows();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text('Citar no tópico',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                ChoiceChip(
                    label: const Text('Biblioteca'),
                    selected: _library,
                    onSelected: (_) => _tab(true)),
                const SizedBox(width: 8),
                ChoiceChip(
                    label: const Text('Plano pedagógico'),
                    selected: !_library,
                    onSelected: (_) => _tab(false)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _library ? 'Buscar documento publicado' : 'Buscar aula',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) {
                  _query = v;
                  if (!_library) setState(() {});
                },
                onSubmitted: (_) {
                  if (_library) _load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('Não foi possível carregar as opções.',
                                style: TextStyle(color: Colors.white70)),
                            TextButton(onPressed: _load, child: const Text('Tentar de novo')),
                          ]),
                        )
                      : rows.isEmpty
                          ? const Center(
                              child: Text('Nenhum resultado.',
                                  style: TextStyle(color: Colors.white60)))
                          : ListView(children: rows),
            ),
          ],
        ),
      ),
    );
  }
}
