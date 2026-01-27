enum EvaluationCategory {
  theological('theological', 'Teológica'),
  congregational('congregational', 'Congregacional'),
  musical('musical', 'Musical');

  const EvaluationCategory(this.name, this.label);
  final String name;
  final String label;

  static EvaluationCategory? fromString(String? value) {
    if (value == null) return null;
    try {
      return EvaluationCategory.values.firstWhere(
        (e) => e.name == value,
      );
    } catch (e) {
      return null;
    }
  }
}
