class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.isAdmin,
  });

  final String id;
  final String name;
  final String email;
  final bool isAdmin;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isAdmin: json['is_admin'] == true || json['isAdmin'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'is_admin': isAdmin,
  };

  UserModel copyWith({String? id, String? name, String? email, bool? isAdmin}) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
