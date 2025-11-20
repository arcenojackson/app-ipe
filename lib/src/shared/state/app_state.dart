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

  Future<void> deleteAccount() async {
    try {
      await _authRepository.deleteAccount();
      // Limpar o usuário atual após exclusão bem-sucedida
      _currentUser = null;
      // Notificar imediatamente para que a UI atualize (igual ao signOut)
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _executeAuth(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      // Após sucesso, o _currentUser já foi atualizado, então notificamos
      _isLoading = false;
      notifyListeners();
    } on AppException catch (error) {
      _error = error.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (error) {
      _error = 'Erro inesperado. Tente novamente.';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
