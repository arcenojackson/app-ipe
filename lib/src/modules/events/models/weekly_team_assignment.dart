class WeeklyTeamAssignment {
  const WeeklyTeamAssignment({
    required this.weekNumber, // 1-4
    this.liturgia,
    this.lanche,
    this.aberturaEbd,
    this.reuniaoOracao,
  });

  final int weekNumber; // 1 = primeira semana, 2 = segunda, etc.
  final String? liturgia; // ID da sociedade
  final String? lanche; // ID da sociedade
  final String? aberturaEbd; // ID da sociedade
  final String? reuniaoOracao; // ID da sociedade

  factory WeeklyTeamAssignment.fromJson(Map<String, dynamic> json) {
    return WeeklyTeamAssignment(
      weekNumber: json['weekNumber'] as int? ?? 1,
      liturgia: json['liturgia']?.toString(),
      lanche: json['lanche']?.toString(),
      aberturaEbd: json['aberturaEbd']?.toString(),
      reuniaoOracao: json['reuniaoOracao']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'weekNumber': weekNumber,
    if (liturgia != null) 'liturgia': liturgia,
    if (lanche != null) 'lanche': lanche,
    if (aberturaEbd != null) 'aberturaEbd': aberturaEbd,
    if (reuniaoOracao != null) 'reuniaoOracao': reuniaoOracao,
  };

  WeeklyTeamAssignment copyWith({
    int? weekNumber,
    String? liturgia,
    String? lanche,
    String? aberturaEbd,
    String? reuniaoOracao,
  }) {
    return WeeklyTeamAssignment(
      weekNumber: weekNumber ?? this.weekNumber,
      liturgia: liturgia ?? this.liturgia,
      lanche: lanche ?? this.lanche,
      aberturaEbd: aberturaEbd ?? this.aberturaEbd,
      reuniaoOracao: reuniaoOracao ?? this.reuniaoOracao,
    );
  }
}
