import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/utils/app_toast.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import '../models/event_template.dart';
import 'widgets/step_editor_sheet.dart';

class EventTemplateEditorPage extends StatefulWidget {
  const EventTemplateEditorPage({
    super.key,
    this.templateId,
    this.isEditable = false,
    this.sourceTemplate,
  });

  final String? templateId;
  final bool isEditable;
  final EventTemplateModel? sourceTemplate;

  @override
  State<EventTemplateEditorPage> createState() =>
      _EventTemplateEditorPageState();
}

class _EventTemplateEditorPageState extends State<EventTemplateEditorPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  EventTemplateModel? _template;
  List<EventStepModel> _steps = const [];
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _template == null
        ? widget.templateId == null
            ? 'Novo Template'
            : 'Carregando...'
        : widget.isEditable
            ? 'Editar Template'
            : _template!.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: widget.isEditable
            ? [
                TextButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar'),
                  onPressed: _isSaving ? null : _save,
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _template == null && widget.templateId != null
          ? const Center(child: Text('Template não encontrado.'))
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  if (widget.isEditable) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Template',
                          hintText: 'Ex: Template Padrão',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o nome do template';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                  Expanded(
                    child: _buildStepsList(),
                  ),
                ],
              ),
            ),
      floatingActionButton: widget.isEditable
          ? FloatingActionButton(
              onPressed: _addStep,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildStepsList() {
    if (_steps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.list_alt, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              Text(
                widget.isEditable
                    ? 'Nenhuma etapa adicionada ainda.\nClique no botão abaixo para adicionar.'
                    : 'Nenhuma etapa neste template.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isEditable) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _steps.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _steps.removeAt(oldIndex);
            _steps.insert(newIndex, item);
          });
        },
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              final double animValue =
                  Curves.easeInOut.transform(animation.value);
              final double elevation = 0 + (8 - 0) * animValue;
              final double scale = 1.0 + (0.05 * animValue);
              final double rotation = 0.02 * animValue;
              return Transform(
                transform: Matrix4.identity()
                  ..scale(scale)
                  ..rotateZ(rotation),
                alignment: Alignment.center,
                child: Material(
                  elevation: elevation,
                  color: Colors.transparent,
                  shadowColor: Colors.black,
                  child: Opacity(
                      opacity: 0.9 + (0.1 * animValue), child: child),
                ),
              );
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final step = _steps[index];
          return Card(
            key: ObjectKey(step),
            margin: const EdgeInsets.only(bottom: 4),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.drag_handle, color: Colors.white54),
                      const SizedBox(width: 8),
                      const Icon(Icons.list_alt),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          step.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (step.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            step.description!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editStep(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _removeStep(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Modo visualização
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _steps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final step = _steps[index];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.list_alt),
              ),
              title: Text(step.title),
              subtitle: step.description?.isNotEmpty == true
                  ? Text(step.description!)
                  : null,
            ),
          );
        },
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repository = context.read<EventsRepository>();

      if (widget.templateId != null) {
        final template = await repository.fetchTemplateById(widget.templateId!);
        setState(() {
          _template = template;
          _steps = List.of(template.steps);
          _nameController.text = template.name;
        });
      } else if (widget.sourceTemplate != null) {
        // Clone de um template existente
        setState(() {
          _template = null; // Tratado como novo
          _steps = List.of(widget.sourceTemplate!.steps);
          _nameController.text = '${widget.sourceTemplate!.name} (clone)';
        });
      } else {
        // Novo template
        setState(() {
          _template = null;
          _steps = const [];
          _nameController.text = '';
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar template: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addStep() async {
    final result = await showModalBottomSheet<EventStepModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StepEditorSheet(
        musics: const [],
        isTemplateMode: true, // Apenas etapas, sem músicas
      ),
    );
    if (result != null) {
      setState(() {
        _steps = [..._steps, result];
      });
    }
  }

  Future<void> _editStep(int index) async {
    final result = await showModalBottomSheet<EventStepModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StepEditorSheet(
        musics: const [],
        initialStep: _steps[index],
        isTemplateMode: true, // Apenas etapas, sem músicas
      ),
    );
    if (result != null) {
      setState(() {
        final updated = List<EventStepModel>.of(_steps);
        updated[index] = result;
        _steps = updated;
      });
    }
  }

  void _removeStep(int index) {
    setState(() {
      _steps = List.of(_steps)..removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repository = context.read<EventsRepository>();
      final name = _nameController.text.trim();

      if (widget.templateId != null) {
        // Atualizar template existente
        await repository.updateTemplate(
          id: widget.templateId!,
          name: name,
          steps: _steps,
        );
        if (!mounted) return;
        showSuccessToast(context, 'Template atualizado com sucesso!');
      } else {
        // Criar novo template
        await repository.createTemplate(
          name: name,
          steps: _steps,
        );
        if (!mounted) return;
        showSuccessToast(context, 'Template criado com sucesso!');
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao salvar template: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

