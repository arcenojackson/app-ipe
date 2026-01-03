import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/events_repository.dart';
import '../../models/event.dart';
import '../../models/event_template.dart';
import '../../../../shared/utils/app_toast.dart';

class EventFormSheet extends StatefulWidget {
  const EventFormSheet({super.key, this.event});

  final EventModel? event;

  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _startController = TextEditingController(text: '19:30');
  final _dateController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  late DateTime _selectedDate;
  bool _isSubmitting = false;
  List<EventTemplateModel> _templates = const [];
  String? _selectedTemplateId;
  bool _isLoadingTemplates = true;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _selectedDate = event?.date ?? DateTime.now();
    if (event != null) {
      _nameController.text = event.name;
      _startController.text = event.start.isEmpty ? '19:30' : event.start;
    }
    _dateController.text = _dateFormat.format(_selectedDate);
    _loadTemplates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event == null ? 'Novo evento' : 'Editar evento';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
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
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Nome do evento',
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
                decoration: const InputDecoration(
                  labelText: 'Data',
                  hintText: 'Selecione a data',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _isSubmitting ? null : _selectDate,
                validator: (_) {
                  if (_selectedDate.isBefore(
                    DateTime.now().subtract(const Duration(days: 1)),
                  )) {
                    return 'Escolha uma data futura';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isSubmitting ? null : _selectTime,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _startController,
                    decoration: const InputDecoration(
                      labelText: 'Horário de início',
                      suffixIcon: Icon(Icons.schedule),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe o horário';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              if (widget.event == null) ...[
                const SizedBox(height: 16),
                _isLoadingTemplates
                    ? const SizedBox(
                        height: 56,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : DropdownButtonFormField<String?>(
                        value: _selectedTemplateId,
                        decoration: const InputDecoration(
                          labelText: 'Template (opcional)',
                          hintText: 'Selecione um template',
                          suffixIcon: Icon(Icons.description),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Nenhum template'),
                          ),
                          ..._templates.map((template) {
                            return DropdownMenuItem<String?>(
                              value: template.id,
                              child: Text(template.name),
                            );
                          }),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedTemplateId = value;
                                });
                              },
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
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 0)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _dateFormat.format(picked);
      });
    }
  }

  TimeOfDay _parseTimeFromInput() {
    final timeText = _startController.text.trim();
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
    // Retorna 19:30 como padrão se não conseguir fazer parse
    return const TimeOfDay(hour: 19, minute: 30);
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
      _startController.text = formatted;
    }
  }

  Future<void> _loadTemplates() async {
    if (widget.event != null) return; // Não carregar templates ao editar
    
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
      // Não mostrar erro ao usuário - apenas não mostrar templates
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final repository = context.read<EventsRepository>();
      if (widget.event == null) {
        await repository.createEvent(
          name: _nameController.text.trim(),
          date: _selectedDate,
          start: _startController.text.trim(),
          templateId: _selectedTemplateId,
        );
        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessToast(context, 'Evento criado com sucesso!');
        }
      } else {
        await repository.updateEvent(
          id: widget.event!.id,
          name: _nameController.text.trim(),
          date: _selectedDate,
          start: _startController.text.trim(),
        );
        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessToast(context, 'Evento atualizado com sucesso!');
        }
      }
    } catch (error) {
      if (mounted) {
        showErrorToast(context, 'Erro ao salvar evento. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
