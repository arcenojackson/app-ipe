import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/auth/models/user.dart';

Map<String, dynamic> _base() => {
  'id': 'u1',
  'name': 'Maria',
  'email': 'maria@mail.com',
};

void main() {
  group('TeachingRole', () {
    test('value e fromValue', () {
      expect(TeachingRole.none.value, 'none');
      expect(TeachingRole.teacher.value, 'teacher');
      expect(TeachingRole.curator.value, 'curator');
      expect(TeachingRole.fromValue('teacher'), TeachingRole.teacher);
      expect(TeachingRole.fromValue('curator'), TeachingRole.curator);
      expect(TeachingRole.fromValue('none'), TeachingRole.none);
      expect(TeachingRole.fromValue('admin'), TeachingRole.none);
      expect(TeachingRole.fromValue(null), TeachingRole.none);
      expect(TeachingRole.fromValue(3), TeachingRole.none);
    });
  });

  group('UserModel.teachingRole', () {
    test('fromJson lê cada papel', () {
      for (final role in TeachingRole.values) {
        final user = UserModel.fromJson({
          ..._base(),
          'teaching_role': role.value,
        });
        expect(user.teachingRole, role);
      }
    });

    test('ausente, desconhecido ou de tipo errado vira none', () {
      expect(UserModel.fromJson(_base()).teachingRole, TeachingRole.none);
      expect(
        UserModel.fromJson({
          ..._base(),
          'teaching_role': 'banana',
        }).teachingRole,
        TeachingRole.none,
      );
      expect(
        UserModel.fromJson({..._base(), 'teaching_role': 42}).teachingRole,
        TeachingRole.none,
      );
      expect(
        UserModel.fromJson({..._base(), 'teaching_role': true}).teachingRole,
        TeachingRole.none,
      );
      expect(
        UserModel.fromJson({..._base(), 'teaching_role': null}).teachingRole,
        TeachingRole.none,
      );
    });

    test('construtor tem none como padrão', () {
      const user = UserModel(
        id: 'a',
        name: 'A',
        email: 'a@a.com',
        isAdmin: false,
        isPending: false,
      );
      expect(user.teachingRole, TeachingRole.none);
    });

    test('toJson omite teaching_role quando none', () {
      final json = UserModel.fromJson(_base()).toJson();
      expect(json.containsKey('teaching_role'), isFalse);
    });

    test('toJson grava teaching_role para teacher e curator', () {
      final teacher = UserModel.fromJson({
        ..._base(),
        'teaching_role': 'teacher',
      }).toJson();
      final curator = UserModel.fromJson({
        ..._base(),
        'teaching_role': 'curator',
      }).toJson();
      expect(teacher['teaching_role'], 'teacher');
      expect(curator['teaching_role'], 'curator');
    });

    test('copyWith altera e preserva o papel', () {
      final user = UserModel.fromJson(_base());
      final teacher = user.copyWith(teachingRole: TeachingRole.teacher);
      expect(teacher.teachingRole, TeachingRole.teacher);
      expect(teacher.name, 'Maria');
      expect(teacher.copyWith(name: 'Ana').teachingRole, TeachingRole.teacher);
      expect(user.teachingRole, TeachingRole.none);
    });
  });
}
