import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/utils/app_toast.dart';
import '../../../../shared/utils/platform_utils.dart';
import '../../data/events_repository.dart';
import '../../models/event_template.dart';

class BatchEventCreatorSheet extends StatefulWidget {
  const BatchEventCreatorSheet({
    super.key,
    required this.currentMonth,
  });

  final DateTime currentMonth;

  @override
  State<BatchEventCreatorSheet> createState() => _BatchEventCreatorSheetState();
}

class _BatchEventCreatorSheetState extends State<BatchEventCreatorSheet> {
  List<EventTemplateModel> _templates = const [];
  String? _selectedTemplateId;
  bool _isLoadingTemplates = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final repository = context.read<EventsRepository>();
      final templates = await repository.fetchAllTemplates();
      setState(() {
        _templates = templates
            .where((template) => template.name != 'Culto de Ceia')
            .toList();
        _isLoadingTemplates = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTemplates = false;
      });
    }
  }

  List<DateTime> _getSundaysInMonth(DateTime month) {
    // Normalizar para o primeiro dia do mês (garantir que usa o mês correto)
    final monthStart = DateTime(month.year, month.month, 1);
    final sundays = <DateTime>[];

    // Encontrar o primeiro domingo do mês
    // weekday: 1=segunda, 2=terça, ..., 7=domingo
    // Se o primeiro dia já é domingo, offset = 0
    // Caso contrário: offset = 7 - weekday (dias até o próximo domingo)
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

  List<DateTime> _getWednesdaysInMonth(DateTime month) {
    // Normalizar para o primeiro dia do mês (garantir que usa o mês correto)
    final monthStart = DateTime(month.year, month.month, 1);
    final wednesdays = <DateTime>[];

    // Encontrar a primeira quarta-feira do mês
    // weekday: 1=segunda, 2=terça, 3=quarta, ..., 7=domingo
    // Se o primeiro dia já é quarta, offset = 0
    // Caso contrário: calcular dias até a próxima quarta
    int firstWednesdayOffset = 3 - monthStart.weekday;
    if (firstWednesdayOffset < 0) {
      // Se já passou da quarta, ir para a próxima semana
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

  Future<void> _createBatchEvents() async {
    if (_selectedTemplateId == null) {
      showErrorToast(context, 'Selecione um template para continuar.');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final repository = context.read<EventsRepository>();
      final selectedTemplate = _templates.firstWhere(
        (t) => t.id == _selectedTemplateId,
      );

      final month = widget.currentMonth;
      List<DateTime> dates = [];
      String time = '';
      String? templateIdForFirst = _selectedTemplateId;

      switch (selectedTemplate.name) {
        case 'Culto à noite':
          dates = _getSundaysInMonth(month);
          time = '19:30';
          // Buscar o ID do template "Culto de Ceia" para o primeiro domingo
          templateIdForFirst = await _findTemplateIdByName('Culto de Ceia');
          // Se não encontrar o template "Culto de Ceia", usar o template padrão
          if (templateIdForFirst == null) {
            templateIdForFirst = _selectedTemplateId;
          }
          break;
        case 'Reunião de Oração':
          dates = _getWednesdaysInMonth(month);
          time = '19:30';
          break;
        case 'Escola Bíblica':
          dates = _getSundaysInMonth(month);
          time = '10:00';
          break;
        default:
          showErrorToast(context, 'Template não suportado para criação em lote.');
          setState(() => _isCreating = false);
          return;
      }

      int created = 0;
      int skipped = 0;

      for (int i = 0; i < dates.length; i++) {
        final date = dates[i];
        final isFirstSunday = i == 0 && selectedTemplate.name == 'Culto à noite';
        final templateId = isFirstSunday ? templateIdForFirst : _selectedTemplateId;
        final eventName = isFirstSunday ? 'Culto de Ceia' : selectedTemplate.name;

        try {
          await repository.createEvent(
            name: eventName,
            date: date,
            start: time,
            templateId: templateId,
          );
          created++;
        } catch (e) {
          skipped++;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        if (created > 0) {
          showSuccessToast(
            context,
            '$created evento(s) criado(s) com sucesso${skipped > 0 ? " ($skipped ignorado(s))" : ""}!',
          );
        } else {
          showErrorToast(context, 'Nenhum evento foi criado.');
        }
      }
    } catch (error) {
      if (mounted) {
        showErrorToast(
          context,
          'Erro ao criar eventos em lote: ${error.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final androidBottomPadding = PlatformUtils.getModalBottomPadding(context);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: mediaQuery.viewInsets.bottom + androidBottomPadding,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              'Criar eventos em lote',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecione um template para criar eventos automaticamente para o mês atual.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            _isLoadingTemplates
                ? const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : DropdownButtonFormField<String?>(
                    value: _selectedTemplateId,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Template',
                      labelStyle: TextStyle(color: Colors.white70),
                      suffixIcon: Icon(Icons.description, color: Colors.white70),
                    ),
                    dropdownColor: const Color(0xFF1A1F2E),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Selecione um template'),
                      ),
                      ..._templates.map((template) {
                        return DropdownMenuItem<String?>(
                          value: template.id,
                          child: Text(template.name),
                        );
                      }),
                    ],
                    onChanged: _isCreating
                        ? null
                        : (value) {
                            setState(() {
                              _selectedTemplateId = value;
                            });
                          },
                  ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_isCreating || _selectedTemplateId == null)
                    ? null
                    : _createBatchEvents,
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar eventos'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
