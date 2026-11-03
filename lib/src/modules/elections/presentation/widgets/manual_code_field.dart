import 'package:flutter/material.dart';

import '../../models/election_logic.dart';

/// Alternativa à câmera: colar o link (ou o código) da votação. Serve para
/// câmera negada, QR danificado e simulador sem câmera.
class ManualCodeField extends StatefulWidget {
  const ManualCodeField({super.key, required this.onElectionId});

  final ValueChanged<String> onElectionId;

  @override
  State<ManualCodeField> createState() => _ManualCodeFieldState();
}

class _ManualCodeFieldState extends State<ManualCodeField> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  void _submit() {
    final id = parseElectionId(_controller.text);
    if (id == null) {
      setState(() => _error = 'Código ou link inválido.');
      return;
    }
    setState(() => _error = null);
    widget.onElectionId(id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Código ou link da eleição',
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _submit, child: const Text('Entrar')),
      ],
    );
  }
}
