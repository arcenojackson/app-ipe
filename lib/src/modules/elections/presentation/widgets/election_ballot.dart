import 'package:flutter/material.dart';

import '../../models/election.dart';
import '../../models/election_logic.dart';
import '../../models/minutes_text.dart';

/// Valor enviado ao servidor para voto em branco.
const String blankChoice = 'blank';

/// Cédula de um escrutínio aberto. A busca por nome só existe no 1º
/// escrutínio (nos seguintes as opções são poucas e já vêm definidas).
///
/// Ocupa a altura toda que receber: a lista de opções rola e o botão
/// "Confirmar voto" fica fixo no rodapé, visível sem chegar ao fim da lista.
class ElectionBallot extends StatefulWidget {
  const ElectionBallot({
    super.key,
    required this.round,
    required this.busy,
    required this.onSubmit,
    this.error,
    this.header,
  });

  final ElectionRound round;
  final bool busy;
  final String? error;
  final ValueChanged<String> onSubmit;

  /// Rola junto com a lista, acima do título da cédula.
  final Widget? header;

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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.header != null) ...[
                widget.header!,
                const SizedBox(height: 16),
              ],
              Text(
                'Votação para ${positionLabel(round.position)} — '
                '${round.number}º escrutínio',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (round.number == 1) ...[
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nome',
                  ),
                  onChanged: (value) => setState(() {
                    _search = value;
                    // A escolha que a busca esconde não pode ser enviada às cegas.
                    final chosen = _choice;
                    if (chosen != null &&
                        chosen != blankChoice &&
                        !filterCandidates(
                          round.options,
                          value,
                        ).any((c) => c.id == chosen)) {
                      _choice = null;
                    }
                  }),
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
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.error != null) ...[
                  Text(
                    widget.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
            ),
          ),
        ),
      ],
    );
  }
}
