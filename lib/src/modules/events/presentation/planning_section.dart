import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/utils/app_toast.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import 'event_editor_page.dart';
import 'widgets/event_form_sheet.dart';

class PlanningSection extends StatefulWidget {
  const PlanningSection({
    super.key,
    required this.user,
    this.onEventsChanged,
  });

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

  /// Compara apenas a data (sem hora) de dois DateTime
  bool _isDateBeforeToday(DateTime date) {
    final now = DateTime.now();
    final eventDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return eventDate.isBefore(today);
  }

  /// Verifica se a data é igual ou maior que hoje -1 dia
  bool _isDateTodayOrAfter(DateTime date) {
    final now = DateTime.now();
    final eventDate = DateTime(date.year, date.month, date.day);
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    return !eventDate.isBefore(yesterday);
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 160),
                  itemCount: _events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final isPastEvent = _isDateBeforeToday(event.date);
                    return _PlanningCard(
                      event: event,
                      dateLabel: _dateFormat.format(event.date),
                      timeLabel: event.start.isNotEmpty ? event.start : '',
                      isPastEvent: isPastEvent,
                      onOpen: () => _openEvent(event),
                      onEdit: isPastEvent ? null : () => _onEditEvent(event),
                      onDelete: isPastEvent ? null : () => _onDeleteEvent(event),
                    );
                  },
                ),
        ),
        Positioned(
          bottom: 130,
          right: 0,
          child: FloatingActionButton(
            onPressed: _onCreateEvent,
            child: const Icon(Icons.add),
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
      final allEvents = await context.read<EventsRepository>().fetchAllServices();
      
      // Filtrar apenas eventos com data >= hoje -1 dia
      final filteredEvents = allEvents
          .where((event) => _isDateTodayOrAfter(event.date))
          .toList();
      
      // Ordenar eventos por data crescente
      filteredEvents.sort((a, b) => a.date.compareTo(b.date));
      
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
  }
}

class _PlanningCard extends StatelessWidget {
  const _PlanningCard({
    required this.event,
    required this.dateLabel,
    required this.timeLabel,
    required this.isPastEvent,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
  });

  final EventModel event;
  final String dateLabel;
  final String timeLabel;
  final bool isPastEvent;
  final VoidCallback onOpen;
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
        onTap: onOpen,
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (onEdit != null || onDelete != null)
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
    );
  }
}
