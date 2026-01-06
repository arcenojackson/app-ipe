import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../musics/data/musics_repository.dart';
import '../../musics/models/music.dart';
import '../../people/data/people_repository.dart';
import '../../people/presentation/widgets/user_chip.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import 'widgets/music_view_dialog.dart';
import '../../../shared/utils/tone_utils.dart';

class EventViewerPage extends StatefulWidget {
  const EventViewerPage({super.key, required this.eventId});

  final String eventId;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _event == null
        ? 'Evento'
        : '${_event!.name} (${DateFormat('dd/MM').format(_event!.date)})';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Etapas'),
            Tab(text: 'Músicas'),
            Tab(text: 'Equipe'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _event == null
          ? const Center(child: Text('Evento não encontrado.'))
          : TabBarView(
              controller: _tabController,
              children: [_buildStepsTab(), _buildMusicsTab(), _buildTeamTab()],
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

  Widget _buildMusicsTab() {
    final steps = _event!.steps
        .where((step) => step.type == EventStepType.music)
        .toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: steps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final step = steps[index];
        final music = _musics.firstWhere(
          (m) => m.id == step.musicId,
          orElse: () => MusicModel(
            id: step.musicId ?? '',
            title: step.title,
            artist: '',
            cipher: '',
            tone: step.musicTone ?? '',
          ),
        );
        return Card(
          child: ListTile(
            onTap: () => _openMusic(step.musicId!, customTone: step.musicTone),
            leading: const CircleAvatar(child: Icon(Icons.music_video)),
            title: Text(music.title),
            subtitle: Text(music.artist),
            trailing: Chip(label: Text(toneLabel(step.musicTone ?? '0'))),
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
          if (_event!.people.elo.isNotEmpty) ...[
            _buildPeopleSection('Equipe de Louvor', _event!.people.elo),
            const SizedBox(height: 24),
          ],
          if (_event!.people.preacher.isNotEmpty) ...[
            _buildPeopleSection('Pregador', _event!.people.preacher),
            const SizedBox(height: 24),
          ],
          if (_event!.people.lead.isNotEmpty) ...[
            _buildPeopleSection('Dirigente', _event!.people.lead),
          ],
        ],
      ),
    );
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final eventsRepository = context.read<EventsRepository>();
      final musicsRepository = context.read<MusicsRepository>();
      final peopleRepository = context.read<PeopleRepository>();

      final event = await eventsRepository.fetchById(widget.eventId);
      final musics = await musicsRepository.fetchAll();
      final people = await peopleRepository.fetchAll();

      setState(() {
        _event = event;
        _musics = musics;
        _people = people;
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
}
