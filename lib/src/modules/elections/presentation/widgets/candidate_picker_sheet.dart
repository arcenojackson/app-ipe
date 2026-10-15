import 'package:flutter/material.dart';

import '../../models/election.dart';

class CandidatePickerSheet extends StatefulWidget {
  const CandidatePickerSheet({
    super.key,
    required this.options,
    this.initial = const [],
  });

  final List<Candidate> options;
  final List<Candidate> initial;

  @override
  State<CandidatePickerSheet> createState() => _CandidatePickerSheetState();
}

class _CandidatePickerSheetState extends State<CandidatePickerSheet> {
  late final Set<String> _selected = {for (final c in widget.initial) c.id};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Candidatos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: widget.options.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhum membro disponível para este cargo.'),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in widget.options)
                        CheckboxListTile(
                          value: _selected.contains(c.id),
                          title: Text(c.name),
                          onChanged: (on) => setState(() {
                            on == true
                                ? _selected.add(c.id)
                                : _selected.remove(c.id);
                          }),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop([
                          for (final c in widget.options)
                            if (_selected.contains(c.id)) c,
                        ]),
                child: const Text('Confirmar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
