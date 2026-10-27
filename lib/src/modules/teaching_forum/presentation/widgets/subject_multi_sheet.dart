import 'package:flutter/material.dart';

import '../../models/forum_models.dart';
import 'subject_filter.dart';

/// Seletor de assuntos com seleção múltipla (até [max]). Devolve os ids
/// escolhidos ao tocar em Concluir, ou null se o usuário só fechou.
Future<List<String>?> showSubjectMultiSheet(
  BuildContext context, {
  required List<SubjectTag> tags,
  required Set<String> selected,
  required int max,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111828),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MultiSheet(tags: tags, initial: selected, max: max),
  );
}

class _MultiSheet extends StatefulWidget {
  const _MultiSheet({required this.tags, required this.initial, required this.max});

  final List<SubjectTag> tags;
  final Set<String> initial;
  final int max;

  @override
  State<_MultiSheet> createState() => _MultiSheetState();
}

class _MultiSheetState extends State<_MultiSheet> {
  String _query = '';
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = widget.tags.where((t) => t.name.toLowerCase().contains(q)).toList();
    final full = _selected.length >= widget.max;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text('Assuntos (${_selected.length}/${widget.max})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            if (full)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Limite atingido. Remova um para escolher outro.',
                    style: TextStyle(color: Colors.amber, fontSize: 12)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar assunto',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const Center(
                      child: Text('Nenhum assunto encontrado.',
                          style: TextStyle(color: Colors.white60)))
                  : ListView(
                      children: [
                        for (final tag in shown)
                          CheckboxListTile(
                            value: _selected.contains(tag.id),
                            activeColor: subjectTagColor,
                            enabled: _selected.contains(tag.id) || !full,
                            title: Text(tag.name,
                                style: TextStyle(
                                    color: _selected.contains(tag.id) || !full
                                        ? Colors.white
                                        : Colors.white38)),
                            onChanged: (on) => setState(() {
                              if (on == true) {
                                _selected.add(tag.id);
                              } else {
                                _selected.remove(tag.id);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(_selected.clear),
                        child: const Text('Limpar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, _selected.toList()),
                        child: const Text('Concluir'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
