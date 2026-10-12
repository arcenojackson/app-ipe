import '../../auth/models/user.dart';

/// Opção do menu de papel de ensino exibida para um usuário na lista de pessoas.
class TeachingRoleMenuOption {
  const TeachingRoleMenuOption({
    required this.value,
    required this.label,
    required this.target,
  });

  /// Valor usado no PopupMenuItem (sempre com prefixo `role_`).
  final String value;
  final String label;
  final TeachingRole target;

  /// Converte o valor do menu (`role_*`) no papel alvo; null se não for um valor de papel.
  static TeachingRole? targetFromMenuValue(String value) {
    switch (value) {
      case 'role_teacher':
        return TeachingRole.teacher;
      case 'role_curator':
        return TeachingRole.curator;
      case 'role_none':
        return TeachingRole.none;
    }
    return null;
  }
}

const _teacher = TeachingRoleMenuOption(
  value: 'role_teacher',
  label: 'Tornar professor',
  target: TeachingRole.teacher,
);
const _curator = TeachingRoleMenuOption(
  value: 'role_curator',
  label: 'Tornar curador',
  target: TeachingRole.curator,
);
const _demote = TeachingRoleMenuOption(
  value: 'role_teacher',
  label: 'Rebaixar para professor',
  target: TeachingRole.teacher,
);
const _remove = TeachingRoleMenuOption(
  value: 'role_none',
  label: 'Remover de professores',
  target: TeachingRole.none,
);

/// Opções de menu disponíveis conforme o papel de ensino atual.
List<TeachingRoleMenuOption> teachingRoleMenuOptions(TeachingRole current) {
  switch (current) {
    case TeachingRole.none:
      return const [_teacher, _curator];
    case TeachingRole.teacher:
      return const [_curator, _remove];
    case TeachingRole.curator:
      return const [_demote, _remove];
  }
}
