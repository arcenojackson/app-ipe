class SocietyModel {
  const SocietyModel({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.userId,
    this.membersIds = const [],
    this.boardIds = const [],
  });

  final String id;
  final String name;
  final String description;
  final int color; // Cor armazenada como int (valor hexadecimal)
  final String userId; // ID do criador
  final List<String> membersIds; // IDs dos membros
  final List<String> boardIds; // IDs da diretoria

  factory SocietyModel.fromJson(Map<String, dynamic> json) {
    return SocietyModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      color: _parseColor(json['color']),
      userId: json['userId']?.toString() ?? '',
      membersIds: _parseIds(json['members']),
      boardIds: _parseIds(json['board']),
    );
  }

  static int _parseColor(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      // Remove o # se existir e converte para int
      final cleanValue = value.replaceAll('#', '');
      return int.tryParse(cleanValue, radix: 16) ?? 0xFF2F4F2F;
    }
    return 0xFF2F4F2F; // Cor padrão (verde escuro)
  }

  static List<String> _parseIds(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'color': color,
        'userId': userId,
        'members': membersIds,
        'board': boardIds,
      };

  SocietyModel copyWith({
    String? id,
    String? name,
    String? description,
    int? color,
    String? userId,
    List<String>? membersIds,
    List<String>? boardIds,
  }) {
    return SocietyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      userId: userId ?? this.userId,
      membersIds: membersIds ?? this.membersIds,
      boardIds: boardIds ?? this.boardIds,
    );
  }
}

