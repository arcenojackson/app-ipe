import 'package:flutter/material.dart';

import '../utils/tone_utils.dart';

class TonePicker extends StatelessWidget {
  const TonePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.isMinor = false,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final bool isMinor;

  static const _toneValues = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _toneValues
          .map(
            (tone) => ChoiceChip(
              label: Text(toneLabel(tone, minor: isMinor)),
              selected: value == tone,
              onSelected: (_) => onChanged(tone),
            ),
          )
          .toList(),
    );
  }
}
