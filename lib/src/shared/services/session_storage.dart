import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../modules/auth/models/user.dart';

class SessionStorage {
  static const _userKey = 'ipe_user';

  Future<UserModel?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_userKey);
    if (json == null) return null;
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return UserModel.fromJson(decoded);
  }

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
