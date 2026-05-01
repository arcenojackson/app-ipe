import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../societies/models/society.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/events_repository.dart';

class WorshipTeamAvailabilityModal extends StatefulWidget {
  const WorshipTeamAvailabilityModal({
    super.key,
    required this.userId,
    this.eloSociety,
  });

  final String userId;
  final SocietyModel? eloSociety;

  @override
  State<WorshipTeamAvailabilityModal> createState() =>
      _WorshipTeamAvailabilityModalState();
}

class _WorshipTeamAvailabilityModalState
    extends State<WorshipTeamAvailabilityModal> {
  final Set<DateTime> _selectedSundays = {};
  Map<DateTime, int> _availabilityCounts = {};
  Map<DateTime, List<String>> _availabilityNames = {};
  bool _isLoading = false;
  bool _isSaving = false;

  List<String> get _ministrosIds => widget.eloSociety?.ministrosIds ?? [];

  List<String> get _allMemberIds {
    final elo = widget.eloSociety;
    if (elo == null) return [];
    return {
      ...elo.membersIds,
      ...elo.boardIds,
      ...elo.vocaisIds,
      ...elo.ministrosIds,
    }.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadExistingAvailability();
  }

  /// Carrega a disponibilidade já salva do usuário e, se aplicável, os contadores
  Future<void> _loadExistingAvailability() async {
    setState(() => _isLoading = true);
    try {
      final repository = context.read<EventsRepository>();
      final availability = await repository.fetchWorshipTeamAvailability(
        widget.userId,
      );
      setState(() {
        _selectedSundays.addAll(
          availability.map((date) => DateTime(date.year, date.month, date.day)),
        );
      });
      await _loadAvailabilityCounts();
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Carrega a contagem (apenas ministros) e os nomes (todos os membros) por domingo
  Future<void> _loadAvailabilityCounts() async {
    final sundays = _getNextMonthSundays();
    if (sundays.isEmpty) return;

    try {
      final repository = context.read<EventsRepository>();
      final futures = <Future>[];

      if (_ministrosIds.isNotEmpty) {
        futures.add(repository.getWorshipTeamAvailabilityCountByDate(_ministrosIds, sundays));
      } else {
        futures.add(Future.value(<DateTime, int>{}));
      }

      if (_allMemberIds.isNotEmpty) {
        futures.add(repository.getWorshipTeamAvailabilityNamesByDate(_allMemberIds, sundays));
      } else {
        futures.add(Future.value(<DateTime, List<String>>{}));
      }

      final results = await Future.wait(futures);
      if (mounted) {
        setState(() {
          _availabilityCounts = results[0] as Map<DateTime, int>;
          _availabilityNames = results[1] as Map<DateTime, List<String>>;
        });
      }
    } catch (e) {
      // Silenciar erro - contador é opcional
    }
  }

  void _showNamesForDate(DateTime date, List<String> names) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1220),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  'Disponíveis em ${_formatDate(date)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: names.isEmpty
                    ? Center(
                        child: Text(
                          'Ninguém informou disponibilidade para este dia.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        itemCount: names.length,
                        itemBuilder: (_, i) {
                          final name = names[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  name,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Obtém todos os domingos do mês seguinte
  List<DateTime> _getNextMonthSundays() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final lastDayOfMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0);

    final sundays = <DateTime>[];
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(nextMonth.year, nextMonth.month, day);
      if (date.weekday == DateTime.sunday) {
        sundays.add(date);
      }
    }
    return sundays;
  }

  /// Formata a data para exibição
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Formata o contador de ministros com concordância singular/plural
  String _formatCountLabel(int count) {
    return count == 1 ? '1 ministro disponível' : '$count ministros disponíveis';
  }

  /// Salva a disponibilidade no Firestore
  Future<void> _saveAvailability() async {
    setState(() => _isSaving = true);
    try {
      final repository = context.read<EventsRepository>();
      await repository.saveWorshipTeamAvailability(
        widget.userId,
        _selectedSundays.toList(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disponibilidade salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar disponibilidade: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextMonthSundays = _getNextMonthSundays();
    final monthName = DateFormat(
      'MMMM/yyyy',
      'pt_BR',
    ).format(DateTime(DateTime.now().year, DateTime.now().month + 1, 1));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disponibilidade - Equipe de Louvor',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selecione os domingos de $monthName em que você estará disponível',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : nextMonthSundays.isEmpty
                ? Center(
                    child: Text(
                      'Não há domingos no mês seguinte',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: nextMonthSundays.length,
                    itemBuilder: (context, index) {
                      final sunday = nextMonthSundays[index];
                      final normalizedSunday = DateTime(
                        sunday.year,
                        sunday.month,
                        sunday.day,
                      );
                      final isSelected = _selectedSundays.any(
                        (selected) =>
                            selected.year == normalizedSunday.year &&
                            selected.month == normalizedSunday.month &&
                            selected.day == normalizedSunday.day,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              final normalizedDate = DateTime(
                                sunday.year,
                                sunday.month,
                                sunday.day,
                              );
                              if (isSelected) {
                                _selectedSundays.removeWhere(
                                  (selected) =>
                                      selected.year == normalizedDate.year &&
                                      selected.month == normalizedDate.month &&
                                      selected.day == normalizedDate.day,
                                );
                              } else {
                                _selectedSundays.add(normalizedDate);
                              }
                            });
                          },
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : Colors.white38,
                                      width: 2,
                                    ),
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatDate(sunday),
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (_availabilityCounts.containsKey(normalizedSunday)) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatCountLabel(
                                            _availabilityCounts[normalizedSunday] ?? 0,
                                          ),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_availabilityCounts.containsKey(normalizedSunday))
                                  GestureDetector(
                                    onTap: () => _showNamesForDate(
                                      normalizedSunday,
                                      _availabilityNames[normalizedSunday] ?? [],
                                    ),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.group_outlined,
                                            size: 26,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${_availabilityNames[normalizedSunday]?.length ?? 0}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Footer with save button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF05070D),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAvailability,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Salvar disponibilidade',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
