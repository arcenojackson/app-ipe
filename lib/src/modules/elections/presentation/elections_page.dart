import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/state/app_state.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/elections_repository.dart';
import '../models/election.dart';
import 'election_detail_page.dart';
import 'widgets/election_form_sheet.dart';

class ElectionsPage extends StatefulWidget {
  const ElectionsPage({super.key});

  @override
  State<ElectionsPage> createState() => _ElectionsPageState();
}

class _ElectionsPageState extends State<ElectionsPage> {
  late final Stream<List<Election>> _stream;

  @override
  void initState() {
    super.initState();
    final userId = context.read<AppState>().currentUser?.id ?? '';
    _stream = context.read<ElectionsRepository>().watchElections(userId);
  }

  String _statusLabel(ElectionStatus s) => switch (s) {
        ElectionStatus.draft => 'Rascunho',
        ElectionStatus.open => 'Em andamento',
        ElectionStatus.closed => 'Encerrada',
      };

  String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      color: Colors.white,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Eleições',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<List<Election>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Erro: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final elections = snapshot.data!;
                    if (elections.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhuma eleição ainda.\nToque no botão + para criar.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                      itemCount: elections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final e = elections[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ElectionDetailPage(electionId: e.id),
                            ),
                          ),
                          child: GlassContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${e.societyName} · ${_date(e.scheduledAt)}',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                Chip(label: Text(_statusLabel(e.status))),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const ElectionFormSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
