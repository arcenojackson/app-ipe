import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/state/app_state.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../societies/data/societies_repository.dart';
import '../../../societies/models/society.dart';
import '../../data/elections_repository.dart';
import '../../models/election_logic.dart';

/// Cargos que toda eleição precisa ter.
const _requiredPositions = {BoardPosition.presidente, BoardPosition.vice};

class ElectionFormSheet extends StatefulWidget {
  const ElectionFormSheet({super.key});

  @override
  State<ElectionFormSheet> createState() => _ElectionFormSheetState();
}

class _ElectionFormSheetState extends State<ElectionFormSheet> {
  final _titleController = TextEditingController();
  List<SocietyModel> _societies = const [];
  SocietyModel? _society;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  final Set<BoardPosition> _positions = {...BoardPosition.values};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final userId = context.read<AppState>().currentUser?.id ?? '';
      final all = await context.read<SocietiesRepository>().fetchAll();
      if (!mounted) return;
      setState(() {
        _societies = directorSocieties(all, userId);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorToast(context, 'Não foi possível carregar as sociedades.');
    }
  }

  void _selectSociety(SocietyModel? society) {
    setState(() {
      _society = society;
      _titleController.text =
          defaultElectionTitle(society?.name ?? '', _scheduledAt.year);
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final society = _society;
    final title = _titleController.text.trim();
    if (society == null || title.isEmpty) {
      showErrorToast(context, 'Escolha a sociedade e o título.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ElectionsRepository>().createElection(
            societyId: society.id,
            title: title,
            scheduledAt: _scheduledAt,
            positions: [
              for (final p in BoardPosition.values)
                if (_positions.contains(p)) p.name,
            ],
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorToast(context, e.toString());
    }
  }

  String _formatted(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _loading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : _societies.isEmpty
              ? const SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      'Você não está na diretoria de nenhuma sociedade.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Nova eleição',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SocietyModel>(
                        initialValue: _society,
                        decoration: const InputDecoration(labelText: 'Sociedade'),
                        items: [
                          for (final s in _societies)
                            DropdownMenuItem(value: s, child: Text(s.name)),
                        ],
                        onChanged: _selectSociety,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Título'),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: Text(_formatted(_scheduledAt)),
                        subtitle: const Text('Data e hora da eleição'),
                        onTap: _pickDateTime,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cargos (Presidente e Vice são obrigatórios)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final p in BoardPosition.values)
                            FilterChip(
                              label: Text(p.label),
                              selected: _positions.contains(p),
                              onSelected: _requiredPositions.contains(p)
                                  ? null
                                  : (on) => setState(() {
                                        on
                                            ? _positions.add(p)
                                            : _positions.remove(p);
                                      }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Criando...' : 'Criar eleição'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
