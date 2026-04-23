import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/auth/models/user.dart';
import 'package:ipe_flutter/src/modules/societies/models/society.dart';

void main() {
  group('ELO board permission (canAddExternal)', () {
    final boardUserId = 'user-board-1';
    final regularUserId = 'user-regular-1';

    SocietyModel makeEloSociety({
      List<String> boardIds = const [],
      Map<String, List<String>> boardWithPositions = const {},
    }) {
      return SocietyModel(
        id: 'elo-id',
        name: 'ELO',
        description: '',
        color: 0xFF2F4F2F,
        userId: 'admin',
        boardIds: boardIds,
        boardWithPositions: boardWithPositions,
      );
    }

    UserModel makeUser(String id) => UserModel(
          id: id,
          name: 'Test',
          email: 'test@test.com',
          isAdmin: false,
          isPending: false,
        );

    test('membro da diretoria (formato antigo) pode adicionar pessoa externa', () {
      final society = makeEloSociety(boardIds: [boardUserId]);
      final user = makeUser(boardUserId);
      expect(society.allBoardIds.contains(user.id), isTrue);
    });

    test('membro da diretoria (formato novo boardWithPositions) pode adicionar pessoa externa', () {
      final society = makeEloSociety(
        boardWithPositions: {
          'Presidente': [boardUserId],
        },
      );
      final user = makeUser(boardUserId);
      expect(society.allBoardIds.contains(user.id), isTrue);
    });

    test('usuário comum não pode adicionar pessoa externa', () {
      final society = makeEloSociety(boardIds: [boardUserId]);
      final user = makeUser(regularUserId);
      expect(society.allBoardIds.contains(user.id), isFalse);
    });

    test('usuário nulo não pode adicionar pessoa externa', () {
      final society = makeEloSociety(boardIds: [boardUserId]);
      const String? nullId = null;
      expect(society.allBoardIds.contains(nullId), isFalse);
    });
  });
}
