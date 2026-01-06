import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/utils/app_toast.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/events_repository.dart';
import '../models/event_template.dart';
import 'event_template_editor_page.dart';

class EventTemplatePage extends StatefulWidget {
  const EventTemplatePage({super.key});

  @override
  State<EventTemplatePage> createState() => _EventTemplatePageState();
}

class _EventTemplatePageState extends State<EventTemplatePage> {
  bool _isLoading = true;
  List<EventTemplateModel> _templates = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
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
                      'Templates de Liturgias',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadTemplates,
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
                      : _templates.isEmpty
                      ? ListView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
                          children: const [
                            Icon(
                              Icons.description_outlined,
                              size: 72,
                              color: Colors.white38,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nenhum template encontrado.\nOs templates aparecerão aqui.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                          itemCount: _templates.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final template = _templates[index];
                            return _TemplateCard(
                              template: template,
                              onOpen: () => _openTemplate(template),
                              onEdit: () => _editTemplate(template),
                              onDelete: () => _deleteTemplate(template),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTemplate,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repository = context.read<EventsRepository>();
      List<EventTemplateModel> templates;
      
      try {
        templates = await repository.fetchAllTemplates();
      } catch (e) {
        // Se der erro ao buscar (collection pode não existir), tratar como lista vazia
        templates = const [];
      }

      // Se não houver templates, criar o template padrão
      if (templates.isEmpty) {
        try {
          await repository.createDefaultTemplate();
          // Recarregar após criar
          templates = await repository.fetchAllTemplates();
          setState(() {
            _templates = templates;
          });
        } catch (e) {
          // Se der erro ao criar o template padrão, mostrar erro específico
          setState(() {
            _error = 'Erro ao criar template padrão: ${e.toString()}';
          });
        }
      } else {
        setState(() {
          _templates = templates;
        });
      }
    } catch (error) {
      setState(() {
        _error = 'Erro ao carregar templates de eventos: ${error.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openTemplate(EventTemplateModel template) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventTemplateEditorPage(templateId: template.id),
      ),
    );
    await _loadTemplates();
  }

  Future<void> _editTemplate(EventTemplateModel template) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventTemplateEditorPage(
          templateId: template.id,
          isEditable: true,
        ),
      ),
    );
    await _loadTemplates();
  }

  Future<void> _deleteTemplate(EventTemplateModel template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir template'),
        content: Text(
          'Deseja realmente excluir "${template.name}"? Esta ação não poderá ser desfeita.',
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

    try {
      await context.read<EventsRepository>().deleteTemplate(template.id);
      if (mounted) {
        showSuccessToast(context, 'Template "${template.name}" excluído.');
        await _loadTemplates();
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao excluir template: ${e.toString()}');
      }
    }
  }

  Future<void> _createTemplate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const EventTemplateEditorPage(isEditable: true),
      ),
    );
    await _loadTemplates();
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final EventTemplateModel template;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
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
                Icons.description,
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
                    template.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${template.steps.length} ${template.steps.length == 1 ? 'etapa' : 'etapas'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
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
    );
  }
}

