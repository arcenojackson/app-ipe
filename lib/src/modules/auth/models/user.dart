class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.isPending,
    this.disabledNotifications = const [],
  });

  final String id;
  final String name;
  final String email;
  final bool isAdmin;
  final bool isPending;
  final List<String> disabledNotifications; // IDs das notificações desabilitadas

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isAdmin: json['is_admin'] == true || json['isAdmin'] == true,
      isPending: json['is_pending'] == true || json['isPending'] == true,
      disabledNotifications: (json['disabled_notifications'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'is_admin': isAdmin,
    'is_pending': isPending,
    if (disabledNotifications.isNotEmpty) 'disabled_notifications': disabledNotifications,
  };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    bool? isAdmin,
    bool? isPending,
    List<String>? disabledNotifications,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      isPending: isPending ?? this.isPending,
      disabledNotifications: disabledNotifications ?? this.disabledNotifications,
    );
  }

  /// Verifica se uma notificação está habilitada (lógica inversa)
  bool isNotificationEnabled(String notificationId) {
    return !disabledNotifications.contains(notificationId);
  }

  // Helpers para verificar tipo de usuário
  bool get isAdminUser => isAdmin && !isPending;
  bool get isStandardUser => !isAdmin && !isPending;
  bool get isNewUser => !isAdmin && isPending;
}
