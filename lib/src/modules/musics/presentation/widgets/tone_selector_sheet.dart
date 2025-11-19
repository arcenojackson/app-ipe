import 'package:flutter/material.dart';

import 'package:ipe_flutter/src/shared/widgets/tone_picker.dart';

class ToneSelectorSheet extends StatelessWidget {
  const ToneSelectorSheet({
    super.key,
    required this.selectedTone,
    required this.onToneSelected,
    this.isMinor = false,
  });

  final String? selectedTone;
  final ValueChanged<String> onToneSelected;
  final bool isMinor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tom', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TonePicker(
          value: selectedTone,
          onChanged: onToneSelected,
          isMinor: isMinor,
        ),
      ],
    );
  }
}
