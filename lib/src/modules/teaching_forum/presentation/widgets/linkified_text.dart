import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/forum_logic.dart';

/// Texto com links http(s) tocáveis; nada além de http(s) vira link.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    for (final part in linkify(widget.text)) {
      if (!part.isLink) {
        spans.add(TextSpan(text: part.value));
        continue;
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          final uri = Uri.tryParse(part.value);
          if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
        };
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: part.value,
        style: const TextStyle(
          color: Colors.lightBlueAccent,
          decoration: TextDecoration.underline,
        ),
        recognizer: recognizer,
      ));
    }
    return Text.rich(TextSpan(children: spans, style: widget.style));
  }
}
