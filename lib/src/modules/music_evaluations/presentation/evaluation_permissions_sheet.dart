import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../people/data/people_repository.dart';
import '../../people/presentation/widgets/people_selector_sheet.dart';
import '../../../shared/utils/app_toast.dart';
import '../../auth/models/user.dart';
import '../../societies/data/societies_repository.dart';
import '../../societies/models/society.dart';
import '../models/evaluation_category.dart';

class EvaluationPermissionsSheet extends StatefulWidget {
  const EvaluationPermissionsSheet({
    super.key,
    required this.category,
    required this.currentAllowedUserIds,
    required this.onSave,
  });

  final EvaluationCategory category;
  final List<String> currentAllowedUserIds;
  final Future<void> Function(List<String>) onSave;

  @override
  State<EvaluationPermissionsSheet> createState() =>
      _EvaluationPermissionsSheetState();
}

class _EvaluationPermissionsSheetState
    extends State<EvaluationPermissionsSheet> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<UserModel> _availableUsers = [];
  List<String> _selectedUserIds = [];
  SocietyModel? _eloSociety;

  @override
  void initState() {
    super.initState();
    _selectedUserIds = List.of(widget.currentAllowedUserIds);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final societiesRepository = context.read<SocietiesRepository>();
      final peopleRepository = context.read<PeopleRepository>();

      // Buscar sociedade ELO
      final eloSociety = await societiesRepository.fetchByName('ELO');
      if (eloSociety == null) {
        if (mounted) {
          showErrorToast(context, 'Sociedade ELO não encontrada.');
          Navigator.of(context).pop();
        }
        return;
      }

      // Buscar usuários da categoria
      final categoryUsers = eloSociety.forumUsersByCategory?[widget.category.name] ?? [];
      final boardIds = eloSociety.allBoardIds;

      // Combinar usuários da categoria com diretoria
      final allowedUserIds = <String>{...categoryUsers, ...boardIds};

      // Buscar todos os usuários
      final allUsers = await peopleRepository.fetchAll();

      // Filtrar apenas usuários permitidos
      final availableUsers = allUsers
          .where((user) => allowedUserIds.contains(user.id))
          .toList();

      setState(() {
        _eloSociety = eloSociety;
        _availableUsers = availableUsers;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar dados: ${e.toString()}');
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_selectedUserIds);
      if (mounted) {
        Navigator.of(context).pop();
        showSuccessToast(context, 'Permissões atualizadas com sucesso!');
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao salvar permissões: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectUsers() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PeopleSelectorSheet(
        people: _availableUsers,
        selectedIds: _selectedUserIds,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedUserIds = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111828), // surface color do tema
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Gerenciar permissões',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Categoria: ${widget.category.label}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            Text(
              'Usuários selecionados: ${_selectedUserIds.length}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _selectedUserIds.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline,
                              size: 48, color: Colors.white38),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum usuário selecionado',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white60),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _selectedUserIds.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final userId = _selectedUserIds[index];
                        final user = _availableUsers
                            .firstWhere((u) => u.id == userId,
                                orElse: () => UserModel(
                                      id: userId,
                                      name: 'Usuário desconhecido',
                                      email: '',
                                      isAdmin: false,
                                      isPending: false,
                                    ));
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(user.name),
                          subtitle: Text(user.email),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedUserIds.remove(userId);
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _selectUsers,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar/Remover usuários'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
        ),
      ),
    );
  }
}
