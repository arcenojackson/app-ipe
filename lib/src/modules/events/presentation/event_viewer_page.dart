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
import '../../holyrics/data/holyrics_service.dart';
import '../../holyrics/presentation/holyrics_settings_screen.dart';
import '../../../shared/utils/app_toast.dart';

class EventViewerPage extends StatefulWidget {
  const EventViewerPage({
    super.key,
    required this.eventId,
    this.initialTabIndex = 0,
    this.initialMessageId,
  });

  final String eventId;
  final int initialTabIndex; // 0: Etapas, 1: Pessoas, 2: Equipes, 3: Chat
  final String?
  initialMessageId; // ID da mensagem para scrollar (usado no chat)

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
  bool _shouldAutoOpenChat = false;
  String? _chatInitialMessageId;
  final HolyricsService _holyricsService = HolyricsService();

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseConfig.auth.currentUser?.uid;
    _shouldAutoOpenChat = widget.initialTabIndex == 3;
    _chatInitialMessageId = widget.initialMessageId;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _markChatMessagesAsRead() async {
    if (_event == null || _currentUserId == null) return;
    final isUserAssigned = _event!.people.allPeopleIds.contains(_currentUserId!);
    if (!isUserAssigned) return;

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    try {
      final messagesSnapshot = await FirebaseConfig.firestore
          .collection('services')
          .doc(widget.eventId)
          .collection('messages')
          .where('isDeleted', isEqualTo: false)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        var lastMessage = messagesSnapshot.docs.first;
        var lastTimestamp =
            (lastMessage.data()['timestamp'] as Timestamp?)
                ?.millisecondsSinceEpoch ??
            0;

        for (var doc in messagesSnapshot.docs) {
          final timestamp =
              (doc.data()['timestamp'] as Timestamp?)
                  ?.millisecondsSinceEpoch ??
              0;
          if (timestamp > lastTimestamp) {
            lastTimestamp = timestamp;
            lastMessage = doc;
          }
        }

        await _chatRepository.markAllMessagesAsViewed(widget.eventId);
        await _chatRepository.setLastReadMessageId(
          widget.eventId,
          lastMessage.id,
        );
      }
    } catch (_) {
      // Ignorar erros silenciosamente
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _holyricsService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _event == null
        ? 'Evento'
        : '${_event!.name} (${DateFormat('dd/MM').format(_event!.date)})';

    // Verificar se usuário está escalado no evento
    final isUserAssigned =
        _event != null &&
        _currentUserId != null &&
        _event!.people.allPeopleIds.contains(_currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_event != null) _buildChatAction(isUserAssigned),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Etapas'),
            Tab(text: 'Pessoas'),
            Tab(text: 'Equipes'),
          ],
        ),
      ),
      floatingActionButton: _event != null &&
              _event!.steps.isNotEmpty &&
              _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _sendToHolyrics,
              icon: const Icon(Icons.cast_connected),
              label: const Text('Enviar para Holyrics'),
            )
          : null,
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
          if (_event!.people.elo.isNotEmpty ||
              _event!.people.eloWithInstruments.isNotEmpty) ...[
            _buildEloSection(),
            const SizedBox(height: 24),
          ],
          if (_event!.people.soundImage.isNotEmpty) ...[
            _buildPeopleSection('Som e Imagem', _event!.people.soundImage),
            const SizedBox(height: 24),
          ],
          if (_event!.people.lead.isNotEmpty ||
              _event!.people.preacher.isNotEmpty) ...[
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
        instrumentGroups
            .putIfAbsent(instrument, () => [])
            .add(MapEntry(userId, talkBack));
      });
    });

    // Adicionar pessoas sem instrumento específico (elo antigo)
    for (final userId in _event!.people.elo) {
      if (!_event!.people.eloWithInstruments.containsKey(userId)) {
        instrumentGroups
            .putIfAbsent('Geral', () => [])
            .add(MapEntry(userId, false));
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

        allPeople.add(
          _buildEloPersonChip(
            user: user,
            instrument: instrument != 'Geral' ? instrument : null,
            talkBack: talkBack,
          ),
        );
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
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
          children: chips
              .map((chip) => SizedBox(width: itemWidth, child: chip))
              .toList(),
        );
      },
    );
  }

  Widget _buildLeadAndPreacherSection() {
    final allPeopleIds = [..._event!.people.lead, ..._event!.people.preacher];

    final people = _people
        .where((user) => allPeopleIds.contains(user.id))
        .toList();

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
          children: people.map((user) => UserChip(user: user)).toList(),
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
    final people = _people
        .where((user) => peopleIds.contains(user.id))
        .toList();

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
          children: people.map((user) => UserChip(user: user)).toList(),
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
      items.add(
        _buildTeamResponsibilityCard(
          title: 'Montar liturgia',
          icon: Icons.menu_book,
          societyId: teams.liturgia,
        ),
      );
      if (shouldShowLanche ||
          shouldShowAberturaEbd ||
          shouldShowReuniaoOracao) {
        items.add(const SizedBox(height: 16));
      }
    }

    if (shouldShowLanche) {
      items.add(
        _buildTeamResponsibilityCard(
          title: 'Lanche pós-culto',
          icon: Icons.restaurant,
          societyId: teams.lanche,
        ),
      );
      if (shouldShowAberturaEbd || shouldShowReuniaoOracao) {
        items.add(const SizedBox(height: 16));
      }
    }

    if (shouldShowAberturaEbd) {
      items.add(
        _buildTeamResponsibilityCard(
          title: 'Abertura EBD',
          icon: Icons.school,
          societyId: teams.aberturaEbd,
        ),
      );
      if (shouldShowReuniaoOracao) {
        items.add(const SizedBox(height: 16));
      }
    }

    if (shouldShowReuniaoOracao) {
      items.add(
        _buildTeamResponsibilityCard(
          title: 'Reunião de oração',
          icon: Icons.favorite,
          societyId: teams.reuniaoOracao,
        ),
      );
    }

    if (items.isEmpty) {
      return const Center(
        child: Text('Nenhuma equipe atribuída para este tipo de evento.'),
      );
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
    return name.contains('culto à noite') || name.contains('culto de ceia');
  }

  bool _shouldShowLanche(String templateName) {
    final name = templateName.toLowerCase();
    return name.contains('culto à noite') || name.contains('culto de ceia');
  }

  bool _shouldShowAberturaEbd(String templateName) {
    final name = templateName.toLowerCase();
    return name.contains('escola bíblica') || name.contains('escola biblica');
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
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
          template = await eventsRepository.fetchTemplateById(
            event.templateId!,
          );
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

      if (_shouldAutoOpenChat && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openChatModal(initialMessageId: _chatInitialMessageId);
        });
      }
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

  // Monta toda a liturgia na playlist do Holyrics de uma só vez.
  // Músicas são buscadas pelo título no banco do Holyrics via SearchLyrics.
  // Versículos bíblicos são passados diretamente como referência textual.
  // Itens de texto e etapas genéricas são adicionados como plain_text.
  Future<void> _sendToHolyrics() async {
    if (_event == null || _event!.steps.isEmpty) return;

    final configured = await _holyricsService.isConfigured();
    if (!configured) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const HolyricsSettingsScreen(),
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Preparando liturgia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pesquisando músicas no Holyrics...'),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );

    final connected = await _holyricsService.testConnection();
    if (!mounted) return;
    if (!connected) {
      Navigator.of(context).pop();
      showErrorToast(context, 'Não foi possível se conectar ao Holyrics');
      return;
    }

    try {
      final items = <Map<String, dynamic>>[];
      final notFoundSongs = <String>[];

      // Cabeçalho da liturgia
      final dateStr = DateFormat('dd/MM').format(_event!.date);
      items.add({'type': 'title', 'name': '${_event!.name} — $dateStr'});

      for (final step in _event!.steps) {
        if (step.type == EventStepType.music && step.musicId != null) {
          final music = await context.read<MusicsRepository>().fetchById(
            step.musicId!,
          );
          final songId = await _holyricsService.searchSong(music.title);
          if (songId != null) {
            items.add({'type': 'song', 'id': songId});
          } else {
            // Tenta criar a música no Holyrics com os dados do app
            try {
              final createdId = await _holyricsService.createSong(
                title: music.title,
                artist: music.artist,
                lyrics: music.lyrics,
                tone: music.tone,
                minorTone: music.minorTone,
                bpm: music.bpm,
              );
              items.add({'type': 'song', 'id': createdId});
            } catch (e) {
              notFoundSongs.add('${music.title} (${e.toString()})');
              items.add({'type': 'plain_text', 'name': '♪ ${music.title}', 'text': '♪ ${music.title}'});
            }
          }
        } else {
          final bibleRef = _extractBibleReference(step.title);
          final hymnNumber = _extractHymnNumber(step.title);
          if (bibleRef != null) {
            items.add({'type': 'verse', 'references': bibleRef});
          } else if (hymnNumber != null) {
            final searchTitle = 'HNC $hymnNumber';
            final songId = await _holyricsService.searchSong(searchTitle);
            if (songId != null) {
              items.add({'type': 'song', 'id': songId});
            } else {
              notFoundSongs.add(searchTitle);
              items.add({'type': 'plain_text', 'name': searchTitle, 'text': searchTitle});
            }
          } else {
            final desc = (step.description ?? '').trim();
            if (desc.isNotEmpty && _looksLikeBibleReference(desc)) {
              items.add({'type': 'verse', 'references': desc});
            } else {
              final text = desc.isNotEmpty ? '${step.title}\n$desc' : step.title;
              items.add({'type': 'plain_text', 'name': step.title, 'text': text});
            }
          }
        }
      }

      await _holyricsService.addToPlaylist(items);

      if (!mounted) return;
      Navigator.of(context).pop();

      if (notFoundSongs.isEmpty) {
        showSuccessToast(
          context,
          'Liturgia adicionada à playlist do Holyrics!',
        );
      } else {
        final songList = notFoundSongs.map((s) => '• $s').join('\n');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Liturgia enviada com avisos'),
            content: Text(
              'A liturgia foi adicionada à playlist.\n\n'
              'Músicas não encontradas no Holyrics (adicionadas como texto):\n$songList',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showErrorToast(context, 'Erro ao enviar para o Holyrics: $e');
    }
  }

  // Extrai o número do hino HNC do título de etapas de "Cântico: <número>".
  // Retorna o número formatado com 3 dígitos (ex: "015"), ou null se não for um cântico.
  String? _extractHymnNumber(String title) {
    final match = RegExp(
      r'c[âa]ntico:?\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(title.trim());
    if (match == null) return null;
    final number = int.tryParse(match.group(1)!);
    if (number == null) return null;
    return number.toString().padLeft(3, '0');
  }

  // Extrai a referência bíblica do título de etapas de "Leitura Bíblica".
  // Ex: "Leitura Bíblica 2 Sm 10.2" → "2 Sm 10.2"
  // Retorna null se o título não contiver "Leitura Bíblica" ou não houver referência.
  String? _extractBibleReference(String title) {
    final match = RegExp(
      r'leitura\s+b[íi]blica:?\s+(.+)',
      caseSensitive: false,
    ).firstMatch(title.trim());
    if (match == null) return null;
    final ref = match.group(1)!.trim();
    return ref.isNotEmpty ? ref : null;
  }

  bool _looksLikeBibleReference(String text) {
    // Aceita formatos como: "João 3:16", "Sl 23.1", "1Jo 3:16-18", "Rm 12:2"
    final biblePattern = RegExp(
      r'^[1-3]?\s*[A-Za-zÀ-ÿ]+\.?\s+\d+[:.]\d+(?:[.-]\d+)?$',
      caseSensitive: false,
    );
    return biblePattern.hasMatch(text.trim());
  }

  void _openChatModal({String? initialMessageId}) {
    if (_event == null) return;
    _markChatMessagesAsRead();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      builder: (ctx) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                const Text(
                  'Chat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: EventChatTab(
              eventId: widget.eventId,
              event: _event!,
              initialMessageId: initialMessageId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatAction(bool isUserAssigned) {
    if (!isUserAssigned || _event == null) {
      return IconButton(
        icon: const Icon(Icons.chat_bubble_outline),
        tooltip: 'Chat',
        onPressed: () => _openChatModal(),
      );
    }

    return StreamBuilder<int>(
      stream: _chatRepository.getUnreadMessageCount(widget.eventId),
      builder: (context, snapshot) {
        final hasUnread = (snapshot.data ?? 0) > 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Chat',
              onPressed: () => _openChatModal(),
            ),
            if (hasUnread)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

}
