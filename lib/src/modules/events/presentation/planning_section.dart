import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/utils/app_toast.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import '../models/event_template.dart';
import 'event_editor_page.dart';
import 'widgets/event_form_sheet.dart';

class PlanningSection extends StatefulWidget {
  const PlanningSection({super.key, required this.user, this.onEventsChanged});

  final UserModel user;
  final ValueChanged<bool>? onEventsChanged;

  @override
  State<PlanningSection> createState() => _PlanningSectionState();
}

class _PlanningSectionState extends State<PlanningSection> {
  final _dateFormat = DateFormat('dd/MM/yy');
  bool _isLoading = true;
  List<EventModel> _events = const [];
  String? _error;
  List<String> _selectedTemplateIds = []; // Lista vazia = Todos
  List<EventTemplateModel> _templates = [];
  bool _isLoadingTemplates = true;
  bool _isSelectionMode = false;
  Set<String> _selectedEventIds = {};
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  /// Compara apenas a data (sem hora) de dois DateTime
  bool _isDateBeforeToday(DateTime date) {
    final now = DateTime.now();
    final eventDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return eventDate.isBefore(today);
  }

  /// Verifica se a data é igual ou maior que hoje (remove eventos de dias anteriores)
  bool _isDateTodayOrAfter(DateTime date) {
    final now = DateTime.now();
    final eventDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    // Retorna true apenas se a data do evento for >= hoje (remove ontem e anteriores)
    return !eventDate.isBefore(today);
  }

  /// Compara dois horários no formato "HH:mm"
  /// Retorna negativo se time1 < time2, zero se iguais, positivo se time1 > time2
  int _compareTime(String time1, String time2) {
    // Se algum horário estiver vazio, tratar como início do dia (00:00)
    if (time1.isEmpty && time2.isEmpty) return 0;
    if (time1.isEmpty) return -1; // time1 vem antes
    if (time2.isEmpty) return 1; // time2 vem antes

    // Converter "HH:mm" para minutos do dia para comparação
    final minutes1 = _timeToMinutes(time1);
    final minutes2 = _timeToMinutes(time2);

    return minutes1.compareTo(minutes2);
  }

