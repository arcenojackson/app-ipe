import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'dart:math';

import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../societies/data/societies_repository.dart';
import '../../societies/models/society.dart';
import '../data/events_repository.dart';
import '../data/weekly_team_assignments_repository.dart';
import '../models/calendar_event.dart';
import '../models/event.dart';
import '../models/weekly_team_assignment.dart';
import 'widgets/calendar_event_form_sheet.dart';

enum CalendarViewMode { day, week, month }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.hideHeader = false});

  final bool hideHeader;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarViewMode _viewMode = CalendarViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<String> _selectedCategories = []; // Lista vazia = Todos
  List<CalendarEventModel> _events = [];
  List<SocietyModel> _societies = [];
  Map<String, Color> _categoryColors = {}; // Mapa categoria -> cor
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSocieties();
    _loadEvents();
  }

  Future<void> _loadSocieties() async {
    try {
      final repository = context.read<SocietiesRepository>();
      final societies = await repository.fetchAll();
      final categoryColors = <String, Color>{};

      for (final society in societies) {
        categoryColors[society.name] = Color(society.color);
      }

      setState(() {
        _societies = societies;
        _categoryColors = categoryColors;
      });
    } catch (e) {
      // Erro silencioso - continua sem cores
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = context.read<EventsRepository>();
      final events = _selectedCategories.isEmpty
          ? await repository.fetchAllCalendarEvents()
          : await repository.fetchCalendarEventsByCategories(
              _selectedCategories,
            );
      setState(() {
        _events = events;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar eventos: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<CalendarEventModel> _getEventsForDay(DateTime day) {
    return _events.where((event) {
      return isSameDay(event.date, day);
    }).toList();
  }

  Widget _buildEventMarkers(List<CalendarEventModel> events) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: events.map((event) {
        final color =
            _categoryColors[event.category] ??
            Theme.of(context).colorScheme.primary;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 6.0,
          height: 6.0,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        );
      }).toList(),
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    // Ajustar o dia selecionado para o novo mês
    final newSelectedDay = _adjustSelectedDayForNewMonth(_selectedDay, focusedDay);
    
    setState(() {
      _focusedDay = focusedDay;
      _selectedDay = newSelectedDay;
    });
  }

  /// Ajusta o dia selecionado quando o mês muda.
  /// Se o dia existe no novo mês, mantém o mesmo dia.
  /// Caso contrário, seleciona o último dia do novo mês.
  DateTime _adjustSelectedDayForNewMonth(DateTime currentSelectedDay, DateTime newMonth) {
    final selectedDay = currentSelectedDay.day;
    final newYear = newMonth.year;
    final newMonthValue = newMonth.month;
    
    // Calcular o último dia do novo mês
    final lastDayOfNewMonth = DateTime(newYear, newMonthValue + 1, 0).day;
    
    // Se o dia selecionado existe no novo mês, usar o mesmo dia
    if (selectedDay <= lastDayOfNewMonth) {
      return DateTime(newYear, newMonthValue, selectedDay);
    } else {
      // Caso contrário, usar o último dia do novo mês
      return DateTime(newYear, newMonthValue, lastDayOfNewMonth);
    }
  }

  Future<void> _showAddEventDialog() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CalendarEventFormSheet(
        initialDate: _selectedDay,
        selectedCategory: _selectedCategories.isEmpty
            ? 'Geral'
            : _selectedCategories.first,
        eventsForDate: _getEventsForDay(_selectedDay),
      ),
    );

    if (result == true) {
      await _loadEvents();
    }
  }

  /// Obtém todos os domingos do mês
  List<DateTime> _getSundaysInMonth(DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final sundays = <DateTime>[];

    // Encontrar o primeiro domingo do mês
    // weekday: 1=segunda, 2=terça, ..., 7=domingo
    final firstSundayOffset = monthStart.weekday == 7 ? 0 : 7 - monthStart.weekday;
    
    DateTime currentSunday = monthStart.add(Duration(days: firstSundayOffset));

    // Adicionar todos os domingos do mês
    while (currentSunday.year == monthStart.year && 
           currentSunday.month == monthStart.month) {
      sundays.add(DateTime(currentSunday.year, currentSunday.month, currentSunday.day));
      currentSunday = currentSunday.add(const Duration(days: 7));
    }

    return sundays;
  }

  /// Obtém todas as quartas-feiras do mês
  List<DateTime> _getWednesdaysInMonth(DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final wednesdays = <DateTime>[];

    // Encontrar a primeira quarta-feira do mês
    int firstWednesdayOffset = 3 - monthStart.weekday;
    if (firstWednesdayOffset < 0) {
      firstWednesdayOffset += 7;
    }

    DateTime currentWednesday = monthStart.add(Duration(days: firstWednesdayOffset));

    // Adicionar todas as quartas-feiras do mês
    while (currentWednesday.year == monthStart.year && 
           currentWednesday.month == monthStart.month) {
      wednesdays.add(DateTime(currentWednesday.year, currentWednesday.month, currentWednesday.day));
      currentWednesday = currentWednesday.add(const Duration(days: 7));
    }

    return wednesdays;
  }

  /// Busca o ID de um template pelo nome
  Future<String?> _findTemplateIdByName(String name) async {
    try {
      final repository = context.read<EventsRepository>();
      final templates = await repository.fetchAllTemplates();
      final template = templates.firstWhere(
        (t) => t.name == name,
        orElse: () => throw Exception('Template não encontrado'),
      );
      return template.id;
    } catch (e) {
      return null;
    }
  }

  /// Determina qual semana do mês uma data pertence (1-5)
  /// Baseado no primeiro domingo/quarta do mês, independente de quando o mês começou
  int _getWeekOfMonthForSunday(DateTime date, DateTime month) {
    final firstSunday = _getSundaysInMonth(month).first;
    final daysDifference = date.difference(firstSunday).inDays;
    return (daysDifference ~/ 7) + 1;
  }

  int _getWeekOfMonthForWednesday(DateTime date, DateTime month) {
    final firstWednesday = _getWednesdaysInMonth(month).first;
    final daysDifference = date.difference(firstWednesday).inDays;
    return (daysDifference ~/ 7) + 1;
  }

  /// Seleciona aleatoriamente uma sociedade das 4 semanas configuradas
  String? _selectRandomSocietyForWeek5(
    List<WeeklyTeamAssignment> assignments,
    String responsibility,
  ) {
    final societies = <String>[];
    
    for (final assignment in assignments) {
      String? societyId;
      switch (responsibility) {
        case 'liturgia':
          societyId = assignment.liturgia;
          break;
        case 'lanche':
          societyId = assignment.lanche;
          break;
        case 'aberturaEbd':
          societyId = assignment.aberturaEbd;
          break;
        case 'reuniaoOracao':
          societyId = assignment.reuniaoOracao;
          break;
      }
      
      if (societyId != null && societyId.isNotEmpty) {
        societies.add(societyId);
      }
    }
    
    if (societies.isEmpty) return null;
    
    final random = Random();
    return societies[random.nextInt(societies.length)];
  }

  /// Obtém a sociedade responsável para uma semana específica e responsabilidade
  String? _getSocietyForWeek(
    List<WeeklyTeamAssignment> assignments,
    int weekNumber,
    String responsibility,
  ) {
    // Se for semana 5, usar seleção aleatória
    if (weekNumber > 4) {
      return _selectRandomSocietyForWeek5(assignments, responsibility);
    }
    
    final assignment = assignments.firstWhere(
      (a) => a.weekNumber == weekNumber,
      orElse: () => WeeklyTeamAssignment(weekNumber: weekNumber),
    );
    
    String? societyId;
    switch (responsibility) {
      case 'liturgia':
        societyId = assignment.liturgia;
        break;
      case 'lanche':
        societyId = assignment.lanche;
        break;
      case 'aberturaEbd':
        societyId = assignment.aberturaEbd;
        break;
      case 'reuniaoOracao':
        societyId = assignment.reuniaoOracao;
        break;
      default:
        return null;
    }
    
    // Retornar null se for string vazia ou null
    if (societyId == null || societyId.isEmpty) {
      return null;
    }
    
    return societyId;
  }

  /// Cria todos os eventos fixos do mês (Cultos, EBDs e Reuniões de Oração)
  Future<void> _createAllMonthlyEvents(DateTime month) async {
    final repository = context.read<EventsRepository>();
    final assignmentsRepository = context.read<WeeklyTeamAssignmentsRepository>();
    
    // Buscar IDs dos templates e configurações semanais
    final results = await Future.wait([
      _findTemplateIdByName('Culto à noite'),
      _findTemplateIdByName('Culto de Ceia'),
      _findTemplateIdByName('Escola Bíblica'),
      _findTemplateIdByName('Reunião de Oração'),
      assignmentsRepository.fetchAll(),
    ]);
    
    final cultoNoiteId = results[0] as String?;
    final cultoCeiId = results[1] as String?;
    final ebdId = results[2] as String?;
    final reuniaoOracaoId = results[3] as String?;
    final weeklyAssignments = results[4] as List<WeeklyTeamAssignment>;

    int totalCreated = 0;
    int totalSkipped = 0;

    // Criar eventos de Reunião de Oração (quartas às 19h30)
    if (reuniaoOracaoId != null) {
      final wednesdays = _getWednesdaysInMonth(month);
      for (final date in wednesdays) {
        try {
          final event = await repository.createEvent(
            name: 'Reunião de Oração',
            date: date,
            start: '19:30',
            templateId: reuniaoOracaoId,
          );
          
          // Aplicar equipe responsável
          final weekNumber = _getWeekOfMonthForWednesday(date, month);
          final societyId = _getSocietyForWeek(
            weeklyAssignments,
            weekNumber,
            'reuniaoOracao',
          );
          
          if (societyId != null && societyId.isNotEmpty) {
            await repository.updateEventDetails(
              id: event.id,
              steps: event.steps,
              people: event.people,
              teams: EventTeams(
                reuniaoOracao: societyId,
              ),
            );
          }
          
          totalCreated++;
        } catch (e) {
          totalSkipped++;
        }
      }
    }

    // Criar eventos de Escola Bíblica (domingos às 10h)
    if (ebdId != null) {
      final sundays = _getSundaysInMonth(month);
      for (final date in sundays) {
        try {
          final event = await repository.createEvent(
            name: 'Escola Bíblica',
            date: date,
            start: '10:00',
            templateId: ebdId,
          );
          
          // Aplicar equipe responsável (Abertura EBD)
          final weekNumber = _getWeekOfMonthForSunday(date, month);
          final societyId = _getSocietyForWeek(
            weeklyAssignments,
            weekNumber,
            'aberturaEbd',
          );
          
          if (societyId != null && societyId.isNotEmpty) {
            await repository.updateEventDetails(
              id: event.id,
              steps: event.steps,
              people: event.people,
              teams: EventTeams(
                aberturaEbd: societyId,
              ),
            );
          }
          
          totalCreated++;
        } catch (e) {
          totalSkipped++;
        }
      }
    }

    // Criar eventos de Culto à noite (domingos às 19h30)
    // Primeiro domingo: Culto de Ceia, demais: Culto à noite
    if (cultoNoiteId != null) {
      final sundays = _getSundaysInMonth(month);
      for (int i = 0; i < sundays.length; i++) {
        final date = sundays[i];
        final isFirstSunday = i == 0;
        final templateId = isFirstSunday && cultoCeiId != null ? cultoCeiId : cultoNoiteId;
        final eventName = isFirstSunday && cultoCeiId != null ? 'Culto de Ceia' : 'Culto à noite';

        try {
          final event = await repository.createEvent(
            name: eventName,
            date: date,
            start: '19:30',
            templateId: templateId,
          );
          
          // Aplicar equipes responsáveis (Liturgia e Lanche)
          final weekNumber = _getWeekOfMonthForSunday(date, month);
          final liturgiaId = _getSocietyForWeek(
            weeklyAssignments,
            weekNumber,
            'liturgia',
          );
          final lancheId = _getSocietyForWeek(
            weeklyAssignments,
            weekNumber,
            'lanche',
          );
          
          // Sempre criar EventTeams (mesmo que alguns valores sejam null)
          // O repository só atualiza os campos não-null
          final liturgiaFinal = (liturgiaId != null && liturgiaId.isNotEmpty) ? liturgiaId : null;
          final lancheFinal = (lancheId != null && lancheId.isNotEmpty) ? lancheId : null;
          
          if (liturgiaFinal != null || lancheFinal != null) {
            await repository.updateEventDetails(
              id: event.id,
              steps: event.steps,
              people: event.people,
              teams: EventTeams(
                liturgia: liturgiaFinal,
                lanche: lancheFinal,
              ),
            );
          }
          
          totalCreated++;
        } catch (e) {
          totalSkipped++;
        }
      }
    }

    if (mounted) {
      if (totalCreated > 0) {
        showSuccessToast(
          context,
          '$totalCreated evento(s) criado(s) com sucesso${totalSkipped > 0 ? " ($totalSkipped ignorado(s))" : ""}!',
        );
      } else {
        showErrorToast(context, 'Nenhum evento foi criado.');
      }
    }
  }

  Future<void> _showBatchEventCreator() async {
    // Obter o nome do mês em português
    final monthName = DateFormat('MMMM', 'pt_BR').format(_focusedDay);
    final capitalizedMonthName = monthName[0].toUpperCase() + monthName.substring(1);

    // Mostrar diálogo de confirmação
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text(
          'Criar compromissos fixos',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Você quer mesmo criar os eventos para todos os cultos, EBDs e reuniões de oração para o mês de $capitalizedMonthName?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: Color(0xFF1A1F2E),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Criando eventos...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Aguardar um pouco para garantir que o loading seja visível
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Criar todos os eventos
      await _createAllMonthlyEvents(_focusedDay);
      
      // Manter o loading por pelo menos 2-3 segundos no total
      await Future.delayed(const Duration(milliseconds: 2000));
    } catch (error) {
      if (mounted) {
        showErrorToast(
          context,
          'Erro ao criar eventos: ${error.toString()}',
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); // Fechar o loading
        await _loadEvents();
      }
    }
  }

  void _showAddEventMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.event, color: Colors.white70),
                  title: const Text('Novo Evento'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showAddEventDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_note, color: Colors.white70),
                  title: const Text('Criar compromissos fixos para o mês selecionado'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showBatchEventCreator();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editEvent(CalendarEventModel event) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CalendarEventFormSheet(
        initialDate: event.date,
        selectedCategory: event.category,
        eventsForDate: _getEventsForDay(event.date),
        event: event,
      ),
    );

    if (result == true) {
      await _loadEvents();
    }
  }

  Future<void> _deleteEvent(CalendarEventModel event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir evento'),
        content: Text(
          'Deseja realmente excluir "${event.name}"? Esta ação não poderá ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repository = context.read<EventsRepository>();
      await repository.deleteCalendarEvent(event.id);
      if (mounted) {
        showSuccessToast(context, 'Evento "${event.name}" excluído.');
        await _loadEvents();
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao excluir evento. Tente novamente.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = context.watch<AppState>().currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;

    final content = Column(
      children: [
        // AppBar - apenas quando não está no menu principal
        if (!widget.hideHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    'Calendário Anual',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Filtro de categoria
        if (_selectedCategories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.label, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _selectedCategories.map((category) {
                        // Obter a cor da categoria (society ou verde para "Geral")
                        final categoryColor = category == 'Geral'
                            ? theme.colorScheme.primary
                            : (_categoryColors[category] ??
                                  theme.colorScheme.primary);

                        return Chip(
                          label: Text(category),
                          backgroundColor: categoryColor.withOpacity(0.2),
                          labelStyle: theme.textTheme.bodySmall?.copyWith(
                            color: categoryColor,
                            fontWeight: FontWeight.w600,
                          ),
                          deleteIcon: Icon(
                            Icons.close,
                            size: 16,
                            color: categoryColor,
                          ),
                          onDeleted: () {
                            setState(() {
                              _selectedCategories.remove(category);
                            });
                            _loadEvents();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  if (_selectedCategories.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategories.clear();
                        });
                        _loadEvents();
                      },
                      child: const Text('Limpar'),
                    ),
                  ],
                ],
              ),
            ),
          ),

        // Modo de visualização
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SegmentedButtonTheme(
            data: SegmentedButtonThemeData(style: SegmentedButton.styleFrom()),
            child: SegmentedButton<CalendarViewMode>(
              segments: [
                ButtonSegment(
                  value: CalendarViewMode.day,
                  label: const Text('Dia'),
                  icon: const SizedBox.shrink(),
                ),
                ButtonSegment(
                  value: CalendarViewMode.week,
                  label: const Text('Semana'),
                  icon: const SizedBox.shrink(),
                ),
                ButtonSegment(
                  value: CalendarViewMode.month,
                  label: const Text('Mês'),
                  icon: const SizedBox.shrink(),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (Set<CalendarViewMode> newSelection) {
                setState(() {
                  _viewMode = newSelection.first;
                });
              },
            ),
          ),
        ),

        // Calendário
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEvents,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        Expanded(
                          flex: _viewMode == CalendarViewMode.day ? 1 : 4,
                          child: _buildCalendarView(),
                        ),
                        // Lista de eventos do dia selecionado
                        if (_viewMode == CalendarViewMode.month ||
                            _viewMode == CalendarViewMode.week)
                          Flexible(flex: 2, child: _buildEventList()),
                      ],
                    );
                  },
                ),
        ),
      ],
    );

    if (widget.hideHeader) {
      // Quando acessado pelo menu principal, usar Stack com Positioned
      return Stack(
        children: [
          content,
          // Botão de filtro (acima do botão +)
          Positioned(
            bottom: 200,
            right: 0,
            child: FloatingActionButton(
              heroTag: 'filter',
              onPressed: _showCategoryFilter,
              child: const Icon(Icons.filter_list),
            ),
          ),
          // Botão de adicionar (mesma posição que Planejar e Músicas)
          // Quando na visualização Mês, exibir menu com opções
          // Só exibir se o usuário for admin
          if (isAdmin)
            Positioned(
              bottom: 130,
              right: 0,
              child: FloatingActionButton(
                heroTag: 'add',
                onPressed: (_viewMode == CalendarViewMode.month)
                    ? _showAddEventMenu
                    : _showAddEventDialog,
                child: const Icon(Icons.add),
              ),
            ),
        ],
      );
    }

    // Quando acessado pelas Configurações, usar Scaffold completo
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1220), Color(0xFF05070D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(child: content),
      ),
      floatingActionButton: Stack(
        children: [
          // Botão de filtro (acima do botão + padrão do Flutter)
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'filter',
              onPressed: _showCategoryFilter,
              child: const Icon(Icons.filter_list),
            ),
          ),
          // Botão de adicionar (posição padrão do Flutter: bottom: 16, right: 16)
          // Só exibir se o usuário for admin
          if (isAdmin)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'add',
                onPressed: (_viewMode == CalendarViewMode.month)
                    ? _showAddEventMenu
                    : _showAddEventDialog,
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    switch (_viewMode) {
      case CalendarViewMode.day:
        return _buildDayView();
      case CalendarViewMode.week:
        return _buildWeekView();
      case CalendarViewMode.month:
        return _buildMonthView();
    }
  }

  Widget _buildMonthView() {
    return TableCalendar<CalendarEventModel>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _getEventsForDay,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      locale: 'pt_BR',
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
          return Positioned(bottom: 1, child: _buildEventMarkers(events));
        },
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: const TextStyle(color: Colors.white70),
        defaultTextStyle: const TextStyle(color: Colors.white),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
        rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: Colors.white70),
        weekendStyle: TextStyle(color: Colors.white70),
      ),
      onDaySelected: _onDaySelected,
      onPageChanged: _onPageChanged,
    );
  }

  Widget _buildWeekView() {
    return TableCalendar<CalendarEventModel>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _getEventsForDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarFormat: CalendarFormat.week,
      locale: 'pt_BR',
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
          return Positioned(bottom: 1, child: _buildEventMarkers(events));
        },
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: const TextStyle(color: Colors.white70),
        defaultTextStyle: const TextStyle(color: Colors.white),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
        rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: Colors.white70),
        weekendStyle: TextStyle(color: Colors.white70),
      ),
      onDaySelected: _onDaySelected,
      onPageChanged: _onPageChanged,
    );
  }

  Widget _buildDayView() {
    final events = _getEventsForDay(_selectedDay);
    final dateFormat = DateFormat('EEEE, d \'de\' MMMM \'de\' y', 'pt_BR');

    return Column(
      children: [
        // Navegação de dia
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedDay = _selectedDay.subtract(
                      const Duration(days: 1),
                    );
                    _focusedDay = _selectedDay;
                  });
                },
              ),
              Expanded(
                child: Text(
                  dateFormat.format(_selectedDay),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedDay = _selectedDay.add(const Duration(days: 1));
                    _focusedDay = _selectedDay;
                  });
                },
              ),
            ],
          ),
        ),
        // Lista de eventos
        Expanded(child: _buildDayEventList(events)),
      ],
    );
  }

  Widget _buildDayEventList(List<CalendarEventModel> events) {
    if (events.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              const Text(
                'Nenhum evento neste dia',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.category,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.start,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      color: Colors.white70,
                      onPressed: () => _editEvent(event),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      color: Colors.red.shade300,
                      onPressed: () => _deleteEvent(event),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay);

    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Eventos do dia ${DateFormat('dd/MM').format(_selectedDay)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                event.category,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                event.start,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: Colors.white70,
                              onPressed: () => _editEvent(event),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.red.shade300,
                              onPressed: () => _deleteEvent(event),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryFilter() {
    // Criar uma cópia local das categorias selecionadas para o modal
    final tempSelectedCategories = List<String>.from(_selectedCategories);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Filtrar por Categoria',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount:
                        2 + _societies.length, // Todos + Geral + societies
                    itemBuilder: (context, index) {
                      String category;
                      if (index == 0) {
                        category = 'Todos';
                      } else if (index == 1) {
                        category = 'Geral';
                      } else {
                        final society = _societies[index - 2];
                        category = society.name;
                      }

                      final isSelected = category == 'Todos'
                          ? tempSelectedCategories.isEmpty
                          : tempSelectedCategories.contains(category);

                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: category == 'Todos'
                            ? null // "Todos" não pode ser selecionado manualmente (é o estado padrão quando nada está selecionado)
                            : (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    if (!tempSelectedCategories.contains(
                                      category,
                                    )) {
                                      tempSelectedCategories.add(category);
                                    }
                                  } else {
                                    tempSelectedCategories.remove(category);
                                  }
                                });
                              },
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempSelectedCategories.clear();
                        });
                      },
                      child: const Text('Limpar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategories = List<String>.from(
                            tempSelectedCategories,
                          );
                        });
                        Navigator.of(context).pop();
                        _loadEvents();
                      },
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
