import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../musics/data/musics_repository.dart';
import '../../musics/models/music.dart';
import '../../people/data/people_repository.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import '../../people/presentation/widgets/people_selector_sheet.dart';
import '../../musics/presentation/widgets/music_selector_sheet.dart';
import '../../musics/presentation/widgets/tone_selector_sheet.dart';
import '../../../shared/utils/app_toast.dart';

class _CustomFABLocation extends FloatingActionButtonLocation {
  final double offset;

  const _CustomFABLocation({this.offset = 16});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX =
        scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        16;
    final double fabY =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        offset;
    return Offset(fabX, fabY);
  }
}

class EventEditorPage extends StatefulWidget {
  const EventEditorPage({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentTabIndex = 0;
  EventModel? _event;
  List<EventStepModel> _steps = const [];
  List<MusicModel> _musics = const [];
  List<UserModel> _people = const [];
  List<String> _selectedPeople = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_currentTabIndex != _tabController.index) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final title = event == null
        ? 'Editar evento'
        : '${event.name} (${DateFormat('dd/MM').format(event.date)})';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Salvar'),
            onPressed: _isSaving ? null : _save,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorColor: const Color(0xFF4CAF50), // Verde mais claro
          labelColor: const Color(
            0xFF4CAF50,
          ), // Verde mais claro para texto selecionado
          unselectedLabelColor: Colors.white,
          tabs: const [
            Tab(text: 'Etapas'),
            Tab(text: 'Equipe'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : event == null
          ? const Center(child: Text('Evento não encontrado.'))
          : TabBarView(
              controller: _tabController,
              children: [_buildStepsTab(), _buildTeamTab()],
            ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: _addStep,
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              onPressed: _manageTeam,
              child: const Icon(Icons.group_add),
            ),
      floatingActionButtonLocation: const _CustomFABLocation(offset: 80),
    );
  }

  Widget _buildStepsTab() {
    if (_steps.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.list_alt, size: 64, color: Colors.white38),
              SizedBox(height: 16),
              Text(
                'Nenhuma etapa adicionada ainda.\nClique no botão abaixo para adicionar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

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
            final double animValue = Curves.easeInOut.transform(
              animation.value,
            );
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
                child: Opacity(opacity: 0.9 + (0.1 * animValue), child: child),
              ),
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final step = _steps[index];
        final isMusic = step.type == EventStepType.music;
        // Usar ObjectKey baseado no objeto step para manter identidade estável
        // Isso permite que o Flutter reconheça corretamente cada item ao reordenar
        return Card(
          key: ObjectKey(step),
          margin: const EdgeInsets.only(bottom: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.drag_handle, color: Colors.white54),
                    const SizedBox(width: 8),
                    Icon(isMusic ? Icons.music_note : Icons.list_alt),
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
                      if (isMusic && step.musicTone != null) ...[
                        const SizedBox(height: 4),
                        Chip(label: Text('Tom: ${step.musicTone}')),
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
  }

  Widget _buildTeamTab() {
    if (_selectedPeople.isEmpty) {
      return const Center(child: Text('Nenhuma pessoa atribuída ao evento.'));
    }
    final team = _people
        .where((user) => _selectedPeople.contains(user.id))
        .toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: team
            .map(
              (user) => InputChip(
                label: Text(user.name),
                avatar: CircleAvatar(
                  child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
                ),
                onDeleted: () => setState(() {
                  _selectedPeople = List.of(_selectedPeople)..remove(user.id);
                }),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final eventsRepository = context.read<EventsRepository>();
      final musicsRepository = context.read<MusicsRepository>();
      final peopleRepository = context.read<PeopleRepository>();

      // Carregar evento primeiro (obrigatório)
      final event = await eventsRepository.fetchById(widget.eventId);

      // Carregar músicas e pessoas de forma independente (não bloqueiam a exibição)
      List<MusicModel> musics = const [];
      List<UserModel> people = const [];

      try {
        musics = await musicsRepository.fetchAll();
      } catch (e) {
        // Não mostrar erro ao usuário - apenas usar lista vazia
      }

      try {
        people = await peopleRepository.fetchAll();
      } catch (e) {
        // Não mostrar erro ao usuário - apenas usar lista vazia
        // A aba Equipe já mostra mensagem apropriada quando não há pessoas
      }

      setState(() {
        _event = event;
        _steps = List.of(event.steps);
        _selectedPeople = List.of(event.peopleIds);
        _musics = musics;
        _people = people;
      });
    } catch (e) {
      setState(() {
        _event = null;
      });
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar evento: ${e.toString()}');
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
      builder: (_) => StepEditorSheet(musics: _musics),
    );
    if (result != null) {
      setState(() => _steps = [..._steps, result]);
    }
  }

  Future<void> _editStep(int index) async {
    final result = await showModalBottomSheet<EventStepModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          StepEditorSheet(musics: _musics, initialStep: _steps[index]),
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

  Future<void> _manageTeam() async {
    // Recarregar usuários da collection users antes de abrir a modal
    try {
      final peopleRepository = context.read<PeopleRepository>();
      final people = await peopleRepository.fetchAll();
      setState(() {
        _people = people;
      });
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar usuários: ${e.toString()}');
      }
      return;
    }

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          PeopleSelectorSheet(people: _people, selectedIds: _selectedPeople),
    );
    if (result != null) {
      setState(() => _selectedPeople = result);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<EventsRepository>().updateEventDetails(
        id: widget.eventId,
        steps: _steps,
        peopleIds: _selectedPeople,
      );
      if (!mounted) return;
      showSuccessToast(context, 'Evento atualizado com sucesso!');
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class StepEditorSheet extends StatefulWidget {
  const StepEditorSheet({super.key, required this.musics, this.initialStep});

  final List<MusicModel> musics;
  final EventStepModel? initialStep;

  @override
  State<StepEditorSheet> createState() => _StepEditorSheetState();
}

class _StepEditorSheetState extends State<StepEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedMusicId;
  String? _musicTone;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStep;
    _type = initial?.type == EventStepType.music ? 'music' : 'step';
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _selectedMusicId = initial?.musicId;
    _musicTone = initial?.musicTone ?? '0';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                widget.initialStep == null ? 'Adicionar item' : 'Editar item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: const [
                  DropdownMenuItem(value: 'step', child: Text('Etapa')),
                  DropdownMenuItem(value: 'music', child: Text('Música')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
                decoration: const InputDecoration(labelText: 'Tipo'),
              ),
              if (_type == 'music') ...[
                const SizedBox(height: 16),
                MusicSelectorField(
                  musics: widget.musics,
                  selectedId: _selectedMusicId,
                  onSelect: (music) {
                    setState(() {
                      _selectedMusicId = music.id;
                      _titleController.text = music.title;
                      _musicTone = music.tone;
                    });
                  },
                ),
                const SizedBox(height: 16),
                ToneSelectorSheet(
                  selectedTone: _musicTone,
                  onToneSelected: (tone) => setState(() => _musicTone = tone),
                ),
              ] else ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Título da etapa ou música',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe o título';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Detalhes adicionais',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Salvar'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    EventStepModel step;
    if (_type == 'music') {
      final musicId = _selectedMusicId;
      if (musicId == null) {
        showErrorToast(context, 'Selecione uma música.');
        return;
      }
      // Quando for música, o título já foi preenchido automaticamente da música selecionada
      // e não usamos descrição
      step = EventStepModel(
        title: _titleController.text.trim(),
        description: '', // Descrição não é usada para músicas
        type: EventStepType.music,
        musicId: musicId,
        musicTone: _musicTone ?? '0',
      );
    } else {
      step = EventStepModel(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: EventStepType.step,
      );
    }
    Navigator.of(context).pop(step);
  }
}
