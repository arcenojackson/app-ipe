import 'package:flutter/material.dart';

import '../../models/forum_logic.dart';
import '../../models/forum_models.dart';
import 'ref_picker.dart';

/// Campo de texto de comentário/resposta/edição. Só limpa se o envio der certo.
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.onSubmit,
    this.initialText = '',
    this.hint = 'Escreva um comentário',
    this.onCancel,
    this.submitLabel = 'Enviar',
    this.allowRefs = false,
  });

  final Future<bool> Function(String text, List<ForumRef> refs) onSubmit;

  /// Mostra "Citar documento ou aula" (novo comentário e resposta).
  final bool allowRefs;
  final String initialText;
  final String hint;
  final String submitLabel;
  final VoidCallback? onCancel;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
  bool _busy = false;
  List<ForumRef> _refs = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.onSubmit(_controller.text, _refs);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _controller.clear();
      setState(() => _refs = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 6,
          maxLength: forumBodyMax,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white10,
            counterStyle: const TextStyle(color: Colors.white38),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (widget.allowRefs)
          Align(
            alignment: Alignment.centerLeft,
            child: RefPickerField(value: _refs, onChanged: (v) => setState(() => _refs = v)),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.onCancel != null)
              TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: Text(_busy ? 'Enviando…' : widget.submitLabel),
            ),
          ],
        ),
      ],
    );
  }
}
