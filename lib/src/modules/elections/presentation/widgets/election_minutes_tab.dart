import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../shared/utils/app_toast.dart';
import '../../data/elections_repository.dart';
import '../../models/election.dart';
import '../../models/minutes_text.dart';

/// Ata da eleição: texto gerado do que está gravado, com botão para copiar.
class ElectionMinutesTab extends StatefulWidget {
  const ElectionMinutesTab({super.key, required this.election});

  final Election election;

  @override
  State<ElectionMinutesTab> createState() => _ElectionMinutesTabState();
}

class _ElectionMinutesTabState extends State<ElectionMinutesTab> {
  late final Stream<List<ElectionCargo>> _cargos;
  late final Stream<List<ElectionVoter>> _voters;
  late final Stream<List<ElectionRound>> _rounds;
  late final Stream<List<ElectionEvent>> _events;

  @override
  void initState() {
    super.initState();
    final repo = context.read<ElectionsRepository>();
    _cargos = repo.watchCargos(widget.election.id);
    _voters = repo.watchVoters(widget.election.id);
    _rounds = repo.watchRounds(widget.election.id);
    _events = repo.watchEvents(widget.election.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ElectionCargo>>(
      stream: _cargos,
      builder: (context, cargosSnap) => StreamBuilder<List<ElectionVoter>>(
        stream: _voters,
        builder: (context, votersSnap) => StreamBuilder<List<ElectionRound>>(
          stream: _rounds,
          builder: (context, roundsSnap) => StreamBuilder<List<ElectionEvent>>(
            stream: _events,
            builder: (context, eventsSnap) {
              final error = cargosSnap.error ??
                  votersSnap.error ??
                  roundsSnap.error ??
                  eventsSnap.error;
              if (error != null) return Text('Erro: $error');
              if (!cargosSnap.hasData ||
                  !votersSnap.hasData ||
                  !roundsSnap.hasData ||
                  !eventsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final text = buildMinutesText(
                election: widget.election,
                cargos: cargosSnap.data!,
                voters: votersSnap.data!,
                rounds: roundsSnap.data!,
                events: eventsSnap.data!,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(text),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar ata'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        showSuccessToast(context, 'Ata copiada.');
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
