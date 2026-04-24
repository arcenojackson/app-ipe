enum MusicStatus {
  avaliar('avaliar', 'Avaliar'),
  emAvaliacao('em_avaliacao', 'Em avaliação'),
  aprovada('aprovada', 'Aprovada'),
  reprovada('reprovada', 'Reprovada');

  const MusicStatus(this.value, this.label);

  final String value;
  final String label;

  static MusicStatus fromString(String? raw) {
    if (raw == null) return MusicStatus.avaliar;
    return MusicStatus.values.firstWhere(
      (s) => s.value == raw,
      orElse: () => MusicStatus.avaliar,
    );
  }
}
