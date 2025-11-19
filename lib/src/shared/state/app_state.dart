import 'package:flutter/foundation.dart';

import '../../core/utils/app_exception.dart';
import '../../modules/auth/data/auth_repository.dart';
import '../../modules/auth/models/user.dart';

class AppState extends ChangeNotifier {
  AppState({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  UserModel? _currentUser;
  bool _isBootstrapping = true;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isBootstrapping => _isBootstrapping;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> bootstrap() async {
    try {
      _currentUser = await _authRepository.restoreSession();
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await _executeAuth(() async {
      _currentUser = await _authRepository.signIn(
        email: email,
        password: password,
      );
    });
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _executeAuth(() async {
      _currentUser = await _authRepository.signUp(
        name: name,
        email: email,
        password: password,
      );
    });
  }

  Future<void> signInWithGoogle() async {
    await _executeAuth(() async {
      _currentUser = await _authRepository.signInWithGoogle();
    });
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _executeAuth(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on AppException catch (error) {
      _error = error.message;
      rethrow;
    } catch (error) {
      _error = 'Erro inesperado. Tente novamente.';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
