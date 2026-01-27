import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../musics/data/musics_repository.dart';
import '../../musics/models/music.dart';
import '../../people/data/people_repository.dart';
import '../../people/presentation/widgets/user_chip.dart';
import '../../societies/data/societies_repository.dart';
import '../../societies/models/society.dart';
import '../data/events_repository.dart';
import '../data/chat_repository.dart';
import '../models/event.dart';
import '../models/event_template.dart';
import '../../../core/config/firebase_config.dart';
import 'widgets/music_view_dialog.dart';
import '../../../shared/utils/tone_utils.dart';
import 'event_chat_tab.dart';

class EventViewerPage extends StatefulWidget {
  const EventViewerPage({
    super.key,
    required this.eventId,
    this.initialTabIndex = 0,
    this.initialMessageId,
  });

  final String eventId;
  final int initialTabIndex; // 0: Etapas, 1: Pessoas, 2: Equipes, 3: Chat
  final String? initialMessageId; // ID da mensagem para scrollar (usado no chat)

  @override
  State<EventViewerPage> createState() => _EventViewerPageState();
}

class _EventViewerPageState extends State<EventViewerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = true;
  EventModel? _event;
  List<MusicModel> _musics = const [];
  List<UserModel> _people = const [];
  List<SocietyModel> _societies = const [];
  EventTemplateModel? _template;
  final ChatRepository _chatRepository = ChatRepository();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseConfig.auth.currentUser?.uid;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  void _onTabChanged() {
    // Quando a aba do chat (índice 3) é selecionada, marcar mensagens como lidas
    if (_tabController.index == 3 && _event != null && _currentUserId != null) {
      final isUserAssigned = _event!.people.allPeopleIds.contains(_currentUserId!);
      if (isUserAssigned) {
        // Aguardar um pouco para garantir que o chat foi carregado
        Future.delayed(const Duration(milliseconds: 1000), () async {
          if (mounted && _tabController.index == 3) {
            try {
              // Buscar todas as mensagens não deletadas (sem orderBy para evitar necessidade de índice)
              final messagesSnapshot = await FirebaseConfig.firestore
                  .collection('services')
                  .doc(widget.eventId)
                  .collection('messages')
                  .where('isDeleted', isEqualTo: false)
                  .get();
              
              if (messagesSnapshot.docs.isNotEmpty) {
                // Encontrar a mensagem mais recente manualmente
                var lastMessage = messagesSnapshot.docs.first;
                var lastTimestamp = (lastMessage.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                
                for (var doc in messagesSnapshot.docs) {
                  final timestamp = (doc.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                  if (timestamp > lastTimestamp) {
                    lastTimestamp = timestamp;
                    lastMessage = doc;
                  }
                }
                
                // Marcar todas como visualizadas e atualizar última lida
                await _chatRepository.markAllMessagesAsViewed(widget.eventId);
                await _chatRepository.setLastReadMessageId(
                  widget.eventId,
                  lastMessage.id,
                );
              }
            } catch (e) {
              // Ignorar erros silenciosamente
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _event == null
        ? 'Evento'
        : '${_event!.name} (${DateFormat('dd/MM').format(_event!.date)})';

    // Verificar se usuário está escalado no evento
    final isUserAssigned = _event != null && _currentUserId != null &&
        _event!.people.allPeopleIds.contains(_currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Etapas'),
            const Tab(text: 'Pessoas'),
            const Tab(text: 'Equipes'),
            _buildChatTab(isUserAssigned),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _event == null
          ? const Center(child: Text('Evento não encontrado.'))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStepsTab(),
                _buildTeamTab(),
                _buildTeamsTab(),
                if (_event != null)
                  EventChatTab(
                    eventId: widget.eventId,
                    event: _event!,
                    initialMessageId: widget.initialMessageId,
                  )
                else
                  const Center(child: Text('Carregando...')),
              ],
            ),
    );
  }

  Widget _buildStepsTab() {
    final steps = _event!.steps;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: steps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final step = steps[index];
        final isMusic = step.type == EventStepType.music;
        return Card(
          child: ListTile(
            onTap: isMusic
                ? () => _openMusic(step.musicId!, customTone: step.musicTone)
                : null,
            leading: CircleAvatar(
              child: Icon(isMusic ? Icons.music_note : Icons.list_alt),
            ),
            title: Text(step.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step.description?.isNotEmpty == true)
                  Text(step.description!),
                if (isMusic && step.musicTone != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Chip(
                      label: Text(
                        'Tom: ${toneLabel(step.musicTone!, minor: false)}',
                      ),
                    ),
                  ),
              ],
            ),
            trailing: isMusic ? const Icon(Icons.play_circle) : null,
          ),
        );
      },
    );
  }

  Widget _buildTeamTab() {
    final allPeopleIds = _event!.people.allPeopleIds;
    if (allPeopleIds.isEmpty) {
      return const Center(child: Text('Nenhuma pessoa atribuída.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_event!.people.elo.isNotEmpty || _event!.people.eloWithInstruments.isNotEmpty) ...[
            _buildEloSection(),
            const SizedBox(height: 24),
          ],
          if (_event!.people.soundImage.isNotEmpty) ...[
            _buildPeopleSection('Som e Imagem', _event!.people.soundImage),
            const SizedBox(height: 24),
          ],
          if (_event!.people.lead.isNotEmpty || _event!.people.preacher.isNotEmpty) ...[
            _buildLeadAndPreacherSection(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildEloSection() {
    // Agrupar pessoas por instrumento
    final instrumentGroups = <String, List<MapEntry<String, bool>>>{};
    
    // Adicionar pessoas com instrumentos
    _event!.people.eloWithInstruments.forEach((userId, instruments) {
      instruments.forEach((instrument, talkBack) {
        instrumentGroups.putIfAbsent(instrument, () => []).add(
          MapEntry(userId, talkBack),
        );
      });
    });
    
    // Adicionar pessoas sem instrumento específico (elo antigo)
    for (final userId in _event!.people.elo) {
      if (!_event!.people.eloWithInstruments.containsKey(userId)) {
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
        
        allPeople.add(_buildEloPersonChip(
          user: user,
          instrument: instrument != 'Geral' ? instrument : null,
          talkBack: talkBack,
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
  
  Widget _buildEloPersonChip({
    required UserModel user,
    String? instrument,
    bool talkBack = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
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
            const SizedBox(height: 4),
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
    );
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
  
  Widget _buildLeadAndPreacherSection() {
    final allPeopleIds = [
      ..._event!.people.lead,
      ..._event!.people.preacher,
    ];
    
    final people = _people.where((user) => allPeopleIds.contains(user.id)).toList();
    
    String title;
    if (_event!.people.lead.isNotEmpty && _event!.people.preacher.isNotEmpty) {
      title = 'Dirigente e Pregador';
    } else if (_event!.people.lead.isNotEmpty) {
      title = 'Dirigente';
    } else {
      title = 'Pregador';
    }
    
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: people
              .map((user) => UserChip(user: user))
              .toList(),
        ),
      ],
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

  Widget _buildPeopleSection(String title, List<String> peopleIds) {
    final people = _people.where((user) => peopleIds.contains(user.id)).toList();
    
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: people
              .map((user) => UserChip(user: user))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTeamsTab() {
    final teams = _event!.teams;
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
        societyId: teams.liturgia,
      ));
      if (shouldShowLanche || shouldShowAberturaEbd || shouldShowReuniaoOracao) {
        items.add(const SizedBox(height: 16));
      }
    }
    
    if (shouldShowLanche) {
      items.add(_buildTeamResponsibilityCard(
        title: 'Lanche pós-culto',
        icon: Icons.restaurant,
        societyId: teams.lanche,
      ));
      if (shouldShowAberturaEbd || shouldShowReuniaoOracao) {
        items.add(const SizedBox(height: 16));
      }
    }
    
    if (shouldShowAberturaEbd) {
      items.add(_buildTeamResponsibilityCard(
        title: 'Abertura EBD',
        icon: Icons.school,
        societyId: teams.aberturaEbd,
      ));
      if (shouldShowReuniaoOracao) {
        items.add(const SizedBox(height: 16));
      }
    }
    
    if (shouldShowReuniaoOracao) {
      items.add(_buildTeamResponsibilityCard(
        title: 'Reunião de oração',
        icon: Icons.favorite,
        societyId: teams.reuniaoOracao,
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final eventsRepository = context.read<EventsRepository>();
      final musicsRepository = context.read<MusicsRepository>();
      final peopleRepository = context.read<PeopleRepository>();
      final societiesRepository = context.read<SocietiesRepository>();

      final event = await eventsRepository.fetchById(widget.eventId);
      final musics = await musicsRepository.fetchAll();
      final people = await peopleRepository.fetchAll();
      final societies = await societiesRepository.fetchAll();

      // Carregar template se houver templateId
      EventTemplateModel? template;
      if (event.templateId != null && event.templateId!.isNotEmpty) {
        try {
          template = await eventsRepository.fetchTemplateById(event.templateId!);
        } catch (_) {
          // Se não conseguir carregar o template, continua sem ele
        }
      }

      setState(() {
        _event = event;
        _musics = musics;
        _people = people;
        _societies = societies;
        _template = template;
      });
    } catch (_) {
      setState(() {
        _event = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openMusic(String musicId, {String? customTone}) async {
    final music = await context.read<MusicsRepository>().fetchById(musicId);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => MusicViewDialog(music: music, customTone: customTone),
    );
  }

  Widget _buildChatTab(bool isUserAssigned) {
    // Se o usuário não está escalado, não mostrar indicador
    if (!isUserAssigned || _event == null) {
      return const Tab(text: 'Chat');
    }

    return StreamBuilder<int>(
      stream: _chatRepository.getUnreadMessageCount(widget.eventId),
      builder: (context, snapshot) {
        // Se ainda está carregando, não mostrar indicador
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Tab(text: 'Chat');
        }

        final unreadCount = snapshot.data ?? 0;
        final hasUnread = unreadCount > 0;

        // Se a aba do chat está ativa, não mostrar indicador (mensagens serão marcadas como lidas)
        final isChatTabActive = _tabController.index == 3;

        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Chat'),
              if (hasUnread && !isChatTabActive) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
