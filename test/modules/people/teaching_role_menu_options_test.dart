import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/auth/models/user.dart';
import 'package:ipe_flutter/src/modules/people/models/teaching_role_menu_option.dart';

List<List<Object>> _summary(TeachingRole current) => teachingRoleMenuOptions(
  current,
).map((o) => <Object>[o.value, o.label, o.target]).toList();

void main() {
  group('teachingRoleMenuOptions', () {
    test('none oferece tornar professor e curador, sem remover', () {
      expect(_summary(TeachingRole.none), [
        ['role_teacher', 'Tornar professor', TeachingRole.teacher],
        ['role_curator', 'Tornar curador', TeachingRole.curator],
      ]);
      expect(
        teachingRoleMenuOptions(
          TeachingRole.none,
        ).any((o) => o.target == TeachingRole.none),
        isFalse,
      );
    });

    test('teacher oferece tornar curador e remover de professores', () {
      expect(_summary(TeachingRole.teacher), [
        ['role_curator', 'Tornar curador', TeachingRole.curator],
        ['role_none', 'Remover de professores', TeachingRole.none],
      ]);
    });

    test('curator oferece rebaixar para professor e remover', () {
      expect(_summary(TeachingRole.curator), [
        ['role_teacher', 'Rebaixar para professor', TeachingRole.teacher],
        ['role_none', 'Remover de professores', TeachingRole.none],
      ]);
    });
  });
}