  /// Converte um horário no formato "HH:mm" para minutos do dia (0-1439)
  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    return hours * 60 + minutes;
  }

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _loadEvents();
    _scrollController.addListener(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadEvents,
          color: Theme.of(context).colorScheme.primary,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 160),
                  children: [
                    const SizedBox(height: 120),
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                )
              : _events.isEmpty
              ? ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 160),
                  children: const [
                    SizedBox(height: 120),
                    Icon(
                      Icons.celebration_outlined,
                      size: 68,
                      color: Colors.white38,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Monte o roteiro do próximo culto e envolva toda a equipe.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.separated(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 160),
                  itemCount: _events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final isPastEvent = _isDateBeforeToday(event.date);
                    final isSelected = _selectedEventIds.contains(event.id);
                    return _PlanningCard(
                      event: event,
                      dateLabel: _dateFormat.format(event.date),
                      timeLabel: event.start.isNotEmpty ? event.start : '',
                      isPastEvent: isPastEvent,
                      isSelectionMode: _isSelectionMode,
                      isSelected: isSelected,
                      onOpen: _isSelectionMode ? null : () => _openEvent(event),
                      onLongPress: () => _enterSelectionMode(event.id),
                      onTap: _isSelectionMode
                          ? () => _toggleEventSelection(event.id)
                          : null,
                      onEdit: isPastEvent || _isSelectionMode
                          ? null
                          : () => _onEditEvent(event),
                      onDelete: isPastEvent || _isSelectionMode
                          ? null
                          : () => _onDeleteEvent(event),
                    );
                  },
                ),
        ),
        // Botão de filtro / selecionar todos
        Positioned(
          bottom: 200,
          right: 0,
          child: FloatingActionButton(
            heroTag: 'filter_planning',
            onPressed: _isSelectionMode
                ? _toggleSelectAll
                : _showTemplateFilter,
            child: Icon(
              _isSelectionMode ? Icons.select_all : Icons.filter_list,
            ),
          ),
        ),
        // Botão de adicionar / excluir
        Positioned(
          bottom: 130,
          right: 0,
          child: FloatingActionButton(
            heroTag: 'add_delete_planning',
            onPressed: _isSelectionMode
                ? _deleteSelectedEvents
                : _onCreateEvent,
            backgroundColor: _isSelectionMode ? Colors.red : null,
            child: Icon(_isSelectionMode ? Icons.delete : Icons.add),
          ),
        ),
      ],
    );
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repository = context.read<EventsRepository>();
      final allEvents = _selectedTemplateIds.isEmpty
          ? await repository.fetchAllServices()
          : await repository.fetchServicesByTemplates(_selectedTemplateIds);

      // Filtrar apenas eventos com data >= hoje -1 dia
      final filteredEvents = allEvents
          .where((event) => _isDateTodayOrAfter(event.date))
          .toList();

      // Ordenar eventos por data e horário crescente
      filteredEvents.sort((a, b) {
        // Primeiro compara a data
        final dateComparison = a.date.compareTo(b.date);
        if (dateComparison != 0) {
          return dateComparison;
        }
        // Se as datas forem iguais, compara o horário
        return _compareTime(a.start, b.start);
      });

      setState(() {
        _events = filteredEvents;
      });
      // Notificar o HomeShell sobre o estado dos eventos
      widget.onEventsChanged?.call(filteredEvents.isNotEmpty);
    } catch (error) {
      setState(() => _error = 'Erro ao carregar os serviços.');
      widget.onEventsChanged?.call(false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final repository = context.read<EventsRepository>();
      final templates = await repository.fetchAllTemplates();
      setState(() {
        _templates = templates;
        _isLoadingTemplates = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTemplates = false;
      });
      // Erro silencioso
    }
  }

  Future<void> _onCreateEvent() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const EventFormSheet(),
    );
    if (created == true) {
      await _loadEvents();
    }
  }

  Future<void> _onEditEvent(EventModel event) async {
    final repository = context.read<EventsRepository>();
    final fullEvent = await repository.fetchById(event.id);
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventFormSheet(event: fullEvent),
    );
    if (updated == true) {
      await _loadEvents();
    }
  }

  Future<void> _onDeleteEvent(EventModel event) async {
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
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await context.read<EventsRepository>().deleteEvent(event.id);
    if (mounted) {
      showSuccessToast(context, 'Evento "${event.name}" excluído.');
      await _loadEvents();
    }
  }

  Future<void> _openEvent(EventModel event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventEditorPage(eventId: event.id)),
    );
    await _loadEvents();
    if (mounted) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollOffset);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(_scrollOffset);
          }
        });
      }
    }
  }

  void _enterSelectionMode(String eventId) {
    setState(() {
      _isSelectionMode = true;
      _selectedEventIds = {eventId};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedEventIds.clear();
    });
  }

  void _toggleEventSelection(String eventId) {
    setState(() {
      if (_selectedEventIds.contains(eventId)) {
        _selectedEventIds.remove(eventId);
      } else {
        _selectedEventIds.add(eventId);
      }
      // Se não houver mais seleções, sair do modo de seleção
      if (_selectedEventIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedEventIds.length == _events.length) {
        // Se todos estão selecionados, desselecionar todos
        _selectedEventIds.clear();
        // Se não houver mais seleções, sair do modo de seleção
        if (_selectedEventIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        // Selecionar todos
        _selectedEventIds = _events.map((e) => e.id).toSet();
      }
    });
  }

  Future<void> _deleteSelectedEvents() async {
    if (_selectedEventIds.isEmpty) return;

    final count = _selectedEventIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text(
          'Excluir eventos',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Deseja realmente excluir $count evento(s) selecionado(s)? Esta ação não poderá ser desfeita.',
          style: const TextStyle(color: Colors.white70),
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
      int deletedCount = 0;

      for (final eventId in _selectedEventIds) {
        try {
          await repository.deleteEvent(eventId);
          deletedCount++;
        } catch (e) {
          // Continuar mesmo se algum falhar
        }
      }

      if (mounted) {
        _exitSelectionMode();
        if (deletedCount > 0) {
          showSuccessToast(
            context,
            '$deletedCount evento(s) excluído(s) com sucesso.',
          );
          await _loadEvents();
        } else {
          showErrorToast(context, 'Erro ao excluir eventos.');
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao excluir eventos.');
      }
    }
  }

  void _showTemplateFilter() {
    final tempSelectedTemplateIds = List<String>.from(_selectedTemplateIds);

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
                  'Filtrar por Template',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
              Flexible(
                child: _isLoadingTemplates
                    ? const Center(child: CircularProgressIndicator())
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount:
                              2 +
                              _templates
                                  .length, // Todos + Sem template + templates
                          itemBuilder: (context, index) {
                            String displayName;
                            String value;

                            if (index == 0) {
                              displayName = 'Todos';
                              value = 'ALL';
                            } else if (index == 1) {
                              displayName = 'Sem template';
                              value = 'NO_TEMPLATE';
                            } else {
                              final template = _templates[index - 2];
                              displayName = template.name;
                              value = template.id;
                            }

                            final isSelected = value == 'ALL'
                                ? tempSelectedTemplateIds.isEmpty
                                : tempSelectedTemplateIds.contains(value);

                            return CheckboxListTile(
                              value: isSelected,
                              title: Text(
                                displayName,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              onChanged: value == 'ALL'
                                  ? null
                                  : (bool? checked) {
                                      setModalState(() {
                                        if (checked == true) {
                                          if (!tempSelectedTemplateIds.contains(
                                            value,
                                          )) {
                                            tempSelectedTemplateIds.add(value);
                                          }
                                        } else {
                                          tempSelectedTemplateIds.remove(value);
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
                          tempSelectedTemplateIds.clear();
                        });
                      },
                      child: const Text('Limpar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _selectedTemplateIds = List<String>.from(
                            tempSelectedTemplateIds,
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

class _PlanningCard extends StatelessWidget {
  const _PlanningCard({
    required this.event,
    required this.dateLabel,
    required this.timeLabel,
    required this.isPastEvent,
    required this.isSelectionMode,
    required this.isSelected,
    this.onOpen,
    this.onLongPress,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final EventModel event;
  final String dateLabel;
  final String timeLabel;
  final bool isPastEvent;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onOpen;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Aplicar opacidade reduzida para eventos passados
    final opacity = isPastEvent ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: onTap ?? onOpen,
        child: Container(
          decoration: isSelectionMode && isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox no modo de seleção, ícone normal caso contrário
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: onTap != null ? (_) => onTap!() : null,
                    activeColor: theme.colorScheme.primary,
                  )
                else
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.calendar_month,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeLabel.isNotEmpty
                            ? '$dateLabel · $timeLabel'
                            : dateLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isSelectionMode && (onEdit != null || onDelete != null))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: onEdit,
                        ),
                      if (onDelete != null)
                        IconButton(
                          tooltip: 'Excluir',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: onDelete,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
