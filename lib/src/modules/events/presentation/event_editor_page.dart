import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../musics/data/musics_repository.dart';
import '../../musics/models/music.dart';
import '../../people/data/people_repository.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import '../models/event_template.dart';
import '../../people/presentation/widgets/people_selector_sheet.dart';
import '../../societies/data/societies_repository.dart';
import '../../societies/models/society.dart';
import '../../../shared/utils/app_toast.dart';
import 'widgets/step_editor_sheet.dart';

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
  int _currentTabIndex = 0;
  EventModel? _event;
  List<EventStepModel> _steps = const [];
  List<MusicModel> _musics = const [];
  List<UserModel> _people = const [];
  EventPeople _selectedPeople = const EventPeople();
  EventTeams _selectedTeams = const EventTeams();
  List<SocietyModel> _societies = const [];
  EventTemplateModel? _template;

  /// Compara apenas a data (sem hora) de dois DateTime
  bool _isDateBeforeToday(DateTime date) {
    final now = DateTime.now();
    final eventDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return eventDate.isBefore(today);
  }

  bool get _isPastEvent => _event != null && _isDateBeforeToday(_event!.date);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        actions: [],
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
            Tab(text: 'Pessoas'),
            Tab(text: 'Equipes'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : event == null
          ? const Center(child: Text('Evento não encontrado.'))
          : TabBarView(
              controller: _tabController,
              children: [_buildStepsTab(), _buildTeamTab(), _buildTeamsTab()],
            ),
      floatingActionButton: _isPastEvent
          ? null
          : (_currentTabIndex == 0
              ? FloatingActionButton(
                  onPressed: _addStep,
                  child: const Icon(Icons.add),
                )
              : _currentTabIndex == 1
                  ? FloatingActionButton(
                      onPressed: _manageTeam,
                      child: const Icon(Icons.group_add),
                    )
                  : null),
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
      onReorder: _isPastEvent
          ? (oldIndex, newIndex) {
              // Não permitir reordenação em eventos passados
            }
          : (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _steps.removeAt(oldIndex);
                _steps.insert(newIndex, item);
              });
              _autoSave();
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
                      onPressed: _isPastEvent ? null : () => _editStep(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      color: _isPastEvent ? Colors.white38 : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: _isPastEvent ? null : () => _removeStep(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      color: _isPastEvent ? Colors.white38 : null,
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
    final allPeopleIds = _selectedPeople.allPeopleIds;
    if (allPeopleIds.isEmpty) {
      return const Center(child: Text('Nenhuma pessoa atribuída ao evento.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedPeople.elo.isNotEmpty || _selectedPeople.eloWithInstruments.isNotEmpty) ...[
            _buildEloSection(),
            const SizedBox(height: 24),
          ],
          if (_selectedPeople.soundImage.isNotEmpty) ...[
            _buildPeopleSection('Som e Imagem', _selectedPeople.soundImage, 'soundImage'),
            const SizedBox(height: 24),
          ],
          if (_selectedPeople.diaconia.isNotEmpty) ...[
            _buildPeopleSection('Diaconia', _selectedPeople.diaconia, 'diaconia'),
            const SizedBox(height: 24),
          ],
          if (_selectedPeople.lead.isNotEmpty || _selectedPeople.preacher.isNotEmpty) ...[
            _buildLeadAndPreacherSection(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildLeadAndPreacherSection() {
    final leadChips = _selectedPeople.lead.map((userId) {
      final user = _people.firstWhere(
        (u) => u.id == userId,
        orElse: () => UserModel(
          id: userId,
          name: 'Usuário desconhecido',
          email: '',
          isAdmin: false,
          isPending: false,
        ),
      );
      return _buildPersonChip(
        user: user,
        onDeleted: _isPastEvent
            ? null
            : () => _removePerson(user.id, 'lead'),
      );
    }).toList();
    
    final preacherChips = _selectedPeople.preacher.map((userId) {
      final user = _people.firstWhere(
        (u) => u.id == userId,
        orElse: () => UserModel(
          id: userId,
          name: 'Usuário desconhecido',
          email: '',
          isAdmin: false,
          isPending: false,
        ),
      );
      return _buildPersonChip(
        user: user,
        onDeleted: _isPastEvent
            ? null
            : () => _removePerson(user.id, 'preacher'),
      );
    }).toList();
    
    final allChips = [...leadChips, ...preacherChips];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedPeople.lead.isNotEmpty && _selectedPeople.preacher.isNotEmpty) ...[
          Text(
            'Dirigente e Pregador',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
          ),
        ] else if (_selectedPeople.lead.isNotEmpty) ...[
          Text(
            'Dirigente',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
          ),
        ] else ...[
          Text(
            'Pregador',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
          ),
        ],
        const SizedBox(height: 12),
        _buildTwoColumnGrid(allChips),
      ],
    );
  }

  Widget _buildEloSection() {
    // Agrupar pessoas por instrumento
    final instrumentGroups = <String, List<MapEntry<String, bool>>>{};
    
    // Adicionar pessoas com instrumentos
    _selectedPeople.eloWithInstruments.forEach((userId, instruments) {
      instruments.forEach((instrument, talkBack) {
        instrumentGroups.putIfAbsent(instrument, () => []).add(
          MapEntry(userId, talkBack),
        );
      });
    });
    
    // Adicionar pessoas sem instrumento específico (elo antigo)
    for (final userId in _selectedPeople.elo) {
      if (!_selectedPeople.eloWithInstruments.containsKey(userId)) {
        instrumentGroups.putIfAbsent('Geral', () => []).add(
          MapEntry(userId, false),
        );
      }
    }
    
    // Coletar todas as pessoas para exibir em duas colunas
    final allPeople = <Widget>[];
    instrumentGroups.forEach((instrument, people) {
      for (final personEntry in people) {
        final userId = personEntry.key;
        final talkBack = personEntry.value;
        final user = _people.firstWhere(
          (u) => u.id == userId,
          orElse: () => UserModel(
            id: userId,
            name: 'Usuário desconhecido',
            email: '',
            isAdmin: false,
            isPending: false,
          ),
        );
        
        allPeople.add(_buildPersonChip(
          user: user,
          talkBack: talkBack,
          instrument: instrument != 'Geral' ? instrument : null,
          onDeleted: _isPastEvent
              ? null
              : () => _removePerson(user.id, 'elo', instrument),
        ));
      }
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Equipe de Louvor',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
        ),
        const SizedBox(height: 12),
        _buildTwoColumnGrid(allPeople),
      ],
    );
  }
  
  Widget _buildPersonChip({
    required UserModel user,
    bool talkBack = false,
    String? instrument,
    VoidCallback? onDeleted,
  }) {
    return InputChip(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: instrument != null ? 6 : 8,
      ),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (instrument != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getInstrumentIcon(instrument),
                  size: 13,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    instrument,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  user.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (talkBack) ...[
                const SizedBox(width: 4),
                Icon(Icons.mic, size: 14),
              ],
            ],
          ),
        ],
      ),
      onDeleted: onDeleted,
    );
  }
  
  IconData _getInstrumentIcon(String instrument) {
    switch (instrument) {
      case 'Violão':
        return Icons.music_note;
      case 'Baixo':
        return Icons.music_note;
      case 'Guitarra':
        return Icons.music_note;
      case 'Teclado':
        return Icons.piano;
      case 'Bateria':
        return Icons.radio;
      case 'Ministrante':
        return Icons.mic;
      case 'Backing':
        return Icons.people;
      default:
        return Icons.music_note;
    }
  }
  
  Widget _buildTwoColumnGrid(List<Widget> chips) {
    if (chips.isEmpty) return const SizedBox.shrink();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / 2;
        
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((chip) => SizedBox(
            width: itemWidth,
            child: chip,
          )).toList(),
        );
      },
    );
  }

  Widget _buildPeopleSection(String title, List<String> peopleIds, String type) {
    final people = _people.where((user) => peopleIds.contains(user.id)).toList();
    
    final chips = people.map((user) => _buildPersonChip(
      user: user,
      onDeleted: _isPastEvent
          ? null
          : () => _removePerson(user.id, type),
    )).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
        ),
        const SizedBox(height: 12),
        _buildTwoColumnGrid(chips),
      ],
    );
  }

  void _removePerson(String userId, String type, [String? instrument]) {
    setState(() {
      switch (type) {
        case 'elo':
          if (instrument != null && _selectedPeople.eloWithInstruments.containsKey(userId)) {
            // Remover instrumento específico
            final updatedInstruments = Map<String, Map<String, bool>>.from(
              _selectedPeople.eloWithInstruments,
            );
            final userInstruments = Map<String, bool>.from(
              updatedInstruments[userId] ?? {},
            );
            userInstruments.remove(instrument);
            
            if (userInstruments.isEmpty) {
              updatedInstruments.remove(userId);
            } else {
              updatedInstruments[userId] = userInstruments;
            }
            
            _selectedPeople = _selectedPeople.copyWith(
              eloWithInstruments: updatedInstruments,
            );
          } else {
            // Remover da lista elo antiga
            _selectedPeople = _selectedPeople.copyWith(
              elo: List.of(_selectedPeople.elo)..remove(userId),
            );
          }
          break;
        case 'soundImage':
          _selectedPeople = _selectedPeople.copyWith(
            soundImage: List.of(_selectedPeople.soundImage)..remove(userId),
          );
          break;
        case 'preacher':
          _selectedPeople = _selectedPeople.copyWith(
            preacher: List.of(_selectedPeople.preacher)..remove(userId),
          );
          break;
        case 'lead':
          _selectedPeople = _selectedPeople.copyWith(
            lead: List.of(_selectedPeople.lead)..remove(userId),
          );
          break;
        case 'diaconia':
          _selectedPeople = _selectedPeople.copyWith(
            diaconia: List.of(_selectedPeople.diaconia)..remove(userId),
          );
          break;
      }
    });
    _autoSave();
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
        // A aba Pessoas já mostra mensagem apropriada quando não há pessoas
      }

      // Carregar sociedades
      List<SocietyModel> societies = const [];
      try {
        final societiesRepository = context.read<SocietiesRepository>();
        societies = await societiesRepository.fetchAll();
      } catch (e) {
        // Não mostrar erro ao usuário - apenas usar lista vazia
      }

      // Carregar template se houver templateId
      EventTemplateModel? template;
      if (event.templateId != null && event.templateId!.isNotEmpty) {
        try {
          template = await eventsRepository.fetchTemplateById(event.templateId!);
        } catch (e) {
          // Se não conseguir carregar o template, continua sem ele
        }
      }

      setState(() {
        _event = event;
        _steps = List.of(event.steps);
        _selectedPeople = event.people;
        _selectedTeams = event.teams;
        _musics = musics;
        _people = people;
        _societies = societies;
        _template = template;
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
      if (result.type == EventStepType.music &&
          result.musicId != null &&
          _event != null) {
        context
            .read<MusicsRepository>()
            .addEventDate(result.musicId!, _event!.date);
      }
      _autoSave();
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
      _autoSave();
    }
  }

  void _removeStep(int index) {
    final step = _steps[index];
    if (step.type == EventStepType.music &&
        step.musicId != null &&
        _event != null) {
      context
          .read<MusicsRepository>()
          .removeEventDate(step.musicId!, _event!.date);
    }
    setState(() {
      _steps = List.of(_steps)..removeAt(index);
    });
    _autoSave();
  }

  Future<void> _manageTeam() async {
    // Recarregar usuários
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

    String? currentStep = 'type_selector';
    String? selectedType; // 'elo', 'soundImage', 'pregador', 'dirigente'
    String? selectedInstrument; // Apenas se selectedType == 'elo'

    // Loop de navegação
    while (currentStep != null) {
      if (currentStep == 'type_selector') {
        final result = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _PeopleTypeSelectorSheet(),
        );

        if (result == null) break;
        selectedType = result;

        if (selectedType == 'elo') {
          currentStep = 'instrument_selector';
        } else {
          currentStep = 'people_selector';
        }
      } else if (currentStep == 'instrument_selector') {
        // Modal de Instrumentos (ELO)
        final result = await showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _InstrumentSelectorSheet(),
        );

        if (result == null) break;
        if (result == 'BACK') {
          currentStep = 'type_selector';
          continue;
        }

        selectedInstrument = result as String;
        currentStep = 'people_selector_elo';
      } else if (currentStep == 'people_selector' ||
          currentStep == 'people_selector_elo') {
        // Preparar dados
        List<String> currentSelectedIds = [];
        bool filterByELO = false;
        String? filterBySociety;
        String? title;
        bool canGoBack = true;
        String? instrumentParam;
        bool showTalkBack = false;

        if (currentStep == 'people_selector_elo') {
          // Configuração para ELO
          title = 'Membros de Equipe de Louvor';
          filterByELO = true;
          instrumentParam = selectedInstrument;
          showTalkBack = selectedInstrument != 'Ministrante' &&
              selectedInstrument != 'Backing';

          // IDs selecionados para este instrumento
          _selectedPeople.eloWithInstruments.forEach((userId, instruments) {
            if (instruments.containsKey(selectedInstrument)) {
              currentSelectedIds.add(userId);
            }
          });
        } else {
          // Configuração para outros
          switch (selectedType) {
            case 'pregador':
              currentSelectedIds = _selectedPeople.preacher;
              title = 'Membros da IPE';
              // canGoBack = true; // Pode voltar para o menu principal
              break;
            case 'dirigente':
              currentSelectedIds = _selectedPeople.lead;
              title = 'Membros da IPE';
              break;
            case 'soundImage':
              filterBySociety = 'Som e Imagem';
              currentSelectedIds = _selectedPeople.soundImage;
              title = 'Membros de Som e Imagem';
              break;
            case 'diaconia':
              filterBySociety = 'DIAC';
              currentSelectedIds = _selectedPeople.diaconia;
              title = 'Membros de Diaconia';
              break;
          }
        }

        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => PeopleSelectorSheet(
            people: _people,
            selectedIds: currentSelectedIds,
            eventDate: _event?.date,
            filterByELO: filterByELO,
            filterBySociety: filterBySociety,
            title: title,
            canGoBack: canGoBack,
            instrument: instrumentParam,
            showTalkBack: showTalkBack,
          ),
        );

        if (result == null) break;
        if (result == 'BACK') {
          if (currentStep == 'people_selector_elo') {
            currentStep = 'instrument_selector';
          } else {
            currentStep = 'type_selector';
          }
          continue;
        }

        // Processar resultado
        setState(() {
          if (currentStep == 'people_selector_elo') {
            final updatedInstruments = Map<String, Map<String, bool>>.from(
              _selectedPeople.eloWithInstruments,
            );

            if (result is Map<String, Map<String, bool>>) {
              result.forEach((userId, instruments) {
                updatedInstruments[userId] = {
                  ...updatedInstruments[userId] ?? {},
                  ...instruments,
                };
              });
            } else if (result is List<String>) {
              // Fallback
              for (final userId in result) {
                updatedInstruments[userId] = {
                  ...updatedInstruments[userId] ?? {},
                  selectedInstrument!: false,
                };
              }
            }
            _selectedPeople = _selectedPeople.copyWith(
              eloWithInstruments: updatedInstruments,
            );
          } else {
             // Outros tipos retornam List<String>
             final ids = result as List<String>;
             switch (selectedType) {
              case 'pregador':
                _selectedPeople = _selectedPeople.copyWith(preacher: ids);
                break;
              case 'dirigente':
                _selectedPeople = _selectedPeople.copyWith(lead: ids);
                break;
              case 'soundImage':
                _selectedPeople = _selectedPeople.copyWith(soundImage: ids);
                break;
              case 'diaconia':
                _selectedPeople = _selectedPeople.copyWith(diaconia: ids);
                break;
            }
          }
        });
        _autoSave();

        // Após salvar, fecha o fluxo (ou poderia voltar para o menu anterior? Geralmente salvar fecha tudo)
        break;
      }
    }
  }

  Future<void> _autoSave() async {
    if (_isPastEvent) return;

    try {
      await context.read<EventsRepository>().updateEventDetails(
        id: widget.eventId,
        steps: _steps,
        people: _selectedPeople,
        teams: _selectedTeams,
      );
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao salvar alterações: ${e.toString()}');
      }
    }
  }

  Widget _buildTeamsTab() {
    final templateName = _template?.name ?? '';
    
    // Determinar quais itens mostrar baseado no template
    final shouldShowLiturgia = _shouldShowLiturgia(templateName);
    final shouldShowLanche = _shouldShowLanche(templateName);
    final shouldShowAberturaEbd = _shouldShowAberturaEbd(templateName);
    final shouldShowReuniaoOracao = _shouldShowReuniaoOracao(templateName);
    
    final items = <Widget>[];
    
    if (shouldShowLiturgia) {
      items.add(_buildTeamResponsibilityCard(
        title: 'Montar liturgia',
        icon: Icons.menu_book,
        societyId: _selectedTeams.liturgia,
      ));
      if (shouldShowLanche || shouldShowAberturaEbd || shouldShowReuniaoOracao) {
        items.add(const SizedBox(height: 16));
      }
    }
    
    if (shouldShowLanche) {
      items.add(_buildTeamResponsibilityCard(
        title: 'Lanche pós-culto',
        icon: Icons.restaurant,
        societyId: _selectedTeams.lanche,
      ));
      if (shouldShowAberturaEbd || shouldShowReuniaoOracao) {
        items.add(const SizedBox(height: 16));
      }
    }
    
    if (shouldShowAberturaEbd) {
      items.add(_buildTeamResponsibilityCard(
        title: 'Abertura EBD',
        icon: Icons.school,
        societyId: _selectedTeams.aberturaEbd,
      ));
      if (shouldShowReuniaoOracao) {
        items.add(const SizedBox(height: 16));
      }
    }
    
    if (shouldShowReuniaoOracao) {
      items.add(_buildTeamResponsibilityCard(
        title: 'Reunião de oração',
        icon: Icons.favorite,
        societyId: _selectedTeams.reuniaoOracao,
      ));
    }
    
    if (items.isEmpty) {
      return const Center(child: Text('Nenhuma equipe atribuída para este tipo de evento.'));
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  bool _shouldShowLiturgia(String templateName) {
    final name = templateName.toLowerCase();
    return name.contains('culto à noite') || 
           name.contains('culto de ceia');
  }

  bool _shouldShowLanche(String templateName) {
    final name = templateName.toLowerCase();
    return name.contains('culto à noite') || 
           name.contains('culto de ceia');
  }

  bool _shouldShowAberturaEbd(String templateName) {
    final name = templateName.toLowerCase();
    return name.contains('escola bíblica') || 
           name.contains('escola biblica');
  }

  bool _shouldShowReuniaoOracao(String templateName) {
    final name = templateName.toLowerCase();
    return name.contains('reunião de oração') || 
           name.contains('reuniao de oracao');
  }

  Widget _buildTeamResponsibilityCard({
    required String title,
    required IconData icon,
    String? societyId,
  }) {
    final society = societyId != null
        ? _societies.firstWhere(
            (s) => s.id == societyId,
            orElse: () => SocietyModel(
              id: '',
              name: 'Sociedade não encontrada',
              description: '',
              color: 0xFF2F4F2F,
              userId: '',
            ),
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  if (society != null)
                    Text(
                      society.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    )
                  else
                    Text(
                      'Nenhuma sociedade atribuída',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white54,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectSocietyForResponsibility(String responsibility) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SocietySelectorSheet(
        societies: _societies,
        currentSocietyId: _getCurrentSocietyId(responsibility),
      ),
    );

    if (result == null) return;

    setState(() {
      switch (responsibility) {
        case 'liturgia':
          _selectedTeams = _selectedTeams.copyWith(
            liturgia: result.isEmpty ? null : result,
          );
          break;
        case 'lanche':
          _selectedTeams = _selectedTeams.copyWith(
            lanche: result.isEmpty ? null : result,
          );
          break;
        case 'aberturaEbd':
          _selectedTeams = _selectedTeams.copyWith(
            aberturaEbd: result.isEmpty ? null : result,
          );
          break;
        case 'reuniaoOracao':
          _selectedTeams = _selectedTeams.copyWith(
            reuniaoOracao: result.isEmpty ? null : result,
          );
          break;
      }
    });
    _autoSave();
  }

  String? _getCurrentSocietyId(String responsibility) {
    switch (responsibility) {
      case 'liturgia':
        return _selectedTeams.liturgia;
      case 'lanche':
        return _selectedTeams.lanche;
      case 'aberturaEbd':
        return _selectedTeams.aberturaEbd;
      case 'reuniaoOracao':
        return _selectedTeams.reuniaoOracao;
      default:
        return null;
    }
  }

}

class _PeopleTypeSelectorSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Adicionar pessoa',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _OptionTile(
                          icon: Icons.music_note,
                          title: 'Equipe de louvor',
                          onTap: () => Navigator.of(context).pop('elo'),
                        ),
                        const SizedBox(height: 12),
                        _OptionTile(
                          icon: Icons.video_library,
                          title: 'Som e imagem',
                          onTap: () => Navigator.of(context).pop('soundImage'),
                        ),
                        const SizedBox(height: 12),
                        _OptionTile(
                          icon: Icons.volunteer_activism,
                          title: 'Diaconia',
                          onTap: () => Navigator.of(context).pop('diaconia'),
                        ),
                        const SizedBox(height: 12),
                        _OptionTile(
                          icon: Icons.mic,
                          title: 'Pregador',
                          onTap: () => Navigator.of(context).pop('pregador'),
                        ),
                        const SizedBox(height: 12),
                        _OptionTile(
                          icon: Icons.person,
                          title: 'Dirigente',
                          onTap: () => Navigator.of(context).pop('dirigente'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}

class _InstrumentSelectorSheet extends StatelessWidget {
  static const List<String> instruments = [
    'Violão',
    'Baixo',
    'Guitarra',
    'Teclado',
    'Bateria',
    'Ministrante',
    'Backing',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop('BACK'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Selecionar instrumento',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    ...instruments.map((instrument) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OptionTile(
                            icon: _getInstrumentIcon(instrument),
                            title: instrument,
                            onTap: () => Navigator.of(context).pop(instrument),
                          ),
                        )),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getInstrumentIcon(String instrument) {
    switch (instrument) {
      case 'Violão':
        return Icons.music_note;
      case 'Baixo':
        return Icons.music_note;
      case 'Guitarra':
        return Icons.music_note;
      case 'Teclado':
        return Icons.piano;
      case 'Bateria':
        return Icons.radio;
      case 'Ministrante':
        return Icons.mic;
      case 'Backing':
        return Icons.people;
      default:
        return Icons.music_note;
    }
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SocietySelectorSheet extends StatelessWidget {
  const _SocietySelectorSheet({
    required this.societies,
    this.currentSocietyId,
  });

  final List<SocietyModel> societies;
  final String? currentSocietyId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Selecionar sociedade',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Opção para remover sociedade (apenas se houver uma selecionada)
                      if (currentSocietyId != null && currentSocietyId!.isNotEmpty)
                        InkWell(
                          onTap: () => Navigator.of(context).pop(''),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red.withOpacity(0.8),
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Remover sociedade',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: Colors.red.withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      if (societies.isNotEmpty && 
                          (currentSocietyId == null || currentSocietyId!.isEmpty))
                        const SizedBox(height: 12),
                      if (currentSocietyId != null && 
                          currentSocietyId!.isNotEmpty && 
                          societies.isNotEmpty)
                        const SizedBox(height: 12),
                      // Lista de sociedades
                      ...societies.map((society) {
                        final isSelected = society.id == currentSocietyId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () =>
                                Navigator.of(context).pop(society.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white.withOpacity(0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Color(society.color)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        society.name.isNotEmpty
                                            ? society.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: Color(society.color),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          society.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        if (society.description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            society.description,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.white70,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
