import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/utils/app_toast.dart';
import '../../../shared/utils/sort_utils.dart';
import '../../../shared/state/app_state.dart';
import '../../people/data/people_repository.dart';
import '../data/societies_repository.dart';
import '../models/society.dart';
import '../../people/presentation/widgets/people_selector_sheet.dart';
import '../../auth/models/user.dart';

/// Tela para configurar Vocais e Ministros da sociedade ELO (Equipe de Louvor).
/// Acessível em Configurações > Equipe de Louvor.
class EloRolesConfigPage extends StatefulWidget {
  const EloRolesConfigPage({super.key});

  @override
  State<EloRolesConfigPage> createState() => _EloRolesConfigPageState();
}

class _EloRolesConfigPageState extends State<EloRolesConfigPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  SocietyModel? _eloSociety;
  List<UserModel> _people = const [];
  List<String> _selectedVocais = const [];
  List<String> _selectedMinistros = const [];
  String? _error;

  bool get _canEdit {
    final user = context.read<AppState>().currentUser;
    if (user == null || _eloSociety == null) return false;
    return user.isAdmin || user.id == _eloSociety!.userId;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final societiesRepository = context.read<SocietiesRepository>();
      final peopleRepository = context.read<PeopleRepository>();

      final eloSociety = await societiesRepository.fetchByName('ELO');
      final people = await peopleRepository.fetchAll();

      if (!mounted) return;

      setState(() {
        _eloSociety = eloSociety;
        _people = people;
        _selectedVocais = eloSociety?.vocaisIds ?? [];
        _selectedMinistros = eloSociety?.ministrosIds ?? [];
        _isLoading = false;
      });

      if (eloSociety == null) {
        setState(() => _error = 'Sociedade ELO não encontrada');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_canEdit || _eloSociety == null) return;

    setState(() => _isSaving = true);
    try {
      final repository = context.read<SocietiesRepository>();
      await repository.updateEloRoles(
        id: _eloSociety!.id,
        vocaisIds: _selectedVocais,
        ministrosIds: _selectedMinistros,
      );
      if (mounted) {
        showSuccessToast(context, 'Vocais e Ministros atualizados!');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao salvar: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _manageVocais() async {
    await _manageEloRole(
      currentIds: _selectedVocais,
      onResult: (result) => setState(() => _selectedVocais = result),
    );
  }

  Future<void> _manageMinistros() async {
    await _manageEloRole(
      currentIds: _selectedMinistros,
      onResult: (result) => setState(() => _selectedMinistros = result),
    );
  }

  Future<void> _manageEloRole({
    required List<String> currentIds,
    required void Function(List<String>) onResult,
  }) async {
    try {
      final peopleRepository = context.read<PeopleRepository>();
      final people = await peopleRepository.fetchAll();
      setState(() => _people = people);
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar usuários: ${e.toString()}');
      }
      return;
    }

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PeopleSelectorSheet(
        people: _people,
        selectedIds: currentIds,
        filterByELO: true,
      ),
    );

    if (result != null) {
      onResult(result);
    }
  }

  Widget _buildRoleSection(
    String label,
    List<String> userIds,
    VoidCallback onManage,
  ) {
    final users = _people.where((user) => userIds.contains(user.id)).toList()
      ..sort((a, b) => compareNamesIgnoreAccents(a.name, b.name));

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
              ),
              if (_canEdit)
                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Gerenciar'),
                  onPressed: onManage,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (users.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Nenhuma pessoa configurada',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white60,
                    ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: users
                  .map(
                    (user) => InputChip(
                      label: Text(user.name),
                      avatar: CircleAvatar(
                        child: Text(
                            user.name.isNotEmpty ? user.name[0] : '?'),
                      ),
                      onDeleted: _canEdit
                          ? () {
                              setState(() {
                                if (label == 'Vocais') {
                                  _selectedVocais =
                                      List.of(_selectedVocais)..remove(user.id);
                                } else {
                                  _selectedMinistros =
                                      List.of(_selectedMinistros)
                                        ..remove(user.id);
                                }
                              });
                            }
                          : null,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocais e Ministros'),
        actions: [
          if (_canEdit)
            TextButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Salvar'),
              onPressed: _isSaving ? null : _save,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1220), Color(0xFF05070D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar novamente'),
                            onPressed: _loadData,
                          ),
                        ],
                      ),
                    ),
                  )
                : !_canEdit
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Você não tem permissão para editar esta configuração.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Defina quem são os vocais e ministros da Equipe de Louvor. '
                              'Essas definições são usadas na modal de disponibilidade para exibir '
                              'quantos já se disponibilizaram em cada domingo.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildRoleSection(
                              'Vocais',
                              _selectedVocais,
                              _manageVocais,
                            ),
                            _buildRoleSection(
                              'Ministros',
                              _selectedMinistros,
                              _manageMinistros,
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }
}
