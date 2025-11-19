const Map<String, String> _tones = {
  '0': 'A',
  '1': 'A#',
  '2': 'B',
  '3': 'C',
  '4': 'C#',
  '5': 'D',
  '6': 'D#',
  '7': 'E',
  '8': 'F',
  '9': 'F#',
  '10': 'G',
  '11': 'G#',
};

String toneLabel(String tone, {bool minor = false}) {
  final base = _tones[tone] ?? tone;
  if (minor && !base.endsWith('m')) {
    return '$base m';
  }
  return base;
}
