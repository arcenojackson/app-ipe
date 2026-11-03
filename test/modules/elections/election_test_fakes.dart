import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/auth/models/user.dart';
import 'package:ipe_flutter/src/shared/state/app_state.dart';

/// Usuário logado fictício para telas que leem `AppState.currentUser`.
class FakeAppState extends Fake with ChangeNotifier implements AppState {
  FakeAppState({this.userId = 'u1'});

  final String userId;

  @override
  UserModel? get currentUser => UserModel(
    id: userId,
    name: 'Ana',
    email: 'ana@ipe.org',
    isAdmin: false,
    isPending: false,
  );
}
