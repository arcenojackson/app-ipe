import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/glass_container.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import 'event_viewer_page.dart';

class EventHistoryPage extends StatefulWidget {
  const EventHistoryPage({super.key});

  @override
  State<EventHistoryPage> createState() => _EventHistoryPageState();
}

class _EventHistoryPageState extends State<EventHistoryPage> {
  final _dateFormat = DateFormat('dd/MM/yy');
  final _monthYearFormat = DateFormat('MMMM yyyy', 'pt_BR');
  bool _isLoading = true;
  List<EventModel> _events = const [];
  List<EventModel> _allPastEvents = const [];
  String? _error;
  DateTime? _selectedMonthYear;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      'Histórico de Liturgias',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Filtro por Mês/Ano
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedMonthYear != null
                              ? _monthYearFormat.format(_selectedMonthYear!)
                              : 'Todos os meses',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 18),
                        label: Text(
                          _selectedMonthYear != null ? 'Alterar' : 'Filtrar',
                        ),
                        onPressed: _selectMonthYear,
                      ),
                      if (_selectedMonthYear != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Remover filtro',
                          onPressed: () {
                            setState(() {
                              _selectedMonthYear = null;
                              _applyFilter();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadEvents,
                  color: Theme.of(context).colorScheme.primary,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? ListView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
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
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        )
                      : _events.isEmpty
                      ? ListView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
                          children: const [
                            Icon(
                              Icons.history,
                              size: 72,
                              color: Colors.white38,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nenhum evento no histórico.\nOs eventos passados aparecerão aqui.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                          itemCount: _events.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final event = _events[index];
                            return _HistoryCard(
                              event: event,
                              dateLabel: _dateFormat.format(event.date),
                              onOpen: () => _openEvent(event),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compara apenas a data (sem hora) de dois DateTime
  bool _isDateBeforeToday(DateTime date) {
    final now = DateTime.now();
    final eventDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return eventDate.isBefore(today);
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final allEvents =
          await context.read<EventsRepository>().fetchAllServices();
      // Filtrar apenas eventos passados (data < hoje)
      final pastEvents = allEvents
          .where((event) => _isDateBeforeToday(event.date))
          .toList();
      // Ordenar por data decrescente (mais recente primeiro)
      pastEvents.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _allPastEvents = pastEvents;
      });
      
      _applyFilter();
    } catch (error) {
      setState(() => _error = 'Erro ao carregar o histórico de eventos.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    if (_selectedMonthYear == null) {
      setState(() {
        _events = _allPastEvents;
      });
      return;
    }

    final selectedYear = _selectedMonthYear!.year;
    final selectedMonth = _selectedMonthYear!.month;

    final filtered = _allPastEvents.where((event) {
      return event.date.year == selectedYear &&
          event.date.month == selectedMonth;
    }).toList();

    setState(() {
      _events = filtered;
    });
  }

  Future<void> _selectMonthYear() async {
    final now = DateTime.now();
    final initialYear = _selectedMonthYear?.year ?? now.year;
    final initialMonth = _selectedMonthYear?.month ?? now.month;

    final result = await showModalBottomSheet<DateTime?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MonthYearPicker(
        initialYear: initialYear,
        initialMonth: initialMonth,
        maxYear: now.year,
        maxMonth: now.month,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedMonthYear = result;
        _applyFilter();
      });
    }
  }

  Future<void> _openEvent(EventModel event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventViewerPage(eventId: event.id),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.event,
    required this.dateLabel,
    required this.onOpen,
  });

  final EventModel event;
  final String dateLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Aplicar opacidade reduzida para eventos passados
    const opacity = 0.6;

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: onOpen,
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 18),
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
                    const SizedBox(height: 6),
                    Text(
                      'Data · $dateLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthYearPicker extends StatefulWidget {
  const _MonthYearPicker({
    required this.initialYear,
    required this.initialMonth,
    required this.maxYear,
    required this.maxMonth,
  });

  final int initialYear;
  final int initialMonth;
  final int maxYear;
  final int maxMonth;

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int _selectedYear;
  late int _selectedMonth;
  final List<String> _months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = List.generate(
      widget.maxYear - 2019,
      (index) => widget.maxYear - index,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Filtrar por mês/ano',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      DateTime(_selectedYear, _selectedMonth),
                    );
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: Row(
              children: [
                // Seletor de Mês
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Mês',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _months.length,
                          itemBuilder: (context, index) {
                            final month = index + 1;
                            final isSelected = _selectedMonth == month;
                            final isDisabled = _selectedYear == widget.maxYear &&
                                month > widget.maxMonth;

                            return ListTile(
                              enabled: !isDisabled,
                              selected: isSelected,
                              title: Text(
                                _months[index],
                                style: TextStyle(
                                  color: isDisabled
                                      ? Colors.white38
                                      : (isSelected
                                          ? theme.colorScheme.primary
                                          : Colors.white),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              onTap: isDisabled
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedMonth = month;
                                      });
                                    },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                // Seletor de Ano
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Ano',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: years.length,
                          itemBuilder: (context, index) {
                            final year = years[index];
                            final isSelected = _selectedYear == year;

                            return ListTile(
                              selected: isSelected,
                              title: Text(
                                year.toString(),
                                style: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedYear = year;
                                  // Ajustar mês se necessário
                                  if (_selectedYear == widget.maxYear &&
                                      _selectedMonth > widget.maxMonth) {
                                    _selectedMonth = widget.maxMonth;
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

