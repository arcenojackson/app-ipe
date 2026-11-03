import 'package:flutter/material.dart';

import '../../models/election.dart';
import '../../models/election_logic.dart';
import '../../models/minutes_text.dart';

/// Valor enviado ao servidor para voto em branco.
const String blankChoice = 'blank';

/// Cédula de um escrutínio aberto. A busca por nome só existe no 1º
/// escrutínio (nos seguintes as opções são poucas e já vêm definidas).
class ElectionBallot extends StatefulWidget {
  const ElectionBallot({
    super.key,
    required this.round,
    required this.busy,
    required this.onSubmit,
    this.error,
  });

  final ElectionRound round;
  final bool busy;
  final String? error;
  final ValueChanged<String> onSubmit;

  @override
  State<ElectionBallot> createState() => _ElectionBallotState();
}

class _ElectionBallotState extends State<ElectionBallot> {
  String? _choice;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final round = widget.round;
    final visible = round.number == 1
        ? filterCandidates(round.options, _search)
        : round.options;
    final options = [
      for (final c in visible) (value: c.id, label: c.name),
      (value: blankChoice, label: 'Branco'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Votação para ${positionLabel(round.position)} — '
          '${round.number}º escrutínio',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        if (round.number == 1) ...[
          TextField(
            decoration: const InputDecoration(labelText: 'Buscar por nome'),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 8),
        ],
        for (final option in options)
          ListTile(
            key: ValueKey('ballot-${option.value}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _choice == option.value
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(option.label),
            selected: _choice == option.value,
            onTap: widget.busy
                ? null
                : () => setState(() => _choice = option.value),
          ),
        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _choice == null || widget.busy
              ? null
              : () => widget.onSubmit(_choice!),
          child: widget.busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmar voto'),
        ),
      ],
    );
  }
}
