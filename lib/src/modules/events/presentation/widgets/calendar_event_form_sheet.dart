import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../shared/utils/app_toast.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../societies/data/societies_repository.dart';
import '../../../societies/models/society.dart';
import '../../data/events_repository.dart';
import '../../models/calendar_event.dart';

class CalendarEventFormSheet extends StatefulWidget {
  const CalendarEventFormSheet({
    super.key,
    required this.initialDate,
    required this.selectedCategory,
    this.eventsForDate = const [],
    this.event,
  });

  final DateTime initialDate;
  final String selectedCategory;
  final List<CalendarEventModel> eventsForDate;
  final CalendarEventModel? event; // Evento para edição (null = novo evento)

  @override
  State<CalendarEventFormSheet> createState() => _CalendarEventFormSheetState();
}

class _CalendarEventFormSheetState extends State<CalendarEventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController(text: '00:00');
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _timeFormat = DateFormat('HH:mm');

  late DateTime _selectedDate;
  String _selectedCategory = 'Geral';
  bool _isSubmitting = false;
  List<CalendarEventModel> _eventsForDate = [];
  List<SocietyModel> _societies = [];
  bool _isLoadingSocieties = true;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      // Modo edição
      _selectedDate = event.date;
      _selectedCategory = event.category;
      _nameController.text = event.name;
      _timeController.text = event.start;
      _dateController.text = _dateFormat.format(event.date);
    } else {
      // Modo criação
      _selectedDate = widget.initialDate;
      _selectedCategory = widget.selectedCategory.isEmpty ? 'Geral' : widget.selectedCategory;
      _dateController.text = _dateFormat.format(_selectedDate);
      _timeController.text = _timeFormat.format(_selectedDate);
    }
    _eventsForDate = widget.eventsForDate;
    _loadSocieties();
    _loadEventsForDate(_selectedDate);
  }

  Future<void> _loadSocieties() async {
    try {
      final repository = context.read<SocietiesRepository>();
      final societies = await repository.fetchAll();
      setState(() {
        _societies = societies;
        _isLoadingSocieties = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSocieties = false;
      });
      // Erro silencioso
    }
  }

  Future<void> _loadEventsForDate(DateTime date) async {
    try {
      final repository = context.read<EventsRepository>();
      // Buscar eventos de todas as categorias para mostrar na lista
      final events = await repository.fetchCalendarEventsByDate(date);
      if (mounted) {
        setState(() {
          _eventsForDate = events;
        });
      }
    } catch (e) {
      // Erro silencioso - apenas manter a lista vazia
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  widget.event == null ? 'Novo Evento' : 'Editar Evento',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nome do evento',
                    hintText: 'Digite o nome do evento',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe o nome do evento';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Data',
                    hintText: 'Selecione a data',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintStyle: const TextStyle(color: Colors.white54),
                    suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                  ),
                  onTap: _isSubmitting ? null : _selectDate,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _isSubmitting ? null : _selectTime,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _timeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Horário',
                        hintText: 'Selecione o horário',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintStyle: TextStyle(color: Colors.white54),
                        suffixIcon: Icon(Icons.schedule, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _isLoadingSocieties
                    ? const SizedBox(
                        height: 56,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _societies.isEmpty
                        ? TextFormField(
                            controller: TextEditingController(text: _selectedCategory),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Categoria',
                              labelStyle: TextStyle(color: Colors.white70),
                              hintText: 'Digite o nome da categoria',
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                            onChanged: (value) {
                              _selectedCategory = value;
                            },
                          )
                        : DropdownButtonFormField<String>(
                            value: _selectedCategory.isEmpty 
                                ? 'Geral'
                                : _selectedCategory,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Categoria',
                              labelStyle: TextStyle(color: Colors.white70),
                              suffixIcon: Icon(Icons.label, color: Colors.white70),
                            ),
                            dropdownColor: const Color(0xFF1A1F2E),
                            items: [
                              // Opção fixa "Geral" com bolinha verde
                              DropdownMenuItem<String>(
                                value: 'Geral',
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Geral'),
                                  ],
                                ),
                              ),
                              // Societies do Firestore
                              ..._societies.map((society) {
                                return DropdownMenuItem<String>(
                                  value: society.name,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: Color(society.color),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(society.name),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: _isSubmitting
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedCategory = value;
                                      });
                                    }
                                  },
                          ),
                // Lista de eventos da data selecionada
                if (_eventsForDate.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Eventos já cadastrados para esta data:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _eventsForDate.length,
                      itemBuilder: (context, index) {
                        final event = _eventsForDate[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 16,
                                  color: theme.colorScheme.primary,
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
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        event.category,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2F4F2F),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1F2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      // Preservar a hora ao mudar a data
      final timeParts = _timeController.text.split(':');
      final hour = timeParts.length == 2 ? int.tryParse(timeParts[0]) ?? 0 : 0;
      final minute = timeParts.length == 2 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          hour,
          minute,
        );
        _dateController.text = _dateFormat.format(picked);
      });
      // Carregar eventos da nova data selecionada
      await _loadEventsForDate(picked);
    }
  }

  TimeOfDay _parseTimeFromInput() {
    final timeText = _timeController.text.trim();
    if (timeText.isNotEmpty) {
      try {
        final parts = timeText.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null && 
              hour >= 0 && hour < 24 && 
              minute >= 0 && minute < 60) {
            return TimeOfDay(hour: hour, minute: minute);
          }
        }
      } catch (e) {
        // Se houver erro ao fazer parse, usa o horário padrão
      }
    }
    // Retorna 00:00 como padrão se não conseguir fazer parse
    return const TimeOfDay(hour: 0, minute: 0);
  }

  Future<void> _selectTime() async {
    final initialTime = _parseTimeFromInput();
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time != null) {
      final formatted =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      _timeController.text = formatted;
      
      // Atualizar _selectedDate com a nova hora
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          time.hour,
          time.minute,
        );
      });
    }
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Combinar data e hora
      final timeParts = _timeController.text.split(':');
      final hour = timeParts.length == 2 ? int.tryParse(timeParts[0]) ?? 0 : 0;
      final minute = timeParts.length == 2 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      
      final eventDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
        minute,
      );

      final repository = context.read<EventsRepository>();
      
      if (widget.event != null) {
        // Modo edição
        await repository.updateCalendarEvent(
          id: widget.event!.id,
          name: _nameController.text.trim(),
          date: eventDate,
          category: _selectedCategory,
          start: _timeController.text.trim(),
        );

        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessToast(context, 'Evento atualizado com sucesso!');
        }
      } else {
        // Modo criação
        await repository.createCalendarEvent(
          name: _nameController.text.trim(),
          date: eventDate,
          category: _selectedCategory,
          start: _timeController.text.trim(),
        );

        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessToast(context, 'Evento criado com sucesso!');
        }
      }
    } catch (error) {
      if (mounted) {
        showErrorToast(
          context,
          widget.event != null
              ? 'Erro ao atualizar evento. Tente novamente.'
              : 'Erro ao criar evento. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

