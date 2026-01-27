enum BoardPosition {
  presidente('Presidente'),
  vice('Vice'),
  secretario('Secretario(a)'),
  tesoureiro('Tesoureiro(a)');

  const BoardPosition(this.label);
  final String label;

  static BoardPosition? fromString(String? value) {
    if (value == null) return null;
    try {
      return BoardPosition.values.firstWhere(
        (e) => e.name == value || e.label == value,
      );
    } catch (e) {
      return null;
    }
  }
}

class SocietyModel {
  const SocietyModel({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.userId,
    this.membersIds = const [],
    this.boardIds = const [],
    this.boardWithPositions = const {},
    this.forumUsersByCategory,
  });

  final String id;
  final String name;
  final String description;
  final int color; // Cor armazenada como int (valor hexadecimal)
  final String userId; // ID do criador
  final List<String> membersIds; // IDs dos membros
  final List<String> boardIds; // IDs da diretoria (formato antigo - compatibilidade)
  final Map<String, List<String>> boardWithPositions; // Map<position, List<userId>> (formato novo)
  final Map<String, List<String>>? forumUsersByCategory; // Map<category, List<userId>> - Usuários do Fórum por categoria

  factory SocietyModel.fromJson(Map<String, dynamic> json) {
    // Parse do board: pode ser List<String> (antigo) ou Map<String, List<String>> (novo)
    final boardData = json['board'];
    final List<String> boardIds = [];
    final Map<String, List<String>> boardWithPositions = {};
    
    if (boardData != null) {
      if (boardData is List) {
        // Formato antigo: List<String>
        boardIds.addAll(boardData.map((e) => e.toString()));
      } else if (boardData is Map) {
        // Formato novo: Map<String, List<String>> onde chave é cargo e valor é lista de userIds
        boardData.forEach((key, value) {
          if (value is List) {
            final userIds = value.map((e) => e.toString()).toList();
            boardWithPositions[key.toString()] = userIds;
            boardIds.addAll(userIds);
          } else if (value is String) {
            // Compatibilidade com formato intermediário Map<String, String>
            final userId = value.toString();
            boardWithPositions.putIfAbsent(key.toString(), () => []).add(userId);
            boardIds.add(userId);
          }
        });
      }
    }
    
    // Parse do forumUsersByCategory
    final forumUsersData = json['forumUsersByCategory'];
    Map<String, List<String>>? forumUsersByCategory;
    if (forumUsersData != null && forumUsersData is Map) {
      forumUsersByCategory = {};
      forumUsersData.forEach((key, value) {
        if (value is List) {
          forumUsersByCategory![key.toString()] =
              value.map((e) => e.toString()).toList();
        }
      });
    }

    return SocietyModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      color: _parseColor(json['color']),
      userId: json['userId']?.toString() ?? '',
      membersIds: _parseIds(json['members']),
      boardIds: boardIds,
      boardWithPositions: boardWithPositions,
      forumUsersByCategory: forumUsersByCategory,
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
        // Se tiver posições, salvar no formato novo (Map<String, List<String>>), senão usar formato antigo (List)
        'board': boardWithPositions.isNotEmpty
            ? boardWithPositions
            : boardIds,
        if (forumUsersByCategory != null && forumUsersByCategory!.isNotEmpty)
          'forumUsersByCategory': forumUsersByCategory,
      };

  SocietyModel copyWith({
    String? id,
    String? name,
    String? description,
    int? color,
    String? userId,
    List<String>? membersIds,
    List<String>? boardIds,
    Map<String, List<String>>? boardWithPositions,
    Map<String, List<String>>? forumUsersByCategory,
  }) {
    return SocietyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      userId: userId ?? this.userId,
      membersIds: membersIds ?? this.membersIds,
      boardIds: boardIds ?? this.boardIds,
      boardWithPositions: boardWithPositions ?? this.boardWithPositions,
      forumUsersByCategory: forumUsersByCategory ?? this.forumUsersByCategory,
    );
  }
  
  // Helper para obter todos os IDs da diretoria (compatibilidade)
  List<String> get allBoardIds {
    if (boardWithPositions.isNotEmpty) {
      return boardWithPositions.values.expand((list) => list).toList();
    }
    return boardIds;
  }
}

