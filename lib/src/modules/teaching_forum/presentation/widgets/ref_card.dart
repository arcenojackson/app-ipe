import 'package:flutter/material.dart';

import '../../models/forum_models.dart';

/// Citação de documento/aula, igual no tópico e nos comentários.
class RefCard extends StatelessWidget {
  const RefCard({super.key, required this.ref});

  final ForumRef ref;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Icon(ref.kind == 'plan' ? Icons.event_note : Icons.description_outlined,
            size: 16, color: Colors.white54),
        const SizedBox(width: 6),
        Expanded(
          child: Text(ref.label.isEmpty ? 'Item citado' : ref.label,
              style: const TextStyle(color: Colors.white70)),
        ),
      ]),
    );
  }
}
