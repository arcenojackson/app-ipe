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
  bool _isSaving = false;
  int _currentTabIndex = 0;
  EventModel? _event;
  List<EventStepModel> _steps = const [];
  List<MusicModel> _musics = const [];
  List<UserModel> _people = const [];
  EventPeople _selectedPeople = const EventPeople();

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
            onPressed: (_isSaving || _isPastEvent) ? null : _save,
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
            Tab(text: 'Pessoas'),
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
      floatingActionButton: _isPastEvent
          ? null
          : (_currentTabIndex == 0
              ? FloatingActionButton(
                  onPressed: _addStep,
                  child: const Icon(Icons.add),
                )
              : FloatingActionButton(
                  onPressed: _manageTeam,
                  child: const Icon(Icons.group_add),
                )),
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
      }
    });
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

      setState(() {
        _event = event;
        _steps = List.of(event.steps);
        _selectedPeople = event.people;
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
    // Mostrar mini modal com opções primeiro
    final option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PeopleTypeSelectorSheet(),
    );

    if (option == null) return;

    // Se for ELO, mostrar submenu de instrumentos
    if (option == 'elo') {
      final instrument = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _InstrumentSelectorSheet(),
      );
      
      if (instrument == null) return;
      
      await _addEloMember(instrument);
      return;
    }

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

    // Determinar filtros baseado na opção escolhida
    bool filterByELO = false;
    String? filterBySociety;
    List<String> currentSelectedIds = [];

    switch (option) {
      case 'pregador':
        currentSelectedIds = _selectedPeople.preacher;
        break;
      case 'dirigente':
        currentSelectedIds = _selectedPeople.lead;
        break;
      case 'soundImage':
        filterBySociety = 'Som e Imagem';
        currentSelectedIds = _selectedPeople.soundImage;
        break;
    }

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PeopleSelectorSheet(
        people: _people,
        selectedIds: currentSelectedIds,
        eventDate: _event?.date,
        filterByELO: filterByELO,
        filterBySociety: filterBySociety,
      ),
    );
    if (result != null) {
      setState(() {
        switch (option) {
          case 'pregador':
            _selectedPeople = _selectedPeople.copyWith(preacher: result);
            break;
          case 'dirigente':
            _selectedPeople = _selectedPeople.copyWith(lead: result);
            break;
          case 'soundImage':
            _selectedPeople = _selectedPeople.copyWith(soundImage: result);
            break;
        }
      });
    }
  }

  Future<void> _addEloMember(String instrument) async {
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

    // Obter pessoas já selecionadas para este instrumento
    final currentSelectedIds = <String>[];
    _selectedPeople.eloWithInstruments.forEach((userId, instruments) {
      if (instruments.containsKey(instrument)) {
        currentSelectedIds.add(userId);
      }
    });

    // Determinar se deve mostrar Talk Back
    final showTalkBack = instrument != 'Ministrante' && instrument != 'Backing';

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PeopleSelectorSheet(
        people: _people,
        selectedIds: currentSelectedIds,
        eventDate: _event?.date,
        filterByELO: true,
        instrument: instrument,
        showTalkBack: showTalkBack,
      ),
    );

    if (result != null) {
      setState(() {
        final updatedInstruments = Map<String, Map<String, bool>>.from(
          _selectedPeople.eloWithInstruments,
        );

        if (result is Map<String, Map<String, bool>>) {
          // Resultado com instrumentos e talk back
          result.forEach((userId, instruments) {
            updatedInstruments[userId] = {
              ...updatedInstruments[userId] ?? {},
              ...instruments,
            };
          });
        } else if (result is List<String>) {
          // Resultado simples (sem talk back - não deveria acontecer, mas mantém compatibilidade)
          for (final userId in result) {
            updatedInstruments[userId] = {
              ...updatedInstruments[userId] ?? {},
              instrument: false,
            };
          }
        }

        _selectedPeople = _selectedPeople.copyWith(
          eloWithInstruments: updatedInstruments,
        );
      });
    }
  }

  Future<void> _save() async {
    if (_isPastEvent) {
      showErrorToast(context, 'Não é possível salvar alterações em eventos passados.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<EventsRepository>().updateEventDetails(
        id: widget.eventId,
        steps: _steps,
        people: _selectedPeople,
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
              _OptionTile(
                icon: Icons.music_note,
                title: 'Adicionar Equipe de louvor',
                onTap: () => Navigator.of(context).pop('elo'),
              ),
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.video_library,
                title: 'Adicionar som/imagem',
                onTap: () => Navigator.of(context).pop('soundImage'),
              ),
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.mic,
                title: 'Adicionar pregador',
                onTap: () => Navigator.of(context).pop('pregador'),
              ),
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.person,
                title: 'Adicionar dirigente',
                onTap: () => Navigator.of(context).pop('dirigente'),
              ),
              const SizedBox(height: 16),
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
              child: Text(
                'Selecionar instrumento',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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
