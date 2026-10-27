import 'package:flutter/material.dart';

import '../../models/forum_models.dart';

/// Cor do tipo "Assunto", a mesma do portal (hsl(38 60% 50%)).
final Color subjectTagColor = const HSLColor.fromAHSL(1, 38, 0.6, 0.5).toColor();

/// Chip colorido de assunto; com [onRemove] mostra o ✕.
class SubjectChip extends StatelessWidget {
  const SubjectChip({super.key, required this.label, this.onRemove, this.small = false});

  final String label;
  final VoidCallback? onRemove;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 2 : 5),
      decoration: BoxDecoration(
        color: subjectTagColor.withValues(alpha: 0.18),
        border: Border.all(color: subjectTagColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: small ? 11 : 13),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.close, size: 14, color: Colors.white70),
          ],
        ],
      ),
    );
    if (onRemove == null) return chip;
    return Semantics(
      button: true,
      label: 'Remover filtro $label',
      child: GestureDetector(onTap: onRemove, child: chip),
    );
  }
}

/// Botão "Assunto ▾" com contador de filtros ativos.
class SubjectFilterButton extends StatelessWidget {
  const SubjectFilterButton({super.key, required this.activeCount, required this.onPressed});

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = activeCount > 0;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.sell_outlined, size: 18, color: active ? subjectTagColor : Colors.white70),
      label: Text(
        active ? 'Assunto ($activeCount) ▾' : 'Assunto ▾',
        style: TextStyle(color: active ? Colors.white : Colors.white70),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: active ? subjectTagColor : Colors.white24),
        shape: const StadiumBorder(),
      ),
    );
  }
}

/// Abre o seletor de assunto e devolve o id escolhido ('' = limpar), ou null se
/// o usuário só fechou. Seleção única, como no portal.
Future<String?> showSubjectFilterSheet(
  BuildContext context, {
  required List<SubjectTag> tags,
  required String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111828),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SubjectSheet(tags: tags, initial: selected),
  );
}

class _SubjectSheet extends StatefulWidget {
  const _SubjectSheet({required this.tags, required this.initial});

  final List<SubjectTag> tags;
  final String? initial;

  @override
  State<_SubjectSheet> createState() => _SubjectSheetState();
}

class _SubjectSheetState extends State<_SubjectSheet> {
  String _query = '';
  late String? _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = widget.tags.where((t) => t.name.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text('Filtrar por assunto',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
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
                          ListTile(
                            leading: Icon(
                              _selected == tag.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: _selected == tag.id ? subjectTagColor : Colors.white54,
                            ),
                            title: Text(tag.name, style: const TextStyle(color: Colors.white)),
                            onTap: () => setState(() => _selected = tag.id),
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
                        onPressed: () => Navigator.pop(context, ''),
                        child: const Text('Limpar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, _selected ?? ''),
                        child: const Text('Aplicar'),
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
