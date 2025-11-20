import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/utils/app_exception.dart';
import '../../auth/models/user.dart';
import '../../../shared/services/session_storage.dart';

class AuthRepository {
  AuthRepository({
    required SessionStorage sessionStorage,
  }) : _sessionStorage = sessionStorage;

  final SessionStorage _sessionStorage;
  final FirebaseAuth _auth = FirebaseConfig.auth;
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Stream do usuário atual
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Usuário atual
  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Buscar dados do usuário no Firestore
      final userModel = await _getUserFromFirestore(credential.user!.uid);

      if (userModel == null) {
        // Se não existe no Firestore, criar com dados básicos
        final newUser = UserModel(
          id: credential.user!.uid,
          name: credential.user!.displayName ?? credential.user!.email?.split('@').first ?? 'Usuário',
          email: credential.user!.email ?? email,
          isAdmin: false,
          isPending: true,
        );
        await _createUserInFirestore(newUser);
        await _sessionStorage.saveUser(newUser);
        return newUser;
      }

      await _sessionStorage.saveUser(userModel);
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AppException(message: _handleAuthException(e));
    } catch (e) {
      throw AppException(message: 'Erro ao fazer login: ${e.toString()}');
    }
  }

  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Atualizar displayName
      await credential.user!.updateDisplayName(name);

      // Criar usuário no Firestore
      final userModel = UserModel(
        id: credential.user!.uid,
        name: name,
        email: email,
        isAdmin: false,
        isPending: true,
      );

      await _createUserInFirestore(userModel);
      await _sessionStorage.saveUser(userModel);

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AppException(message: _handleAuthException(e));
    } catch (e) {
      throw AppException(message: 'Erro ao criar conta: ${e.toString()}');
    }
  }

  Future<UserModel> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw AppException(message: 'Login com Google cancelado pelo usuário');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw AppException(message: 'Falha ao obter tokens de autenticação do Google');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Verificar se o usuário já existe no Firestore
      var userModel = await _getUserFromFirestore(userCredential.user!.uid);

      if (userModel == null) {
        // Criar usuário no Firestore se não existir
        userModel = UserModel(
          id: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? 'Usuário Google',
          email: userCredential.user!.email ?? '',
          isAdmin: false,
          isPending: true,
        );

        await _createUserInFirestore(userModel);
      }

      await _sessionStorage.saveUser(userModel);
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AppException(message: _handleAuthException(e));
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(message: 'Erro no login com Google: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _sessionStorage.clear();
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AppException(message: 'Nenhum usuário logado');
      }

      final uid = user.uid;

      // 1. Deletar dados do Firestore primeiro (enquanto ainda temos autenticação)
      try {
        await _firestore.collection('users').doc(uid).delete();
      } on FirebaseException catch (firestoreError) {
        // Se for erro de permissão, logamos mas continuamos com a exclusão do Auth
        if (firestoreError.code == 'permission-denied') {
          print('Aviso: Sem permissão para deletar do Firestore. Continuando com exclusão do Auth.');
        } else {
          // Para outros erros do Firestore, relançamos
          throw AppException(
            message: 'Erro ao remover dados do Firestore: ${firestoreError.message}',
          );
        }
      }

      // 2. Deletar conta do Firebase Auth (CRÍTICO - deve sempre executar)
      // IMPORTANTE: user.delete() remove a autenticação, então deve ser a última operação autenticada
      await user.delete();

      // 3. Limpar sessão local
      await _sessionStorage.clear();

      // 4. Fazer logout do Google se aplicável
      await _googleSignIn.signOut();

      // 5. Garantir que não há usuário autenticado
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AppException(
          message: 'Por segurança, faça login novamente antes de excluir a conta',
        );
      }
      throw AppException(message: 'Erro ao excluir conta: ${e.message}');
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(message: 'Erro ao excluir conta: ${e.toString()}');
    }
  }

  Future<UserModel?> restoreSession() async {
    // Primeiro verificar se há usuário logado no Firebase
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      return await _sessionStorage.loadUser();
    }

    // Buscar dados atualizados do Firestore
    final userModel = await _getUserFromFirestore(firebaseUser.uid);
    if (userModel != null) {
      await _sessionStorage.saveUser(userModel);
      return userModel;
    }

    // Se não existe no Firestore, retornar do storage local
    return await _sessionStorage.loadUser();
  }

  // Buscar usuário no Firestore
  Future<UserModel?> _getUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Criar usuário no Firestore
  Future<void> _createUserInFirestore(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toJson());
    } catch (e) {
      rethrow;
    }
  }

  // Tratar exceções do Firebase Auth
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Erro de login: Os dados informados estão incorretos ou não existem';
      case 'email-already-in-use':
        return 'Este email já está em uso.';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres.';
      case 'invalid-email':
        return 'Email inválido.';
      case 'user-disabled':
        return 'Usuário desabilitado.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      default:
        return 'Erro de autenticação: ${e.message ?? 'Erro desconhecido'}';
    }
  }
}
