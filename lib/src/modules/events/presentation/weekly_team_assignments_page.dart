import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/glass_container.dart';
import '../../../shared/utils/app_toast.dart';
import '../../societies/data/societies_repository.dart';
import '../../societies/models/society.dart';
import '../data/weekly_team_assignments_repository.dart';
import '../models/weekly_team_assignment.dart';

class WeeklyTeamAssignmentsPage extends StatefulWidget {
  const WeeklyTeamAssignmentsPage({super.key});

  @override
  State<WeeklyTeamAssignmentsPage> createState() =>
      _WeeklyTeamAssignmentsPageState();
}

class _WeeklyTeamAssignmentsPageState extends State<WeeklyTeamAssignmentsPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<SocietyModel> _societies = const [];
  List<WeeklyTeamAssignment> _assignments = List.generate(
    4,
    (index) => WeeklyTeamAssignment(weekNumber: index + 1),
  );
  final Map<int, bool> _expandedWeeks = {1: true, 2: false, 3: false, 4: false};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final societiesRepository = context.read<SocietiesRepository>();
      final assignmentsRepository = context
          .read<WeeklyTeamAssignmentsRepository>();

      final results = await Future.wait([
        societiesRepository.fetchAll(),
        assignmentsRepository.fetchAll(),
      ]);

      final societies = results[0] as List<SocietyModel>;
      final assignments = results[1] as List<WeeklyTeamAssignment>;

      setState(() {
        _societies = societies;
        // Se já existem configurações salvas, usar elas; senão, usar as padrão
        if (assignments.isNotEmpty) {
          _assignments = assignments;
          // Garantir que temos 4 semanas
          while (_assignments.length < 4) {
            _assignments.add(
              WeeklyTeamAssignment(weekNumber: _assignments.length + 1),
            );
          }
        }
      });
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar dados: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAssignments() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final repository = context.read<WeeklyTeamAssignmentsRepository>();
      await repository.saveAll(_assignments);

      if (mounted) {
        showSuccessToast(context, 'Configurações salvas com sucesso!');
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao salvar: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _selectSocietyForWeek({
    required int weekNumber,
    required String responsibility,
  }) async {
    final assignment = _assignments.firstWhere(
      (a) => a.weekNumber == weekNumber,
    );

    String? currentSocietyId;
    switch (responsibility) {
      case 'liturgia':
        currentSocietyId = assignment.liturgia;
        break;
      case 'lanche':
        currentSocietyId = assignment.lanche;
        break;
      case 'aberturaEbd':
        currentSocietyId = assignment.aberturaEbd;
        break;
      case 'reuniaoOracao':
        currentSocietyId = assignment.reuniaoOracao;
        break;
    }

    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SocietySelectorSheet(
        societies: _societies,
        currentSocietyId: currentSocietyId,
      ),
    );

    // Se result for null, o usuário cancelou
    // Se result for string vazia, quer remover a sociedade
    // Se result for uma string não vazia, quer selecionar essa sociedade
    if (result == null) return;

    setState(() {
      final index = _assignments.indexWhere((a) => a.weekNumber == weekNumber);
      if (index != -1) {
        // Se result for string vazia, definir como null para remover
        final value = result.isEmpty ? '' : result;

        final updated = _assignments[index].copyWith(
          liturgia: responsibility == 'liturgia'
              ? value
              : _assignments[index].liturgia,
          lanche: responsibility == 'lanche'
              ? value
              : _assignments[index].lanche,
          aberturaEbd: responsibility == 'aberturaEbd'
              ? value
              : _assignments[index].aberturaEbd,
          reuniaoOracao: responsibility == 'reuniaoOracao'
              ? value
              : _assignments[index].reuniaoOracao,
        );
        _assignments[index] = updated;
      }
    });
  }

  String? _getSocietyName(String? societyId) {
    if (societyId == null || societyId.isEmpty) return null;
    try {
      return _societies.firstWhere((s) => s.id == societyId).name;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1220), Color(0xFF05070D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Responsabilidades Semanais',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Configure quais sociedades serão responsáveis por cada ação em cada semana do mês',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: 4,
                        itemBuilder: (context, index) {
                          final weekNumber = index + 1;
                          final assignment = _assignments.firstWhere(
                            (a) => a.weekNumber == weekNumber,
                            orElse: () =>
                                WeeklyTeamAssignment(weekNumber: weekNumber),
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _buildWeekSection(weekNumber, assignment),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveAssignments,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar configurações'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekSection(int weekNumber, WeeklyTeamAssignment assignment) {
    final theme = Theme.of(context);
    final isExpanded = _expandedWeeks[weekNumber] ?? false;

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedWeeks[weekNumber] = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Text(
            'Semana $weekNumber',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          children: [
            _buildResponsibilityCard(
              title: 'Abertura EBD',
              icon: Icons.school,
              societyId: assignment.aberturaEbd,
              onTap: () => _selectSocietyForWeek(
                weekNumber: weekNumber,
                responsibility: 'aberturaEbd',
              ),
            ),
            const SizedBox(height: 12),
            _buildResponsibilityCard(
              title: 'Montar liturgia',
              icon: Icons.menu_book,
              societyId: assignment.liturgia,
              onTap: () => _selectSocietyForWeek(
                weekNumber: weekNumber,
                responsibility: 'liturgia',
              ),
            ),
            const SizedBox(height: 12),
            _buildResponsibilityCard(
              title: 'Lanche pós-culto',
              icon: Icons.restaurant,
              societyId: assignment.lanche,
              onTap: () => _selectSocietyForWeek(
                weekNumber: weekNumber,
                responsibility: 'lanche',
              ),
            ),
            const SizedBox(height: 12),
            _buildResponsibilityCard(
              title: 'Reunião de oração',
              icon: Icons.favorite,
              societyId: assignment.reuniaoOracao,
              onTap: () => _selectSocietyForWeek(
                weekNumber: weekNumber,
                responsibility: 'reuniaoOracao',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsibilityCard({
    required String title,
    required IconData icon,
    String? societyId,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final societyName = _getSocietyName(societyId);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    societyName ?? 'Nenhuma sociedade atribuída',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: societyName != null
                          ? Colors.white70
                          : Colors.white54,
                      fontStyle: societyName == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              societyName != null ? Icons.edit : Icons.add,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

class _SocietySelectorSheet extends StatelessWidget {
  const _SocietySelectorSheet({required this.societies, this.currentSocietyId});

  final List<SocietyModel> societies;
  final String? currentSocietyId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Selecionar sociedade',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Opção para remover sociedade (apenas se houver uma selecionada)
                      if (currentSocietyId != null &&
                          currentSocietyId!.isNotEmpty)
                        InkWell(
                          onTap: () => Navigator.of(context).pop(''),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red.withOpacity(0.8),
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Remover sociedade',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Colors.red.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (societies.isNotEmpty &&
                          (currentSocietyId == null ||
                              currentSocietyId!.isEmpty))
                        const SizedBox(height: 12),
                      if (currentSocietyId != null &&
                          currentSocietyId!.isNotEmpty &&
                          societies.isNotEmpty)
                        const SizedBox(height: 12),
                      // Lista de sociedades
                      ...societies.map((society) {
                        final isSelected = society.id == currentSocietyId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(society.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white.withOpacity(0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Color(society.color),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      society.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                          ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
