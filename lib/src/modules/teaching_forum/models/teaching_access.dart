import '../../auth/models/user.dart';
import 'forum_logic.dart';

/// Só professor e curador (não pendentes) usam a Plataforma pedagógica no app.
/// Admin sem papel de ensino não vê; a restrição é de interface.
bool canUseTeachingForum(UserModel? user) =>
    user != null &&
    !user.isPending &&
    (user.teachingRole == TeachingRole.teacher ||
        user.teachingRole == TeachingRole.curator);

/// Só quem é Curador (não pendente) gerencia papéis de ensino. Admin sem papel
/// de curador não concede nem remove Professor/Curador. Restrição de interface:
/// as regras do Firestore ainda deixam admin gravar `teaching_role`.
bool canManageTeachingRoles(UserModel? user) =>
    user != null && !user.isPending && user.teachingRole == TeachingRole.curator;

ForumViewer? forumViewerFor(UserModel? user) => user == null
    ? null
    : ForumViewer(
        uid: user.id,
        isCurator: user.teachingRole == TeachingRole.curator,
        isAdmin: user.isAdminUser,
      );
